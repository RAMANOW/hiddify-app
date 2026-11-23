#!/usr/bin/env bash
# Raman VPN "DNS قطعی": the Slipstream DNS-tunnel client (github.com/EndPositive/slipstream, C,
# Apache-2.0) as an Android executable libslipstream.so in build/dnstunnel-jni/<abi>/ (run after
# build-dnstunnel.sh, which empties that dir). Built from the commit in SLIPSTREAM_COMMIT with its
# submodules (picoquic MIT, picotls MIT via picoquic's FetchContent, SPCDNS LGPL-3.0,
# lua-resty-base-encoding MIT, quick_arg_parser MIT). Needs ANDROID_NDK_HOME, meson, ninja, cmake,
# pkg-config.
#
# Changes to upstream, made here at build time (Apache-2.0 §4b; also listed in NOTICE.txt):
#  1. meson.build: picoquic is configured with WITH_OPENSSL=OFF (and a placeholder
#     OPENSSL_INCLUDE_DIR), so TLS uses picotls "minicrypto" and no OpenSSL is needed on Android,
#     and without picotls "fusion" (x86_64 AES-NI; needs aligned_alloc, API 28+).
#  2. picoquic cmake/FindPTLS.cmake: picotls-openssl dropped from the fetched picotls libraries.
#  3. src/slipstream_client.c: the local TCP listener binds 127.0.0.1 instead of 0.0.0.0, so the
#     tunnel is not open to the local network.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
out="$root/build/dnstunnel-jni"
work="${RUNNER_TEMP:-/tmp}/raman-slipstream"
repo="$(tr -d '[:space:]' < "$here/SLIPSTREAM_REPO")"
commit="$(tr -d '[:space:]' < "$here/SLIPSTREAM_COMMIT")"
api=24
ndkbin="${ANDROID_NDK_HOME:?ANDROID_NDK_HOME}/toolchains/llvm/prebuilt/linux-x86_64/bin"

rm -rf "$work"
mkdir -p "$work" "$out"
git clone --quiet "$repo" "$work/src"
git -C "$work/src" checkout --quiet "$commit"
git -C "$work/src" submodule update --init --quiet
src="$work/src"

patch_once() { # file from to [all]
  python3 - "$@" <<'PY'
import sys
path, old, new = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()
n = s.count(old)
if n < 1 or (n != 1 and len(sys.argv) < 5):
    sys.exit("patch: %r found %d times in %s" % (old, s.count(old), path))
open(path, "w").write(s.replace(old, new))
PY
}
patch_once "$src/meson.build" "    {'BUILD_TESTING': 'OFF'}," \
  "    {'BUILD_TESTING': 'OFF'},
    {'WITH_OPENSSL': 'OFF'},
    {'WITH_FUSION': 'OFF'},
    {'PTLS_WITH_FUSION': 'OFF'},
    {'OPENSSL_INCLUDE_DIR': meson.project_source_root() / 'include'},"
patch_once "$src/subprojects/picoquic/cmake/FindPTLS.cmake" ' ${PTLS_OPENSSL_LIBRARY} ' ' ' all
patch_once "$src/src/slipstream_client.c" 'listen_addr.sin_addr.s_addr = INADDR_ANY;' \
  'listen_addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);'

build() { # abi clang-prefix cpu_family cpu [extra c flags]
  local abi=$1 cc=$2 family=$3 cpu=$4 extra=${5:-}
  local cross="$work/cross-$abi.ini"
  cat > "$cross" <<EOF
[binaries]
c = '$ndkbin/$cc-clang'
cpp = '$ndkbin/$cc-clang++'
ar = '$ndkbin/llvm-ar'
strip = '$ndkbin/llvm-strip'
cmake = 'cmake'
pkg-config = 'pkg-config'

[host_machine]
system = 'linux'
cpu_family = '$family'
cpu = '$cpu'
endian = 'little'

[cmake]
CMAKE_SYSTEM_NAME = 'Linux'
EOF
  meson setup "$work/build-$abi" "$src" --cross-file "$cross" \
    -Dbuildtype=release -Ddefault_library=static \
    "-Dc_args=-include signal.h -D_GNU_SOURCE $extra" "-Dcpp_args=-D_GNU_SOURCE"
  ninja -C "$work/build-$abi" slipstream-client
  mkdir -p "$out/$abi"
  "$ndkbin/llvm-strip" -o "$out/$abi/libslipstream.so" "$work/build-$abi/slipstream-client"
  chmod 755 "$out/$abi/libslipstream.so"
}

build arm64-v8a "aarch64-linux-android$api" aarch64 aarch64
# picotls's micro-ecc has ARM32 asm that clang's assembler rejects in Thumb mode: use its C code
build armeabi-v7a "armv7a-linux-androideabi$api" arm armv7a "-DuECC_PLATFORM=0 -DuECC_WORD_SIZE=4"
build x86_64 "x86_64-linux-android$api" x86_64 x86_64

file "$out"/*/libslipstream.so || true
ls -la "$out"/*/libslipstream.so
