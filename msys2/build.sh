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

# Andre added
# --enable-shared
# Andre removed - html - requires perl texinfo  - make html
# --disable-doc (ANDRE REMOVED)
#  keep some documentation but discard the rest
#  --disable-htmlpages (skips HTML files) - perl and then texinfo(texi2any) NOT DISABLED
#  --disable-manpages (skips terminal man pages)
#  --disable-podpages (skips Perl POD pages)
#  --disable-txtpages (skips plain text documentation)
# Andre removed - requires SDL2
# --disable-sdl2 \
# --disable-ffplay \
PKG_CONFIG_PATH=/clang64/ffbuild/lib/pkgconfig ./configure \
    --cc=clang \
    --cxx=clang++ \
    --pkg-config-flags=--static \
    --extra-cflags=-I/clang64/ffbuild/include \
    --extra-ldflags=-L/clang64/ffbuild/lib \
    --prefix=/clang64/ffbuild/jellyfin-ffmpeg \
    --extra-version=Jellyfin \
    --disable-manpages \
    --disable-txtpages \
    --disable-podpages \
    --enable-shared \
    --disable-unstable \
    --disable-debug \
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


# Andre added - require perl texinfo ( do not --disable-doc )
# make doc -- To skip compilation of the massive binary files 
#             and exclusively build the web docs, execute `make html` instead
# HTML files (including the central index manual) will materialize inside 
#   the doc/ subdirectory of your cloned Git folder.
# Andre added
# make html
# ls -alrt -R ..
# if [ -d "${PREFIX}" ]; then ls -alrt -R ${PREFIX} ; fi

make -j$(nproc) V=1

# Andre added
make doc
make install

# Andre added 
# make install-doc


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

# Andre added the code section
# Doing this early, so that the ffmpeg.exe and ffprobe.exe are not moved(mv) out of the root directory
# Andre added the one line ...
PKG_NAME2="jellyfin-ffmpeg_${PKG_VER}_shared_portable_${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}"
# Andre added the one line ...
ARTIFACTS_PATH2="$BUILDER_ROOT"/artifacts2
# Andre added the one line ...
OUTPUT_FNAME2="${PKG_NAME2}-shared.zip"
cd "$BUILDER_ROOT"
mkdir -p                                                                           artifacts2

# NOT WHAT I AM LOOKING FOR
# if [ $(ls ../*.exe > /dev/null 2>&1 && echo 0) ]; then cp    ../*.exe            artifacts2/; fi
# if [ $(ls ../*.dll > /dev/null 2>&1 && echo 0) ]; then cp    ../*.dll            artifacts2/; fi
# #                            also copy the directory itself "PKGBUILD" (with the contents)
# if [ -d "PKGBUILD" ];                             then cp -R PKGBUILD            artifacts2/; fi
# if [ -d "${FFBUILD_PREFIX}" ];                    then mkdir -p                  artifacts2${FFBUILD_PREFIX}  ; fi
# #                                copy the contents
# if [ -d "${FFBUILD_PREFIX}" ];                    then cp -R ${FFBUILD_PREFIX}/. artifacts2${FFBUILD_PREFIX}/ ; fi

# Andre trying to copy out what is useful
# build (results from "make")
# make
# "Files" section at the bottom
# https://packages.msys2.org/packages/mingw-w64-ucrt-x86_64-ffmpeg
# structure
# ffmpeg-n8.1-latest-win64-gpl-shared-8.1.zip
# https://github.com/BtbN/FFmpeg-Builds/releases
# old custom build
# https://github.com/AndreMikulec/jellyfin-ffmpeg/actions/runs/27672539025/job/81840015606
# old custom build log
# https://productionresultssa13.blob.core.windows.net/actions-results/af15059e-acd7-4e68-99a8-316a9a3c46cc/workflow-job-run-a259afe4-2ea5-5f56-9c34-14baa0cd6df6/logs/job/job-logs.txt?rsct=text%2Fplain&se=2026-06-18T18%3A25%3A31Z&sig=8LBDsWTWjd7NJ2auvYw1lWfj8VH30%2Fe0YtuVmsd454s%3D&ske=2026-06-18T19%3A49%3A52Z&skoid=ca7593d4-ee42-46cd-af88-8b886a2f84eb&sks=b&skt=2026-06-18T15%3A49%3A52Z&sktid=398a6654-997b-47e9-b12b-9515b896b4de&skv=2025-11-05&sp=r&spr=https&sr=b&st=2026-06-18T18%3A15%3A26Z&sv=2025-11-05
# Install path PREFIX
# https://trac.ffmpeg.org/wiki/CompilationGuide/Generic

# Andre added - trying to see the build
ls -alrt -R ..

# copy from ./configure (above)
export PREFIX=/clang64/ffbuild/jellyfin-ffmpeg

# Andre trying to see the install
ls -alrt -R ${PREFIX}

### NEVER TRIED - SHOULD WORK
# # mkdir -p                                                    artifact2/{lib,bin}
# # # build ../*[_g].exe # install ${MSYSTEM}/bin                                          
# # cp ../*.exe                                                 artifact2/bin
# # # build ./*.dll # install ${MSYSTEM}/bin                                               
# # cp ../${library}/bin/*.dll                                  artifact2/bin
# # mkdir -p                                                    artifact2/share/ffmpeg
# # # make install AND install-doc (everything else)
# # cp -R ${PREFIX}/share/ffmpeg/.                              artifact2/share/ffmpeg
# # # libraries in the for-do-done
# # mkdir -p                                                    artifact2/lib/pkgconfig
# # mkdir -p artifact2/include/{libavcodec,libavdevice,libavfilter,libavformat,libavutil,libswresample,libswscale}
# # #
# # for library in              libavcodec libavdevice libavfilter libavformat libavutil libswresample libswscale
# # do
# #   # build-only .lib .def .dll.objs
# #   cp ../${library}/*{.lib,.def}                             artifact2/lib
# #   # make install or # build ../${library}/${library}.dll.a
# #   cp ${PREFIX}/lib/lib${library}.dll.a                      artifact2/lib
# #   # install # .a not found in the "old shared custom build log" # not in shared BtbN .zip
# # # .a (static) xor .dll (shared)
# # # cp ${PREFIX}/lib/${library}.a                             artifact2/lib
# #   # make install                                            
# #   cp ${PREFIX}/lib/pkgconfig/${library}.pc                  artifact2/lib/pkgconfig
# #   # make install                                            
# #   cp ${PREFIX}/include/${library}/*.h                       artifact2/include/${library}
# # done

# better
cp                                    -R ${PREFIX}/{bin,lib,include}  artifacts2
if [ -d "${PREFIX}/share" ]; then cp - R ${PREFIX}/share              artifacts2 ; fi
if [ -d "${PREFIX}/doc" ];   then cp - R ${PREFIX}/doc                artifacts2 ; fi
if [ -d "../doc" ];          then cp - R ../doc                       artifacts2 ; fi

pushd                                                       artifacts2
zip -9 -r "${ARTIFACTS_PATH2}/${OUTPUT_FNAME2}"             .
popd                                                        # from artifacts2

cd "$BUILDER_ROOT"/..


if [[ -n "$GITHUB_ACTIONS" ]]; then
    echo "build_name=${BUILD_NAME}" >> "$GITHUB_OUTPUT"
    # Andre added the single line
    echo "${OUTPUT_FNAME2}" > "${ARTIFACTS_PATH2}/${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}-shared.txt"
fi


PKG_NAME="jellyfin-ffmpeg_${PKG_VER}_portable_${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}"
ARTIFACTS_PATH="$BUILDER_ROOT"/artifacts
OUTPUT_FNAME="${PKG_NAME}.zip"

cd "$BUILDER_ROOT"
mkdir -p artifacts
mv ../ffmpeg.exe ./
mv ../ffprobe.exe ./
zip -9 -r "${ARTIFACTS_PATH}/${OUTPUT_FNAME}" ffmpeg.exe ffprobe.exe
cd "$BUILDER_ROOT"/..

if [[ -n "$GITHUB_ACTIONS" ]]; then
    echo "build_name=${BUILD_NAME}" >> "$GITHUB_OUTPUT"
    echo "${OUTPUT_FNAME}" > "${ARTIFACTS_PATH}/${TARGET}-${VARIANT}${ADDINS_STR:+-}${ADDINS_STR}.txt"
fi
