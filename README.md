# GlassNav - Minimalist SwiftUI Glassmorphic Navigation

基于最新 SwiftUI (iOS 17+ / Swift 6) 构建的现代极简玻璃拟态底部导航栏工程。

## 特性亮点

- **真实玻璃质感（Glassmorphism）**：
  - 基于 `.ultraThinMaterial` 材质。
  - 模拟真实光学折射的微高光渐变边缘（Specular Highlight Stroke Border）。
  - 双层柔和弥散环境阴影（Ambient Soft Shadow）。
- **流体动效与交互反馈**：
  - 采用 `matchedGeometryEffect` 与 `snappy` 弹簧曲线，实现流体胶囊平滑切换。
  - 内置原生触觉反馈（`.sensoryFeedback(.selection)`）。
  - 动态 SF Symbol 切换动效（`.symbolEffect(.replace)`）。
- **极致 Clean Code 架构**：
  - 纯原生 SwiftUI，零三方库依赖。
  - 严格模块分层：`Models`、`Modifiers`、`Views`。
  - 视图像素级修饰符 `.glassCapsule()` / `.glassBackground()` 完全解耦，支持全局复用。
  - 页面画布无多余业务干扰，仅保留底部悬浮玻璃导航。

## 目录结构

```text
GlassNav/
├── project.yml                       # XcodeGen 规范文件
├── GlassNav.xcodeproj                # 生成的标准 Xcode 工程文件
└── GlassNav/
    ├── App/
    │   └── GlassNavApp.swift         # App 入口
    ├── Models/
    │   └── TabItem.swift             # 导航项定义 (Sendable, CaseIterable)
    ├── Modifiers/
    │   └── GlassModifier.swift       # 可复用玻璃拟态修饰符 (.glassCapsule)
    └── Views/
        ├── RootContentView.swift     # 极简背景画布与导航挂载
        └── Navigation/
            ├── GlassTabBar.swift     # 悬浮玻璃底部导航栏组件
            └── GlassTabItem.swift    # 导航项交互视图
```

## 快速运行

- 使用 Xcode 打开 `GlassNav.xcodeproj` 即可在画布（Canvas）中直接预览 `#Preview`。
- 或在命令行中重新生成工程：
  ```bash
  xcodegen generate
  ```
