#!/usr/bin/env bash
# Raman VPN Google Relay: builds libmhrv_rs.so (mhrv-rs, the Rust port of MasterHttpRelayVPN, MIT)
# for the Android ABIs the app ships, into build/relay-jni/<abi>/. The app loads it only when
# the user starts the relay (lib/features/raman/relay, RelayHandler.kt).
#
# Needs: rustup targets for Android, cargo-ndk, ANDROID_NDK_HOME.
set -euo pipefail

: "${MHRV_REPO:=https://github.com/therealaleph/MasterHttpRelayVPN-RUST.git}"
: "${MHRV_REF:=$(cat "$(dirname "$0")/MHRV_VERSION")}"
: "${MHRV_COMMIT:=$(cat "$(dirname "$0")/MHRV_COMMIT")}"

root=$(pwd)
src="$root/build/mhrv-src"
out="$root/build/relay-jni"
rm -rf "$src" "$out"
git clone --depth 1 --branch "$MHRV_REF" "$MHRV_REPO" "$src"
got=$(git -C "$src" rev-parse HEAD)
if [ "$got" != "$MHRV_COMMIT" ]; then
  echo "mhrv-rs $MHRV_REF is $got, expected $MHRV_COMMIT" >&2
  exit 1
fi

cd "$src"
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86_64 -P 21 -o "$out" build --release --lib --locked

# only libmhrv_rs.so is used (the app's VPN is the Hiddify core; tun2proxy is not needed)
find "$out" -name 'libtun2proxy*' -delete
find "$out" -name '*.so' ! -name 'libmhrv_rs.so' -print -delete
ls -laR "$out"
for abi in arm64-v8a armeabi-v7a x86_64; do
  test -s "$out/$abi/libmhrv_rs.so"
done
cp LICENSE "$out/LICENSE-mhrv-rs"
