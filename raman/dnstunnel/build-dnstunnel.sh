#!/usr/bin/env bash
# Raman VPN "DNS قطعی" engines, built as Android executables named lib*.so so the APK ships them in
# jniLibs and Android extracts them to the app's native library dir (useLegacyPackaging = true):
#   libsoarsocks.so  - raman/dnstunnel/soarsocks: SOCKS5 on 127.0.0.1 over a Soar DNS tunnel
#                      (github.com/getlantern/soar v0.2.4, Apache-2.0, pinned in soarsocks/go.mod)
#   libcottendns.so  - the CottenDNS client (MIT, TaJirax), unchanged, from the tag in COTTEN_TAG
#                      (its own SOCKS5 listener on 127.0.0.1)
#   libdnstt.so      - dnstt-client (David Fifield, public domain / CC0), unchanged, from DNSTT_TAG
#                      (a TCP forwarder on 127.0.0.1 to the server's SOCKS5 proxy); cgo on every ABI
#                      so DoH / DoT host names resolve with Android's resolver
#   libmasterdns.so  - the MasterDnsVPN client (Amin Mahmoudi / masterking32, MIT), unchanged, from
#                      MASTERDNS_TAG (its own SOCKS5 listener on 127.0.0.1)
# libslipstream.so (C, EndPositive/slipstream, Apache-2.0) is built by build-slipstream.sh.
# Output: build/dnstunnel-jni/<abi>/. Needs Go >= 1.26 and ANDROID_NDK_HOME (cgo linking for
# armeabi-v7a and x86_64; arm64 links internally like CottenDNS's own Android build).
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="$root/build/dnstunnel-jni"
work="${RUNNER_TEMP:-/tmp}/raman-dnstunnel"
repo="$(tr -d '[:space:]' < "$here/COTTEN_REPO")"
tag="$(tr -d '[:space:]' < "$here/COTTEN_TAG")"
commit="$(tr -d '[:space:]' < "$here/COTTEN_COMMIT")"
pin() { tr -d '[:space:]' < "$here/$1"; }
api=24
ndkbin="${ANDROID_NDK_HOME:?ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin"

rm -rf "$out" "$work"
mkdir -p "$out" "$work"
git clone --quiet --depth 1 --branch "$tag" "$repo" "$work/cotten"
got="$(git -C "$work/cotten" rev-parse HEAD)"
if [ "$got" != "$commit" ]; then
  echo "CottenDNS tag $tag is $got, expected $commit" >&2
  exit 1
fi

# clone <dir> <repo> <tag> <commit> [mirror]
clone() {
  local dir=$1 url=$2 tg=$3 want=$4 mirror=${5:-}
  git clone --quiet --depth 1 --branch "$tg" "$url" "$work/$dir" ||
    { [ -n "$mirror" ] && rm -rf "${work:?}/$dir" && git clone --quiet --depth 1 --branch "$tg" "$mirror" "$work/$dir"; }
  local have
  have="$(git -C "$work/$dir" rev-parse HEAD)"
  if [ "$have" != "$want" ]; then
    echo "$dir tag $tg is $have, expected $want" >&2
    exit 1
  fi
}
clone dnstt "$(pin DNSTT_REPO)" "$(pin DNSTT_TAG)" "$(pin DNSTT_COMMIT)" https://repo.or.cz/dnstt.git
clone masterdns "$(pin MASTERDNS_REPO)" "$(pin MASTERDNS_TAG)" "$(pin MASTERDNS_COMMIT)"

build() { # abi goarch goarm cc
  local abi=$1 goarch=$2 goarm=$3 cc=$4
  mkdir -p "$out/$abi"
  local env=(GOOS=android GOARCH="$goarch")
  [ -n "$goarm" ] && env+=(GOARM="$goarm")
  if [ -n "$cc" ]; then env+=(CGO_ENABLED=1 CC="$ndkbin/$cc"); else env+=(CGO_ENABLED=0); fi
  (cd "$here/soarsocks" && env "${env[@]}" go build -trimpath -ldflags "-s -w -buildid=" -o "$out/$abi/libsoarsocks.so" .)
  (cd "$work/cotten" && env "${env[@]}" go build -trimpath \
    -ldflags "-s -w -buildid= -X cottendns-go/internal/version.BuildVersion=$tag" \
    -o "$out/$abi/libcottendns.so" ./cmd/client)
  (cd "$work/masterdns" && env "${env[@]}" go build -trimpath \
    -ldflags "-s -w -buildid= -X masterdnsvpn-go/internal/version.BuildVersion=$(pin MASTERDNS_TAG)" \
    -o "$out/$abi/libmasterdns.so" ./cmd/client)
  # dnstt: always cgo (Android has no /etc/resolv.conf for Go's own resolver)
  local cgocc=$5
  (cd "$work/dnstt/dnstt-client" && env GOOS=android GOARCH="$goarch" ${goarm:+GOARM=$goarm} CGO_ENABLED=1 CC="$ndkbin/$cgocc" \
    go build -trimpath -ldflags "-s -w -buildid=" -o "$out/$abi/libdnstt.so" .)
}

build arm64-v8a arm64 "" "" "aarch64-linux-android$api-clang"
build armeabi-v7a arm 7 "armv7a-linux-androideabi$api-clang" "armv7a-linux-androideabi$api-clang"
build x86_64 amd64 "" "x86_64-linux-android$api-clang" "x86_64-linux-android$api-clang"

file "$out"/*/*.so || true
ls -laR "$out"
