#!/usr/bin/env bash
# Builds hiddify-core's Android library (hiddify-core.aar) from the hiddify-core source at the
# version of dependencies.properties, with the patches of raman/core-patches applied.
#
#   raman/core-patches/<dir>/*.patch   applied with `git apply` inside <dir> of hiddify-core
#                                      ("root" = hiddify-core itself, "hiddify-sing-box" = that submodule)
#
# Environment (all optional):
#   CORE_REF      hiddify-core tag (default v<core.version>)
#   WORK          where hiddify-core is cloned (default $RUNNER_TEMP/hiddify-core)
#   OUT           the AAR written (default build/core/hiddify-core.aar)
#   TARGETS       gomobile targets (default android/arm,android/arm64,android/amd64)
#   INPROXY       true: build psiphon-tunnel-core's in-proxy (Conduit) support (default true)
#   STEP          clone | check | build | all (default all)
#   HIDDIFY_SECRET_KEY + PSIPHON_CONFIG   a Psiphon config of your own for config "hiddify".
#                 Without them, the encrypted config (and its key) of the official hiddify-core
#                 release of CORE_REF is linked in unchanged, so config "hiddify" behaves as in
#                 the official core.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
CORE_VERSION=$(sed -n 's/^core.version=//p' "$REPO/dependencies.properties")
CORE_REF=${CORE_REF:-v$CORE_VERSION}
WORK=${WORK:-${RUNNER_TEMP:-/tmp}/hiddify-core}
OUT=${OUT:-$REPO/build/core/hiddify-core.aar}
TARGETS=${TARGETS:-android/arm,android/arm64,android/amd64}
INPROXY=${INPROXY:-true}
STEP=${STEP:-all}

log() { echo "::group::$*" 2>/dev/null || true; }
endlog() { echo "::endgroup::" 2>/dev/null || true; }

clone() {
  log "clone hiddify-core $CORE_REF"
  rm -rf "$WORK"
  git clone --depth 1 --branch "$CORE_REF" https://github.com/hiddify/hiddify-core.git "$WORK"
  # ray2sing is listed with an ssh URL
  local sub=(git -C "$WORK" -c url."https://github.com/".insteadOf="git@github.com:"
    -c url."https://github.com/".insteadOf="ssh://git@github.com/" submodule update --init --recursive --jobs 4)
  "${sub[@]}" --depth 1 || "${sub[@]}"
  git -C "$WORK" submodule status --recursive
  endlog

  log "apply the Raman patches"
  for dir in "$REPO"/raman/core-patches/*/; do
    name=$(basename "$dir")
    target="$WORK"
    [ "$name" != root ] && target="$WORK/$name"
    for patch in "$dir"*.patch; do
      [ -e "$patch" ] || continue
      echo "apply $name/$(basename "$patch")"
      git -C "$target" apply --whitespace=nowarn "$patch"
    done
  done
  endlog

  if [ "$INPROXY" = true ]; then
    # psiphon-tunnel-core builds in-proxy only with the tag PSIPHON_ENABLE_INPROXY, and then needs
    # its forks of pion dtls/ice/webrtc (replace directives of its own go.mod, which only apply
    # when it is the main module): they are taken from the same tunnel-core commit.
    log "in-proxy: Psiphon's pion forks"
    local ver commit
    ver=$(cd "$WORK" && go list -m -f '{{.Version}}' github.com/Psiphon-Labs/psiphon-tunnel-core)
    commit=${ver##*-}
    echo "psiphon-tunnel-core $ver ($commit)"
    rm -rf "$WORK/.psiphon"
    git clone --filter=blob:none --no-checkout https://github.com/Psiphon-Labs/psiphon-tunnel-core.git "$WORK/.psiphon"
    git -C "$WORK/.psiphon" checkout "$commit" -- replace/dtls replace/ice replace/webrtc
    (cd "$WORK" &&
      go mod edit -replace github.com/pion/dtls/v2=./.psiphon/replace/dtls &&
      go mod edit -replace github.com/pion/ice/v2=./.psiphon/replace/ice &&
      go mod edit -replace github.com/pion/webrtc/v3=./.psiphon/replace/webrtc)
    endlog
  fi

  log "go mod tidy"
  (cd "$WORK" && go mod tidy)
  endlog
}

tags() {
  local t
  t=$(cd "$WORK" && env -u PSIPHON_CONFIG -u HIDDIFY_SECRET_KEY make -s print-TAGS)
  [ "$INPROXY" = true ] && t="$t,PSIPHON_ENABLE_INPROXY"
  echo "$t"
}

check() {
  # compiles the patched Psiphon outbound (with tunnel-core and, with INPROXY, in-proxy) and runs
  # its tests: minutes, where the Android build takes much longer
  log "check: go test the Psiphon outbound"
  (cd "$WORK" && go test -tags "$(tags)" -run 'TestMergeParameters' -count=1 github.com/sagernet/sing-box/protocol/psiphon)
  endlog
}

embedded() {
  # prints "KEY CONFIG" for -X, or nothing
  if [ -n "${HIDDIFY_SECRET_KEY:-}" ] && [ -n "${PSIPHON_CONFIG:-}" ]; then
    local enc
    enc=$(cd "$WORK" && go run ./cmd/internal/encryptconfig)
    echo "$HIDDIFY_SECRET_KEY $enc"
    return
  fi
  local tmp
  tmp=$(mktemp -d)
  if curl -fsSL --retry 5 --retry-all-errors -o "$tmp/core.tgz" \
    "https://github.com/hiddify/hiddify-core/releases/download/$CORE_REF/hiddify-lib-android.tar.gz" &&
    tar xzf "$tmp/core.tgz" -C "$tmp" &&
    unzip -q -o "$tmp/hiddify-core.aar" 'jni/arm64-v8a/libhiddify-core.so' -d "$tmp" &&
    python3 "$HERE/extract_embedded.py" "$tmp/jni/arm64-v8a/libhiddify-core.so" "$tmp/key" "$tmp/config" >&2; then
    echo "$(cat "$tmp/key") $(cat "$tmp/config")"
  fi
  rm -rf "$tmp"
}

build() {
  log "gomobile"
  (cd "$WORK" && go install github.com/sagernet/gomobile/cmd/gomobile@v0.1.11 github.com/sagernet/gomobile/cmd/gobind@v0.1.11)
  endlog

  local key="" config="" pair
  pair=$(embedded || true)
  if [ -n "$pair" ]; then
    key=${pair%% *}
    config=${pair#* }
    echo "::add-mask::$key"
    echo "::add-mask::$config"
    echo "embedded Psiphon config: yes (${#config} chars)"
  else
    echo "::warning::no embedded Psiphon config: config \"hiddify\" uses Psiphon's public defaults"
  fi

  local ld="-w -s -checklinkname=0 -buildid="
  ld="$ld -X github.com/hiddify/hiddify-core/v2/hcommon/constants.Version=${CORE_REF}-raman"
  ld="$ld -X github.com/sagernet/sing-box/constant.Version=1.13.0"
  ld="$ld -X github.com/hiddify/hiddify-core/v2/hcore/buildid.ID=$(cat /proc/sys/kernel/random/uuid)"
  if [ -n "$key" ]; then
    ld="$ld -X github.com/sagernet/sing-box/hiddify/secret.Key=$key"
    ld="$ld -X github.com/sagernet/sing-box/protocol/psiphon.embeddedHiddifyConfig=$config"
  fi

  log "gomobile bind ($TARGETS)"
  mkdir -p "$(dirname "$OUT")"
  (cd "$WORK" && PATH="$(go env GOPATH)/bin:$PATH" CGO_LDFLAGS="-O2 -g -s -w -Wl,-z,max-page-size=16384" \
    gomobile bind -androidapi=21 -javapkg=com.hiddify.core -libname=hiddify-core -tags="$(tags)" -trimpath \
    -ldflags="$ld" -target="$TARGETS" -gcflags "all=-N -l" -o "$OUT" \
    github.com/sagernet/sing-box/experimental/libbox ./platform/mobile)
  endlog
  ls -la "$OUT"
  unzip -l "$OUT" | grep -E 'jni/|classes.jar'
}

case "$STEP" in
  clone) clone ;;
  check) check ;;
  build) build ;;
  all) clone; check; build ;;
  *) echo "unknown STEP $STEP" >&2; exit 2 ;;
esac
