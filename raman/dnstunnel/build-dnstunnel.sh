#!/usr/bin/env bash
# Raman VPN "DNS قطعی" engines, built as Android executables named lib*.so so the APK ships them in
# jniLibs and Android extracts them to the app's native library dir (useLegacyPackaging = true):
#   libsoarsocks.so  - raman/dnstunnel/soarsocks: SOCKS5 on 127.0.0.1 over a Soar DNS tunnel
#                      (github.com/getlantern/soar v0.2.4, Apache-2.0, pinned in soarsocks/go.mod)
#   libcottendns.so  - the CottenDNS client (MIT, TaJirax), unchanged, from the tag in COTTEN_TAG
#                      (its own SOCKS5 listener on 127.0.0.1)
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
}

build arm64-v8a arm64 "" ""
build armeabi-v7a arm 7 "armv7a-linux-androideabi$api-clang"
build x86_64 amd64 "" "x86_64-linux-android$api-clang"

file "$out"/*/*.so || true
ls -laR "$out"
