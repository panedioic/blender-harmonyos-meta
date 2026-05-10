import os
import glob
import subprocess

# ==================== 配置区 ====================
ROOT_PATH = "/home/seina/tpc_c_cplusplus/lycium/usr"
OUTPUT_DIR = os.path.expanduser("~/ohos_export_libs")
READELF_PATH = "/home/seina/ohos-sdk/linux/native/llvm/bin/llvm-readelf"
ARCH = "arm64-v8a"

# 把你所有的依赖库全写在这里，脚本会一次性把它们全部处理完（可能有遗漏，请根据实际情况补充）
input_libs = [
    "boost",
    "libdeflate",
    "fmt",
    "openexr",
    "libjpeg-turbo",
    "xz",
    "openimageio",
    "libpng",
    "libtiff",
    "oneTBB",
    "libwebp",
    "zlib",
    "zstd"
]
# ================================================

print(f"📦 准备修复！清洗后的纯净实体库将存放在: {OUTPUT_DIR}")
os.makedirs(OUTPUT_DIR, exist_ok=True)

# 1. 扫描所有的库文件（包括真身和软链接），并按它们指向的真身进行分组
real_to_aliases = {}

for lib_name in input_libs:
    lib_dir = os.path.join(ROOT_PATH, lib_name, ARCH, 'lib')
    for file_path in glob.glob(os.path.join(lib_dir, "*.so*")):
        # os.path.realpath 会直接穿透软链接，找到真正的物理文件
        real_path = os.path.realpath(file_path)
        if real_path not in real_to_aliases:
            real_to_aliases[real_path] = set()
        # 把文件名（别名）记录下来
        real_to_aliases[real_path].add(os.path.basename(file_path))

# 2. 遍历每一个真实的物理库，进行内存读取、补丁并在多别名下生成副本
for real_path, aliases in real_to_aliases.items():
    if not os.path.exists(real_path):
        continue
        
    primary_name = os.path.basename(real_path)
    
    # 调用 readelf 分析 NEEDED 字段
    cmd = f"{READELF_PATH} -d {real_path}"
    try:
        output = subprocess.check_output(cmd, shell=True, text=True)
    except Exception as e:
        print(f"❌ 无法读取 {primary_name} 的 ELF 头: {e}")
        continue
        
    bad_needed = []
    # 解析含有路径前缀的异常 NEEDED (特征：名字里带有 '/')
    for line in output.split('\n'):
        if "(NEEDED)" in line:
            start = line.find('[')
            end = line.find(']')
            if start != -1 and end != -1:
                needed_lib = line[start+1:end]
                if '/' in needed_lib:
                    bad_needed.append(needed_lib)

    # 按照二进制模式读取真实的库文件数据
    with open(real_path, 'rb') as f:
        data = bytearray(f.read())
        
    print(f"\n=======================================================")
    print(f"🔍 处理源库: {primary_name}")
    print(f"📋 将生成 {len(aliases)} 份物理副本: {', '.join(aliases)}")
    
    modified = False
    if bad_needed:
        for bad_str in bad_needed:
            good_str = bad_str.split('/')[-1]
            
            # 转换为字节并进行无损等长填充 (用 \0 补齐多余字符)
            bad_bytes = bad_str.encode('utf-8')
            good_bytes = good_str.encode('utf-8')
            padded_bytes = good_bytes + b'\x00' * (len(bad_bytes) - len(good_bytes))
            
            if bad_bytes in data:
                data = data.replace(bad_bytes, padded_bytes)
                modified = True
                print(f"   ✅ [FIXED] {bad_str} -> {good_str}")
            else:
                print(f"   ⚠️ [WARNING] 在二进制中未能找到: {bad_str}")
    else:
        print(f"   ✅ 该库 NEEDED 干净，无需二进制修复，直接裂解生成副本。")

    # 核心：将处理后的内存数据，以所有的别名写成**真正的独立文件**！
    # 彻底告别 Windows 不识别软链接导致变 1KB 文件的梦魇！
    for alias in aliases:
        out_path = os.path.join(OUTPUT_DIR, alias)
        with open(out_path, 'wb') as f:
            f.write(data)

# 最后，不要忘了把 libblender.so 也拷贝到输出目录（回头补上）