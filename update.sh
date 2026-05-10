# 该脚本用于修改代码后避免重复编译整个blender使用。
# 使用时自行修改相关目录为自己的目录
START=$(date +%s%N)
/home/seina/ohos-sdk/linux/native/build-tools/cmake/bin/cmake --build ~/blender-git/build_ohos_aarch64 --target blender -j$(nproc)
rm /mnt/c/myws/hm/teedemo//entry/libs/arm64-v8a/libblender.so
cp /home/seina/blender-git/build_ohos_aarch64/lib/libblender.so /mnt/c/myws/hm/teedemo//entry/libs/arm64-v8a/libblender.so
END=$(date +%s%N)
echo "Time consumed: $(( (END - START) / 1000000 )) ms."