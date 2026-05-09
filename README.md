# Blender for HarmonyOS

本仓库是 **Blender for HarmonyOS** 移植计划的 Meta 仓库。包含项目架构说明、多仓库导航、编译所需脚本、构建指引以及打包好的 `.hap` 文件。

> 💡 **注：**：本项目的诞生过程高度依赖了 AI 辅助（Vibe Coding），甚至这个文档也是 AI 帮我润色的。移植目前仍处于非常早期的阶段，请带着探索和宽容的心态体验！

---

## 🚀 直接体验（普通用户）

如果您只想看看 Blender 在鸿蒙上跑起来是什么样，无需自己编译代码：
请前往本仓库的 **[Releases](#)** 页面，下载最新打包好的 `.hap` 安装包，直接在您的 HarmonyOS 物理设备上安装即可。
安装方法详见： [OpenHarmony Linux 环境 SDK 使用说明](https://github.com/Zitann/HarmonyOS-Haps)

⚠️ **警告**：当前的移植版本极其早期，**功能残缺且非常容易崩溃**。目前仅供尝鲜、技术验证和 UI 展示，**绝对不能**用于生产环境或实际工作！

---

## 📂 源码与仓库结构

为了方便管理庞大的源码和多语言环境，本项目被拆分为三个核心仓库：

1. 📖 **[blender-harmonyos-meta](https://github.com/panedioic/blender-harmonyos-meta)**（当前仓库）：储存构建相关脚本、整体指南、依赖预编译包以及应用发布包（HAP）。
2. 🛠️ **[blender-harmonyos](https://github.com/panedioic/blender-harmonyos)**：包含经过鸿蒙化 Patch 修改后的 Blender 4.5 源码，负责输出核心引擎库 `libblender.so`。
3. 📱 **[blender-harmonyos-app](https://github.com/panedioic/blender-harmonyos-app)**：HarmonyOS ArkUI 胶水层前端，这是一个 DevEco Studio 工程，负责 UI 渲染、事件采集和最终打包。

---

## 🏗️ 项目架构简介

Blender 的鸿蒙移植参考了 Godot 等引擎的常见移动端移植方案：

1. **引擎库化**：我们将 Blender 编译为动态链接库（`libblender.so`）。
2. **生命周期拆分**：在 `creator.cc` 中屏蔽了标准的 `main` 函数，将其运行逻辑拆分为 `Blender_Init`、`Blender_Step` 等生命周期接口并对外暴露。
3. **渲染与通信**：
   - 鸿蒙前端利用 `NAPI` (`napi_init`) 调用暴露的接口驱动引擎主循环。
   - 图形层通过 **Vulkan** 将画面直接渲染至 ArkUI 的 `XComponent` 组件上。
   - 输入层在 ArkTS 侧监听并过滤屏幕触摸、鼠标和键盘事件，然后投递进 `libblender` 的 GHOST 系统队列。

---

## 🔨 编译指南

本章节将指引您从零开始编译适用于 HarmonyOS 的 Blender 4.5 版本。

### 1. 环境准备

开发采用的是 **Ubuntu 24.04 (WSL) + Windows** 混合开发模式：
- **Ubuntu (WSL)**：负责交叉编译 Blender 动态链接库及其庞杂的 C/C++ 三方依赖。
- **Windows**：运行 DevEco Studio，负责处理 HAP 工程（eTS 胶水层）的编译和签名打包。

#### 1.1 宿主机依赖安装 (Ubuntu)

首先，安装必需的系统构建工具：

```bash
sudo apt update
sudo apt install -y \
  build-essential git curl wget vim \
  cmake ninja-build meson \
  pkg-config autoconf automake libtool \
  python3 python3-pip python3-venv python3-dev \
  clang clang-format clang-tidy \
  llvm lld gdb valgrind \
  zip unzip tar \
  ca-certificates gnupg lsb-release \
  software-properties-common apt-transport-https

# 图形与本地基础库依赖
sudo apt install -y libgl-dev libegl-dev libgl1-mesa-dev libegl1-mesa-dev
```

**⚠️ Python 版本警告**：
Blender 4.5 需要精确依赖 **Python 3.11**。若需要顺带编译 CPython 的扩展依赖，宿主机中最好也拥有一份完整的 Python 3.11 工具链。建议使用 `pyenv` 隔离安装：

```bash
curl https://pyenv.run | bash
# 按终端提示把 pyenv 加到环境变量中，然后执行：
pyenv install 3.11.11
pyenv global 3.11.11
python3 --version
```
*请务必记住宿主机中 Python 3.11 的安装路径。*

#### 1.2 配置 OHOS NDK

参考官方文档 [OpenHarmony Linux 环境 SDK 使用说明](https://gitcode.com/openharmony-sig/tpc_c_cplusplus/blob/master/lycium/doc/ohos_use_sdk/OHOS_SDK-Usage.md) 获取 NDK。

解压后，请在 `~/.bashrc` 或 `~/.zshrc` 中注入环境变量（根据实际路径修改）：

```bash
export OHOS_SDK=~/ohos-sdk/linux
```

#### 1.3 准备 Lycium 构建框架

对于巨量三方库的交叉编译，我们推荐使用 OpenHarmony 官方支持的 **Lycium** 构建工具：

```bash
cd ~
git clone https://gitcode.com/openharmony-sig/tpc_c_cplusplus.git
```

---

### 2. 编译三方库依赖

Blender 是一个庞然大物，即使在早期移植阶段关闭了非必要的模块，为了保证基础运行（如 Python 解释器、基础文件读写和图片编解码），仍需要编译大量依赖库。

**依赖清单**：
`boost`, `brotli`, `bzip2`, `cpython`, `fmt`, `freetype`, `gdbm`, `gettext`, `Imath`, `jbigkit`, `libdeflate`, `libepoxy`, `libffi`, `libjpeg-turbo`, `libpng`, `libtiff`, `libuuid`, `libwebp`, `ncurses`, `oneTBB`, `openexr`, `openimageio`, `openssl`, `readline`, `shaderc`, `sqlite`, `tcl`, `tiff`, `xz`, `zlib`, `zstd`

> *有些是blender直接的依赖，有些是blender的依赖的依赖，有些是依赖的依赖的依赖......不一定每个都严格必需，但为了避免麻烦，我建议把它们全编译了。*

#### 方式 A：自己动手编译
你可以 clone 我的依赖配方仓库获取 `HPKBUILD` 移植脚本：
```bash
git clone https://github.com/panedioic/blender-harmonyos-lib.git
```
*(部分配方基于开源社区提供，部分由 AI 辅助手搓完善)*。获取后，到 Lycium 目录下逐一构建：
```bash
cd ~/tpc_c_cplusplus/lycium
./build.sh <library_name>
```
产物将会输出在 `${LYCIUM}/usr` 目录下。

#### 方式 B：使用预编译包（推荐懒人使用）🚀
编译所有这些依赖耗时极长，因此我之后也会将预编译的三方库文件上传。您可以直接下载并解压到环境相应的存放目录下即可。

---

### 3. 核心 `libblender.so` 编译

#### 3.1 获取源码及脚本
新建专门的目录用于存放引擎层代码：
```bash
mkdir -p ~/blender-git && cd ~/blender-git
# clone 修改过后的 blender 源码
git clone https://github.com/panedioic/blender-harmonyos.git blender
```

从当前（meta）仓库中，将预配置好的 `build-host.sh` 和 `build-ohos.sh` 脚本拷入 `~/blender-git/` 目录。

#### 3.2 宿主机（Host）工具链编译
因为跨平台交叉编译时，目标平台的可执行工具无法在宿主 Ubuntu 上运行。Blender 需要先用宿主环境编译出如 `makesdna`、`makesrna`、`datatoc`、`glsl_preprocess` 等预处理工具。

在 `blender` 目录下执行：
```bash
../build-host.sh
```
成功后，在 `blender-git/build-host/bin/` 下会生成这些二进制预处理工具。此时宿主的 blender 完整产物可能并不能跑，这不需要在意，拿到上述生成工具即可。

#### 3.3 目标平台（OHOS）编译
在确认 Host 工具和三方依赖都就绪后，执行鸿蒙目标平台的构建：
```bash
../build-ohos.sh
```
一切顺利的话，您就可以在 `blender-git/build-ohos/lib/` （或对应输出路径）得到最为关键的 `libblender.so`！

---

### 4. DevEco Studio App 工程组装打包

在您的 Windows 主机上，克隆前端应用工程代码：
```bash
git clone https://github.com/panedioic/blender-harmonyos-app.git
```

该工程代码一般无需二次开发修改。您只需完成拼装和签名：

1. **放入库文件**：将上面编译出的 `libblender.so`，连同各种必须要的三方 `.so` 动态库，拷入 App 工程的 `entry/libs/arm64-v8a/` 目录下。（此仓库中提供了一个 `copy_so.sh` 脚本，可快速帮您筛选复制必要的库文件）。
2. **构建与运行**：使用 DevEco Studio 打开工程，在 IDE 中连接您的真机设备。配置好个人开发者签名（Auto Sign），最后点击右上角的绿色三角形（Run），稍等片刻，Blender 的熟悉画面就会出现在您的设备上了！ 🎉
