# TechListen - 技术播客逐句精听与精读应用

基于 SwiftUI 与 iOS Liquid Glass 设计系统构建的现代播客逐句精听与精读 iOS 应用。

<p align="center">
  <img src="logo_designs/logo.svg" alt="TechListen Logo" width="120" height="120" />
</p>

---

## 🌟 核心特性

### 1. 逐句播放控制与状态机
- **单句精听**：点击播放当前句子，播完自动暂停，便于反复琢磨与练习听力。
- **快速切换**：支持快速上句/下句跳转、速率调节（0.5x ~ 2.0x）、句子微调进度滑块。
- **进度展示**：精确展示句子序号（如 `12 / 180`）及句子播放耗时/总长。

### 2. 交互式单词遮盖与刮开 (Mask & Reveal)
- **遮词记忆**：支持一键隐藏台词中的重点词汇。
- **手势刮开**：支持单点点击与手势连续滑动刮开遮罩，配合触感反馈（Haptics）。
- **智能重置与联动**：切句自动重置遮罩，全词揭晓后自动联动遮罩按钮状态。

### 3. 全文台词与时间戳抽屉
- **抽屉视图**：随时上滑展开完整双语/英文字幕台词。
- **定位高亮**：跟随播放进度智能滚动并平滑高亮当前句子。
- **任意跳转**：点击任意句子无缝切换音频时间戳并开始播放。

### 4. 离线缓存与后台下载
- **单集离线**：支持单集音频文件与 VTT/JSON 台词文件的后台异步下载。
- **实时进度**：列表卡片与播放器均支持展示下载进度百分比、已下载标志与缓存删除。
- **缓存管理**：在设置页实时统计磁盘占用，支持一键安全清理。

### 5. Liquid Glass 玻璃拟态设计
- 基于 iOS 26 Liquid Glass 设计系统，多层 `.ultraThinMaterial` 折射高光与弥散阴影。
- 异形悬浮底部导航栏（Shaped Glass Tab Bar），中央凸起流体玻璃播放/暂停快捷胶囊。

---

## 🏗️ 架构分层 (Clean Architecture)

项目遵循严格的 4 层 Clean Architecture 分层体系：

```text
GlassNav/
├── App/                         # 应用入口与依赖注入容器 (AppContainer)
├── Core/                        # 语言本地化、基础类型
├── Domain/                      # 业务实体与纯协议接口
│   ├── Models/                  # Episode, TranscriptSegment 等业务模型
│   └── Interfaces/              # Repository, Player, Cache, State 等协议
├── Data/                        # 协议具体实现
│   ├── Parsers/                 # RSS 聚合解析与 VTT 字幕解析
│   ├── Repositories/            # 远程 RSS 与本地文件仓储
│   └── Services/                # 音频播放、下载管理、缓存与全局状态
├── ViewModels/                  # 视图业务逻辑状态机 (Home, Settings, Player)
├── Views/                       # 原生 SwiftUI 视图层
│   ├── Home/                    # 节目列表与单集卡片
│   ├── Player/                  # 播放器主界面、精听控制区、遮词与台词抽屉
│   ├── Navigation/              # 异形流体悬浮导航栏 (ShapedGlassTabBar)
│   └── Settings/                # 设置页面
└── Style/ & Modifiers/          # Liquid Glass 设计系统与样式修饰符
```

---

## 🧪 自动化测试

项目内建完整的单元与状态机测试套件（`GlassNavTests`），覆盖：
- 架构层依赖注入与模块可替换性测试
- 逐句播放控制状态机（`SentencePlaybackState`）
- RSS / 字幕解析与配置重置逻辑

运行测试命令：
```bash
xcodebuild -project GlassNav.xcodeproj -scheme GlassNav -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test CODE_SIGNING_ALLOWED=NO
```

---

## 🚀 编译与运行

1. 确保已安装 Xcode 16+ / macOS Sequoia。
2. 打开 `GlassNav.xcodeproj`。
3. 选择 iOS 模拟器（如 iPhone 17 Pro / iPhone 16 Pro）或真机。
4. 按 `Cmd + R` 构建并运行。

---

## 📄 文档索引

- [产品设计规划 (PRODUCT.md)](docs/PRODUCT.md)
- [设置规范 (SETTINGS.md)](docs/SETTINGS.md)
