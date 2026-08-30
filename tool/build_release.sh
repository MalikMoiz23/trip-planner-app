#!/usr/bin/env bash
# Builds the artefacts you actually ship, and prints what each one weighs.
#
# `flutter build apk` produces a universal APK carrying the Flutter engine three
# times over — arm64-v8a, armeabi-v7a and x86_64 — because it cannot know which
# phone will install it. That is 97% of a 52 MB file, and every phone uses
# exactly one of the three. Splitting per ABI takes the download to about 17 MB.
#
#   ./tool/build_release.sh          both APKs and the app bundle
#   ./tool/build_release.sh apk      per-ABI APKs only (for sideloading)
#   ./tool/build_release.sh bundle   app bundle only (for Play)
set -euo pipefail
cd "$(dirname "$0")/.."

what="${1:-all}"

# Obfuscation strips Dart symbol names out of libapp.so. Keep the symbol files:
# without them a crash report from a release build is unreadable.
SYMBOLS="build/symbols"
COMMON=(--release --obfuscate --split-debug-info="$SYMBOLS")

size() { du -m "$1" 2>/dev/null | cut -f1; }

report() {
  printf '\n%s\n' "artefacts"
  printf '%s\n' "---------"
  for f in "$@"; do
    [ -f "$f" ] && printf '%6s MB  %s\n' "$(size "$f")" "$f"
  done
  printf '\n'
}

if [ "$what" = "all" ] || [ "$what" = "apk" ]; then
  echo "==> per-ABI APKs"
  flutter build apk "${COMMON[@]}" --split-per-abi
  report \
    build/app/outputs/flutter-apk/app-arm64-v8a-release.apk \
    build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk \
    build/app/outputs/flutter-apk/app-x86_64-release.apk
  cat <<'NOTE'
Install app-arm64-v8a-release.apk on any phone made since roughly 2016.
armeabi-v7a is for older 32-bit devices; x86_64 is emulators only and should
not be distributed.
NOTE
fi

if [ "$what" = "all" ] || [ "$what" = "bundle" ]; then
  echo "==> app bundle"
  flutter build appbundle "${COMMON[@]}"
  report build/app/outputs/bundle/release/app-release.aab
  cat <<'NOTE'
The .aab is not a download size. Play splits it per device and serves roughly
what the matching per-ABI APK weighs.
NOTE
fi

if [ ! -f android/key.properties ]; then
  cat <<'WARN'
WARNING: android/key.properties is missing, so this build is signed with the
debug key. It cannot be published, and an update signed on another machine will
refuse to install over it. See android/key.properties.example.
WARN
fi
