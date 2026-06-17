#!/bin/bash
set -x -v -e
# Andre addded the single line above
# Andre commented out the single line below
# set -xe
cd "$(dirname "$0")"
export BUILDER_ROOT="$(pwd)"
export FFBUILD_PREFIX="/clang64/ffbuild"
export CMAKE_POLICY_VERSION_MINIMUM="3.5"

arch="x86_64"
TARGET="win64-clang"
VARIANT="gpl"

# Copy libc++ & libunwind to our prefix folder
mkdir -p /clang64/ffbuild/lib
cp /clang64/lib/libc++.a /clang64/ffbuild/lib/libc++.a
cp /clang64/lib/libunwind.a /clang64/ffbuild/lib/libunwind.a

cd "$BUILDER_ROOT"/PKGBUILD
for pkg in *; do
    if [ -d "$pkg" ]; then
        echo "Installing $pkg"
        cd "$pkg"

        (MINGW_ARCH=clang64 makepkg-mingw -sLfi --noconfirm --skippgpcheck) || exit $?

        cd ..
      fi
done

cd "$BUILDER_ROOT"
cd ..
if [[ -f "debian/patches/series" ]]; then
    ln -s debian/patches patches
    quilt push -a
fi

# On Windows, included headers are usually case-insensitive:
# ffmpeg's VERSION and libc++'s "#include <version>"
if [[ -f "VERSION" && -f "ffbuild/version.sh" ]]; then
    mv VERSION{,.bak}
    sed -i "s/cat VERSION/&.bak/g" ffbuild/version.sh
fi

# Andre changed
# from
#   --pkg-config-flags=--static
# to
#   --pkg-config-flags=--shared
#
PKG_CONFIG_PATH=/clang64/ffbuild/lib/pkgconfig ./configure \
    --cc=clang \
    --cxx=clang++ \
    --pkg-config-flags=--static \
    --extra-cflags=-I/clang64/ffbuild/include \
    --extra-ldflags=-L/clang64/ffbuild/lib \
    --prefix=/clang64/ffbuild/jellyfin-ffmpeg \
    --extra-version=Jellyfin \
    --enable-shared \
    --disable-unstable \
    --disable-ffplay \
    --disable-debug \
    --disable-doc \
    --disable-sdl2 \
    --enable-lto=thin \
    --enable-gpl \
    --enable-version3 \
    --enable-schannel \
    --enable-iconv \
    --enable-libxml2 \
    --enable-zlib \
    --enable-lzma \
    --enable-gmp \
    --enable-chromaprint \
    --enable-libfreetype \
    --enable-libfribidi \
    --enable-libfontconfig \
    --enable-libharfbuzz \
    --enable-libass \
    --enable-libbluray \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libtheora \
    --enable-libvorbis \
    --enable-libopenmpt \
    --enable-libwebp \
    --enable-libvpx \
    --enable-libzimg \
    --enable-libx264 \
    --enable-libx265 \
    --enable-libsvtav1 \
    --enable-libdav1d \
    --enable-libfdk-aac \
    --enable-libshaderc \
    --enable-libplacebo \
    --enable-vulkan \
    --enable-opencl \
    --enable-dxva2 \
    --enable-d3d11va \
    --enable-d3d12va \
    --enable-amf \
    --enable-libvpl \
    --enable-ffnvcodec \
    --enable-cuda \
    --enable-cuda-llvm \
    --enable-cuvid \
    --enable-nvdec \
    --enable-nvenc

make -j$(nproc) V=1

# We have to manually match lines to get version as there will be no dpkg-parsechangelog on msys2
PKG_VER=0.0.0
while IFS= read -r line; do
    if [[ $line == jellyfin-ffmpeg* ]]; then
        if [[ $line =~ \(([^\)]+)\) ]]; then
            PKG_VER="${BASH_REMATCH[1]}"
            break
        fi
    fi
done < "$BUILDER_ROOT"/../debian/changelog

PKG_NAME="jellyfin-ffmpeg_${PKG_VER}_portable_${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}"
# Andre added the one line ...
PKG_NAME2="jellyfin-ffmpeg_${PKG_VER}_shared_portable_${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}"
ARTIFACTS_PATH="$BUILDER_ROOT"/artifacts
# Andre added the one line ...
ARTIFACTS_PATH2="$BUILDER_ROOT"/artifacts2
OUTPUT_FNAME="${PKG_NAME}.zip"
# Andre added the one line ...
OUTPUT_FNAME2="${PKG_NAME2}-shared.zip"
cd "$BUILDER_ROOT"
mkdir -p artifacts
mv ../ffmpeg.exe ./
mv ../ffprobe.exe ./
zip -9 -r "${ARTIFACTS_PATH}/${OUTPUT_FNAME}" ffmpeg.exe ffprobe.exe
cd "$BUILDER_ROOT"/..

# Andre added the code section ... any .dll and .exe (other than ffmpeg.exe ffprob.exe)
cd "$BUILDER_ROOT"
mkdir -p                                                                         artifacts2
if [ $(ls ../*.exe > /dev/null 2>&1 && echo 0) ]; then cp    ../*.exe            artifacts2/; fi
if [ $(ls ../*.dll > /dev/null 2>&1 && echo 0) ]; then cp    ../*.dll            artifacts2/; fi
#                            also copy the directory itself "PKGBUILD" (with the contents)
if [ -d "PKGBUILD" ];                             then cp -R PKGBUILD            artifacts2/; fi
if [ -d "${FFBUILD_PREFIX}" ];                    then mkdir -p                  artifacts2${FFBUILD_PREFIX}  ; fi
#                                copy the contents
if [ -d "${FFBUILD_PREFIX}" ];                    then cp -R ${FFBUILD_PREFIX}/. artifacts2${FFBUILD_PREFIX}/ ; fi
pushd                                                                            artifacts2
zip -9 -r "${ARTIFACTS_PATH2}/${OUTPUT_FNAME2}"                                  .
popd                                                                      # from artifacts2
cd "$BUILDER_ROOT"/..

if [[ -n "$GITHUB_ACTIONS" ]]; then
    echo "build_name=${BUILD_NAME}" >> "$GITHUB_OUTPUT"
    echo "${OUTPUT_FNAME}" > "${ARTIFACTS_PATH}/${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}.txt"
    # Andre added the single line
    echo "${OUTPUT_FNAME2}" > "${ARTIFACTS_PATH2}/${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}-shared.txt"
fi
