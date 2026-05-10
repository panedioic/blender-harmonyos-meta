#!/usr/bin/env bash
# build-host.sh
# Don't forget chmod +x ./build-host.sh !

START=$(date +%s%N)   # 计时

# 进入目录
cd ~/blender-git
rm -rf build-host
mkdir build-host
cd blender

# 设置 blender 宿主环境依赖路径
export BLENDER_LIB_BASE="~/blender-git/blender/lib/linux_x64"

# 构建
cmake -S . -B ../build-host \
  -DCMAKE_EXE_LINKER_FLAGS="\
  -L${BLENDER_LIB_BASE}/openexr/lib -Wl,-rpath,${BLENDER_LIB_BASE}/openexr/lib\
  -L${BLENDER_LIB_BASE}/imath/lib -Wl,-rpath,${BLENDER_LIB_BASE}/imath/lib\
  -L${BLENDER_LIB_BASE}/tbb/lib -Wl,-rpath,${BLENDER_LIB_BASE}/tbb/lib\
  -L${BLENDER_LIB_BASE}/boost/lib -Wl,-rpath,${BLENDER_LIB_BASE}/boost/lib\
  -L${BLENDER_LIB_BASE}/openimageio/lib -Wl,-rpath,${BLENDER_LIB_BASE}/openimageio/lib \
  -L${BLENDER_LIB_BASE}/opencolorio/lib -Wl,-rpath,${BLENDER_LIB_BASE}/opencolorio/lib" \
  -C ./build_files/cmake/config/blender_lite.cmake \
  -DWITH_GHOST_X11=OFF \
  -DWITH_GHOST_WAYLAND=OFF \
  -DWITH_VULKAN_BACKEND=ON \
  -DWITH_PYTHON=ON \
  -DWITH_INTERNATIONAL=OFF \
  -DWITH_CYCLES=OFF \
  -DWITH_OPENMP=OFF \
  -DWITH_MEM_JEMALLOC=OFF \
  -DWITH_MEM_VALGRIND=OFF \
  -DWITH_BUILDINFO=OFF \
  -DWITH_IMAGE_OPENEXR=OFF \
  -DWITH_IMAGE_OPENJPEG=OFF \
  -DWITH_IMAGE_TIFF=OFF \
  -DWITH_IMAGE_WEBP=OFF \
  -DWITH_IMAGE_DDS=OFF \
  -DWITH_IMAGE_CINEON=OFF \
  -DWITH_IMAGE_HDR=OFF \
  -DWITH_OPENIMAGEIO=OFF \
  -DWITH_OPENEXR=OFF \
  -DWITH_OPENJPEG=OFF \
  -DWITH_TIFF=OFF \
  -DWITH_WEBP=OFF \
  -DWITH_DDS=OFF \
  -DWITH_CINEON=OFF \
  -DWITH_HDR=OFF \
  -DWITH_AUDASPACE=OFF \
  -DWITH_SDL=OFF \
  -DWITH_OPENAL=OFF \
  -DWITH_JACK=OFF \
  -DWITH_PULSEAUDIO=OFF \
  -DWITH_COREAUDIO=OFF \
  -DWITH_WASAPI=OFF \
  -DWITH_ALEMBIC=OFF \
  -DWITH_USD=OFF \
  -DWITH_BULLET=OFF \
  -DWITH_OPENSUBDIV=OFF \
  -DWITH_OPENVDB=OFF \
  -DWITH_NANOVDB=OFF \
  -DWITH_MOD_FLUID=OFF \
  -DWITH_MOD_OCEANSIM=OFF \
  -DWITH_SIMULATION_DATABLOCK=OFF \
  -DWITH_BOOST=OFF \
  -DWITH_TBB=OFF \
  -DWITH_POTRACE=OFF \
  -DWITH_HARU=OFF \
  -DWITH_LZMA=OFF \
  -DWITH_LZO=OFF \
  -DWITH_SNDFILE=OFF \
  -DWITH_FFTW3=OFF \
  -DWITH_XR_OPENXR=OFF \
  -DWITH_HEADLESS=OFF \
  -DWITH_UI_TESTS=OFF \
  -DWITH_GHOST_DEBUG=OFF \
  -DCMAKE_BUILD_TYPE=Debug

# 编译
cmake --build ../build-host --target blender -j$(nproc)

END=$(date +%s%N)
DURATION=$(( (END - START) / 1000000 ))
echo "耗时: ${DURATION}ms"


