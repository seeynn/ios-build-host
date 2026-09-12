#!/bin/sh
set -eu

ENGINE="${ENGINE:?ENGINE path is required}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK=iphoneos
ARCH=arm64
MIN_OS=26.0
OUT="${OUT:-$ROOT/build}"

DEPS="$ENGINE/deps"
TREE="$DEPS/build-$SDK-$ARCH"
ANGLE="$DEPS/ANGLE/$SDK"
BUILD="$OUT/$SDK-$ARCH"
APP="$BUILD/Lona.app"
OBJ="$BUILD/obj"
LIB="$BUILD/lib"

SYSROOT="$(xcrun --sdk "$SDK" --show-sdk-path)"
CC="$(xcrun --sdk "$SDK" -f clang)"
CXX="$(xcrun --sdk "$SDK" -f clang++)"
TARGET="${ARCH}-apple-ios${MIN_OS}"

if [ ! -d "$TREE/lib" ] || [ ! -d "$ANGLE/lib" ]; then
  echo "Lona build: dependencies missing under $DEPS" >&2
  exit 1
fi

INCLUDES="\
 --include $TREE/include \
 --include $TREE/include/AL \
 --include $TREE/include/SDL2 \
 --include $TREE/include/pixman-1 \
 --include $TREE/include/uchardet \
 --include $TREE/include/freetype2 \
 --include $ANGLE/include"

rm -rf "$BUILD"
mkdir -p "$OBJ" "$LIB" "$APP"

# shellcheck disable=SC2086
"$ENGINE/tools/build-core-ios.sh" \
  --sdk "$SDK" --arch "$ARCH" --min-os "$MIN_OS" \
  --obj "$OBJ/core" --out "$LIB" $INCLUDES

build_binding() {
  # shellcheck disable=SC2086
  "$ENGINE/tools/build-binding-ios.sh" --ruby "$1" \
    --sdk "$SDK" --arch "$ARCH" --min-os "$MIN_OS" \
    --obj "$OBJ/binding$1" --out "$LIB" --scratch "$BUILD" \
    --ruby-include "$TREE/include/$2" \
    --static-lib "$TREE/lib/$3" --ext-lib "$TREE/lib/$4" \
    $INCLUDES
}

build_binding 31 ruby31 libruby.3.1-static.a libruby.3.1-ext.a
build_binding 19 ruby19 libruby19-static.a libruby19-ext.a
build_binding 18 ruby18 libruby18-static.a libruby18-ext.a

"$CC" -isysroot "$SYSROOT" -target "$TARGET" -arch "$ARCH" \
  -miphoneos-version-min="$MIN_OS" -fobjc-arc -O2 \
  -I"$ENGINE/src" \
  -c "$ROOT/port/LonaHost.m" -o "$OBJ/LonaHost.o"

"$CXX" -isysroot "$SYSROOT" -target "$TARGET" -arch "$ARCH" \
  -miphoneos-version-min="$MIN_OS" \
  -L"$TREE/lib" -L"$ANGLE/lib" \
  -o "$APP/Lona" \
  "$OBJ/LonaHost.o" \
  -Wl,-force_load,"$LIB/libmkxpz-core.a" \
  "$LIB/mkxp18-merged.o" "$LIB/mkxp19-merged.o" "$LIB/mkxp31-merged.o" \
  -lSDL2 -lSDL2main -lSDL2_image -lSDL2_sound -lSDL2_ttf \
  -lfreetype -lpixman-1 -lpng16 \
  -logg -lvorbis -lvorbisfile -ltheora -ltheoradec \
  -lphysfs -luchardet -lopenal \
  -lssl -lcrypto -lz -lbz2 -liconv \
  -lANGLE_static -lEGL_static -lGLESv2_static \
  -framework Foundation -framework UIKit -framework CoreFoundation \
  -framework CoreGraphics -framework CoreVideo -framework CoreAudio \
  -framework AudioToolbox -framework AVFoundation -framework Metal \
  -framework QuartzCore -framework GameController -framework CoreMotion \
  -framework IOSurface \
  -weak_framework CoreBluetooth -weak_framework CoreHaptics \
  -weak_framework OpenGLES

cp "$ROOT/port/Info.plist" "$APP/Info.plist"

ASSETS="$APP/Assets.bundle"
mkdir -p "$ASSETS/Shaders" "$ASSETS/Fonts" "$ASSETS/Preload" "$ASSETS/Postload"
cp "$ENGINE"/shader/*.frag "$ENGINE"/shader/*.vert "$ENGINE"/shader/*.h "$ASSETS/Shaders/"
cp "$ENGINE"/assets/liberation.ttf "$ENGINE"/assets/wqymicrohei.ttf "$ASSETS/Fonts/"
cp "$ENGINE"/assets/gamecontrollerdb.txt "$ENGINE"/assets/icon.png "$ENGINE"/assets/cacert.pem "$ASSETS/"
cp "$ENGINE"/scripts/preload/*.rb "$ASSETS/Preload/"
cp "$ENGINE"/scripts/postload/*.rb "$ASSETS/Postload/"
cp -R "$TREE/ruby-stdlib" "$APP/Ruby"

mkdir -p "$APP/Game"
printf '%s\n' 'payload injected after build' > "$APP/Game/.payload-placeholder"
rm -rf "$APP/_CodeSignature" "$APP/embedded.mobileprovision" 2>/dev/null || true

mkdir -p "$OUT/ipa/Payload"
rm -rf "$OUT/ipa/Payload/Lona.app"
cp -R "$APP" "$OUT/ipa/Payload/Lona.app"
(cd "$OUT/ipa" && ditto -c -k --sequesterRsrc --keepParent Payload "$OUT/LonaHost-unsigned.ipa")

test -s "$OUT/LonaHost-unsigned.ipa"
echo "Built $OUT/LonaHost-unsigned.ipa"
