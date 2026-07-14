#!/bin/zsh

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/CubismSdkForNative"
  exit 64
fi

SDK_ROOT="${1:A}"
REPO_ROOT="${0:A:h:h}"
RUNTIME_SOURCES="$REPO_ROOT/Vendor/Live2D/RuntimeSources"
OUTPUT="$REPO_ROOT/Vendor/Live2D/JoiCubismRuntime.xcframework"
BUILD_ROOT="$(mktemp -d /tmp/joi-cubism-runtime.XXXXXX)"

cleanup() {
  rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

for required in \
  "$SDK_ROOT/Core/include/Live2DCubismCore.h" \
  "$SDK_ROOT/Framework/src/CubismFramework.cpp" \
  "$SDK_ROOT/Framework/src/Rendering/Metal/CubismRenderer_Metal.mm"; do
  if [[ ! -f "$required" ]]; then
    echo "Missing required SDK file: $required"
    exit 66
  fi
done

build_slice() {
  local name="$1"
  local sdk="$2"
  local target="$3"
  local core_library="$4"
  local slice_root="$BUILD_ROOT/$name"
  local object_root="$slice_root/objects"
  local sdk_path
  sdk_path="$(xcrun --sdk "$sdk" --show-sdk-path)"
  mkdir -p "$object_root" "$slice_root/include"

  local common_flags=(
    -target "$target"
    -isysroot "$sdk_path"
    -miphoneos-version-min=17.0
    -std=c++14
    -stdlib=libc++
    -fmodules
    -fPIC
    -O2
    -DNDEBUG=1
    -DCSM_TARGET_IPHONE_ES2=1
    -I"$SDK_ROOT/Core/include"
    -I"$SDK_ROOT/Framework/src"
    -I"$SDK_ROOT/Framework/src/Rendering/Metal"
    -I"$SDK_ROOT/Framework/src/Rendering/Metal/Shaders"
  )

  local index=0
  local source
  while IFS= read -r source; do
    case "$source" in
      */Rendering/D3D9/*|*/Rendering/D3D11/*|*/Rendering/OpenGL/*|*/Rendering/Vulkan/*)
        continue
        ;;
    esac
    index=$((index + 1))
    xcrun --sdk "$sdk" clang++ "${common_flags[@]}" -c "$source" -o "$object_root/framework-$index.o"
  done < <(find "$SDK_ROOT/Framework/src" -type f -name '*.cpp' | sort)

  while IFS= read -r source; do
    index=$((index + 1))
    if [[ "$source" == *"/CubismShader_Metal.mm" ]]; then
      local patched_shader="$slice_root/CubismShader_Metal.mm"
      sed 's|id<MTLLibrary> shaderLib = \[device newLibraryWithURL:libraryURL error:nil\];|extern id<MTLLibrary> JoiLoadCubismShaderLibrary(id<MTLDevice> device, NSString* sourceName);\n    id<MTLLibrary> shaderLib = JoiLoadCubismShaderLibrary(device, @"MetalShaders");\n    if (!shaderLib \&\& libraryURL) { shaderLib = [device newLibraryWithURL:libraryURL error:nil]; }|' "$source" > "$patched_shader"
      perl -0pi -e 's@    // 5\.3以降.*?    // サンプラーの初期化@    // Joi uses the Cubism 5.2-compatible blend modes initialized above.\n    // サンプラーの初期化@s' "$patched_shader"
      source="$patched_shader"
    fi
    xcrun --sdk "$sdk" clang++ "${common_flags[@]}" -fno-objc-arc -c "$source" -o "$object_root/framework-$index.o"
  done < <(find "$SDK_ROOT/Framework/src/Rendering/Metal" -maxdepth 1 -type f -name '*.mm' | sort)

  xcrun --sdk "$sdk" clang++ "${common_flags[@]}" -fobjc-arc -c \
    "$RUNTIME_SOURCES/JoiCubismView.mm" \
    -o "$object_root/JoiCubismView.o"

  xcrun libtool -static -o "$slice_root/libJoiCubismRuntime.a" \
    "$object_root"/*.o \
    "$core_library"

  cp "$RUNTIME_SOURCES/JoiCubismView.h" "$slice_root/include/JoiCubismView.h"
  cp "$RUNTIME_SOURCES/module.modulemap" "$slice_root/include/module.modulemap"
}

build_slice \
  iphoneos \
  iphoneos \
  arm64-apple-ios17.0 \
  "$SDK_ROOT/Core/lib/ios/Release-iphoneos/libLive2DCubismCore.a"

build_slice \
  iphonesimulator \
  iphonesimulator \
  arm64-apple-ios17.0-simulator \
  "$SDK_ROOT/Core/lib/ios/Release-iphonesimulator-arm64/libLive2DCubismCore.a"

rm -rf "$OUTPUT"
xcodebuild -create-xcframework \
  -library "$BUILD_ROOT/iphoneos/libJoiCubismRuntime.a" \
  -headers "$BUILD_ROOT/iphoneos/include" \
  -library "$BUILD_ROOT/iphonesimulator/libJoiCubismRuntime.a" \
  -headers "$BUILD_ROOT/iphonesimulator/include" \
  -output "$OUTPUT"

echo "Created $OUTPUT"
