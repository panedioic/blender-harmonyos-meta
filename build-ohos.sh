#!/usr/bin/env bash
# build-ohos.sh
# Don't forget chmod +x ./build-ohos.sh !

set -e
START=$(date +%s%N)

# ================================================================
# 0. 环境变量
# ================================================================
export OHOS_SDK=/home/suwan/ohos-sdk/linux
export OHOS_TOOLCHAIN="$OHOS_SDK/native/build/cmake/ohos.toolchain.cmake"
export OHOS_CMAKE=${OHOS_SDK}/native/build-tools/cmake/bin/cmake
export OHOS_NINJA=${OHOS_SDK}/native/build-tools/cmake/bin/ninja
export LYCIUM_USR=/home/suwan/tpc_c_cplusplus/lycium/usr
export OHOS_ARCH=arm64-v8a
ROOT=~/blender-git
BLENDER=$ROOT/blender
BUILD=$ROOT/build-ohos
BUILD_HOST=$ROOT/build-host
# 宿主机工具列表：所有需要在构建期被 CMake 当场执行的工具
# 后续如果再遇到新的 Exec format error，把工具名追加到这里即可
HOST_TOOLS=(datatoc datatoc_icon makesdna makesrna)

# ---------------- Python ----------------
export PY_VER=3.11
export PY_TARGET_ROOT=${LYCIUM_USR}/cpython_3.11.11/${OHOS_ARCH}
export PY_HOST_BIN=$(command -v python3.11 || command -v python3)
export PY_HOST_BIN=$HOME/.pyenv/versions/3.11.11/bin/python3

if [ ! -f "${PY_TARGET_ROOT}/lib/libpython${PY_VER}.a" ]; then
    echo "❌ libpython${PY_VER}.a not found at ${PY_TARGET_ROOT}/lib/"
    exit 1
fi
echo "  [PY] target = ${PY_TARGET_ROOT} (static)"
echo "  [PY] host   = ${PY_HOST_BIN}"

echo ""
echo "════════════════════════════════════════"
echo "  Step 1: 编译宿主机原生构建工具"
echo "════════════════════════════════════════"

# 检查标记文件，存在则跳过
# 打印宿主工具清单（方便调试）
echo "  📦 宿主 bin/ 目录内容:"
ls -la $BUILD_HOST/bin/

echo ""
echo "════════════════════════════════════════"
echo "  Step 2: 交叉编译 libblender.so"
echo "════════════════════════════════════════"
# disabled -D_GNU_SOURCE
#   -DCMAKE_C_FLAGS="-D__OHOS__=1 -D_GNU_SOURCE -Wno-unused-command-line-argument"       \
#   -DCMAKE_CXX_FLAGS="-D__OHOS__=1 -D_GNU_SOURCE -Wno-unused-command-line-argument"     \

rm -rf $BUILD && mkdir -p $BUILD
cd $BLENDER

${OHOS_CMAKE} -S . -B $BUILD -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE=$OHOS_TOOLCHAIN \
  -DCMAKE_MAKE_PROGRAM=${OHOS_NINJA} \
  -DOHOS_ARCH=$OHOS_ARCH          \
  -DOHOS_PLATFORM=OHOS            \
  -DOHOS_STL=c++_shared           \
  \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DWITH_ASSERT_ABORT=OFF \
  -DCMAKE_CROSSCOMPILING_EMULATOR=$BUILD/qemu-bridge.sh \
  \
  `# —— 关键：手动塞鸿蒙专属宏（因为 toolchain 里没有）——` \
  -D__OHOS__=1 \
  \
  `# —— 关键：骗过 Blender 的 platform 分发 ——` \
  -DPLATFORM_BUNDLED_LIBRARIES=OFF  \
  \
  `# —— GHOST 配置 ——` \
  -DWITH_GHOST_DUMMY=OFF   \
  -DWITH_GHOST_OHOS=ON \
  -DWITH_GHOST_X11=OFF    \
  -DWITH_GHOST_WAYLAND=OFF\
  -DWITH_GHOST_SDL=OFF    \
  -DWITH_VULKAN_BACKEND=ON \
  \
  `# —— Python (静态链接 lycium 产物) ——` \
  -DWITH_PYTHON=ON \
  -DWITH_PYTHON_INSTALL=OFF \
  -DWITH_PYTHON_INSTALL_NUMPY=OFF \
  -DWITH_PYTHON_MODULE=OFF \
  -DPYTHON_VERSION=${PY_VER} \
  -DPYTHON_INCLUDE_DIR=${PY_TARGET_ROOT}/include/python${PY_VER} \
  -DPYTHON_INCLUDE_DIRS=${PY_TARGET_ROOT}/include/python${PY_VER} \
  -DPYTHON_INCLUDE_CONFIG_DIR=${PY_TARGET_ROOT}/include/python${PY_VER} \
  -DPYTHON_LIBRARY=${PY_TARGET_ROOT}/lib/libpython${PY_VER}.a \
  -DPYTHON_LIBPATH=${PY_TARGET_ROOT}/lib \
  -DPYTHON_EXECUTABLE=${PY_HOST_BIN} \
  -DPYTHON_ROOT_DIR=${PY_TARGET_ROOT} \
  `# —— 阉割重依赖（同 Linux PoC）——` \
  -DWITH_CYCLES=OFF \
  -DWITH_BOOST=OFF -DWITH_TBB=OFF \
  -DWITH_AUDASPACE=OFF -DWITH_SDL=OFF -DWITH_OPENAL=OFF \
  -DWITH_ALEMBIC=OFF -DWITH_USD=OFF -DWITH_BULLET=OFF \
  -DWITH_OPENSUBDIV=OFF -DWITH_OPENVDB=OFF -DWITH_NANOVDB=OFF \
  -DWITH_MOD_FLUID=OFF -DWITH_MOD_OCEANSIM=OFF \
  -DWITH_INTERNATIONAL=OFF \
  -DWITH_MEM_JEMALLOC=OFF -DWITH_MEM_VALGRIND=OFF \
  -DWITH_IMAGE_OPENJPEG=OFF \
  -DWITH_IMAGE_WEBP=OFF \
  -DWITH_IMAGE_CINEON=OFF \
  -DWITH_XR_OPENXR=OFF -DWITH_HEADLESS=OFF \
  -DWITH_BUILDINFO=OFF -DWITH_POTRACE=OFF -DWITH_HARU=OFF \
  -DWITH_LZMA=OFF -DWITH_LZO=OFF -DWITH_FFTW3=OFF \
  -DWITH_CPU_SIMD=OFF \
  \
  `# —— libepoxy 静态库（避免 SONAME 陷阱）——` \
  -DWITH_SYSTEM_EPOXY=ON \
  -DEpoxy_INCLUDE_DIR=${LYCIUM_USR}/libepoxy/${OHOS_ARCH}/include \
  -DEpoxy_LIBRARY=${LYCIUM_USR}/libepoxy/${OHOS_ARCH}/lib/libepoxy.so \
  \
  -C $BLENDER/build_files/cmake/config/blender_lite.cmake

echo ""
echo "════════════════════════════════════════"
echo "  Step 4: 开始编译 (自动重试模式)"
echo "════════════════════════════════════════"
MAX_RETRY=10
RETRY=0
while [ $RETRY -lt $MAX_RETRY ]; do
    echo ""
    echo "  ▶ 第 $((RETRY + 1)) 次编译尝试..."
    set +e
    # $OHOS_CMAKE --build $BUILD --target blender -j$(nproc) 2>&1 | tee /tmp/ninja_output.txt
    $OHOS_NINJA -C $BUILD blender -j$(nproc) 2>&1 | tee /tmp/ninja_output.txt
    BUILD_EXIT=${PIPESTATUS[0]}
    set -e
    if [ $BUILD_EXIT -eq 0 ]; then
        echo ""
        echo "  ✅ 编译成功！"
        break
    fi
    # 提取报 Exec format error 的工具名
    NEW_TOOLS=$(grep -E "Exec format error|Syntax error.*unexpected" /tmp/ninja_output.txt \
        | grep -oP "(?<=$BUILD/bin/)[^: ]+" \
        | sort -u)
    if [ -z "$NEW_TOOLS" ]; then
        echo ""
        echo "  ❌ 编译失败（非 Exec format error），请检查上方日志。"
        END=$(date +%s%N)
        echo "  总耗时: $(( (END - START) / 1000000 )) ms"
        exit 1
    fi
    echo ""
    echo "  🔄 发现新的宿主工具需求: $NEW_TOOLS"
    REPLACED=0
    for tool in $NEW_TOOLS; do
        if [ -f "$BUILD_HOST/bin/$tool" ]; then
            cp -v "$BUILD_HOST/bin/$tool" "$BUILD/bin/$tool"
            echo "  ✅ 补注入: $tool"
            REPLACED=$((REPLACED + 1))
        else
            echo "  ❌ $tool 在宿主构建目录里不存在，无法自动处理。"
            END=$(date +%s%N)
            echo "  总耗时: $(( (END - START) / 1000000 )) ms"
            exit 1
        fi
    done
    if [ $REPLACED -eq 0 ]; then
        echo "  ❌ 没有成功替换任何工具，停止重试。"
        END=$(date +%s%N)
        echo "  总耗时: $(( (END - START) / 1000000 )) ms"
        exit 1
    fi
    RETRY=$((RETRY + 1))
done
if [ $RETRY -eq $MAX_RETRY ]; then
    echo "  ❌ 超过最大重试次数 ($MAX_RETRY)，请检查日志。"
    END=$(date +%s%N)
    echo "  总耗时: $(( (END - START) / 1000000 )) ms"
    exit 1
fi

echo ""
echo "════════════════════════════════════════"
echo "  Step 5: 校验 & 拷贝产物"
echo "════════════════════════════════════════"
SO_PATH=$(find $BUILD -name "libblender.so" -type f | head -1)
if [ -z "$SO_PATH" ]; then
    echo "  ❌ libblender.so 未找到！"
    END=$(date +%s%N)
    echo "  总耗时: $(( (END - START) / 1000000 )) ms"
    exit 1
fi
echo "  📦 产物: $SO_PATH"
echo "  🔍 导出符号:"
${OHOS_SDK}/native/llvm/bin/llvm-nm -D $SO_PATH | grep " T Blender_" || true

echo "  🔍 so文件:"
#/home/suwan/ohos-sdk/linux/native/llvm/bin/llvm-readelf -d /home/suwan/blender-git/build_ohos_aarch64/out/libblender.so | grep NEEDED
HAP_LIBS_DIR=$BUILD/out
mkdir -p ${HAP_LIBS_DIR}

# rm -f /mnt/c/myws/hm/teedemo//entry/libs/arm64-v8a/libblender.so
# cp /home/suwan/blender-git/build_ohos_aarch64/out/libblender.so /mnt/c/myws/hm/teedemo//entry/libs/arm64-v8a/libblender.so
# ================================================================
# 完成
# ================================================================
END=$(date +%s%N)
echo ""
echo "════════════════════════════════════════"
echo "  🎉 全部完成！"
echo "  总耗时: $(( (END - START) / 1000000 )) ms"
echo "  HAP 目录: ${HAP_LIBS_DIR}"
echo "════════════════════════════════════════"