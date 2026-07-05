# AIGuide iOS

AIGuide 是一个 SwiftUI 原生 iOS App 原型，目标是做“现场感知型 AI 讲解员”：它根据定位、地图候选、拍照识别和用户追问，给出可播放、可追问、带来源的景点/展馆讲解。

当前仓库只保留 iOS SwiftUI 版本，方便后续继续打磨和发布。Android、Expo/RN、backend 实验线没有放进这个仓库。

## 当前状态

已具备可运行 MVP：

- 导览：MapKit 地图、定位状态、附近文化路线、抽屉讲解、来源/纠错/追问入口。
- 识景：拍照/相册入口、本地 Vision fallback、后端视觉识别接入位、候选结果与追问。
- 行程：搜索景点生成行程、推荐路线、历史行程、每日回顾、行程播放。
- 设置：讲解风格、语音、地图样式、语言、外观模式、后端诊断、离线内容和缓存管理。
- 本地化：简体中文、繁体中文、英文、日文、韩文 string catalog；App 内手动语言切换已接入 SwiftUI 环境。
- 视觉打磨：底部浮动 tab、导览抽屉、多 detent、主页面风格统一、旧入口 Route 页基础本地化。

详见：

- [产品路线图](docs/PRODUCT_ROADMAP.md)
- [完成与未完成清单](docs/STATUS.md)
- [新会话交接说明](docs/HANDOFF.md)

## 构建要求

- Xcode 17 或兼容 iOS 26 Simulator 的版本
- iOS 17.0+
- SwiftUI + MapKit + Vision + AVFoundation + Speech

## 快速构建

```bash
xcodebuild \
  -project AIGuide.xcodeproj \
  -scheme AIGuide \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AIGuideDerived \
  build
```

安装到当前 booted 模拟器：

```bash
xcrun simctl install booted /tmp/AIGuideDerived/Build/Products/Debug-iphonesimulator/AIGuide.app
xcrun simctl launch booted com.ai-guide.app
```

## 目录结构

```text
AIGuide.xcodeproj/
AIGuide/
  AIGuideApp.swift
  ContentView.swift
  Info.plist
  InfoPlist.xcstrings
  Localizable.xcstrings
  Models/
  Services/
  Views/
docs/
  PRODUCT_ROADMAP.md
  STATUS.md
  HANDOFF.md
```

## 配置说明

当前仓库不提交真实 API key。后端与模型服务应通过运行时配置、后端代理或本机环境变量注入。

后端地址可通过三种方式配置：

- `AIGUIDE_API_BASE_URL` / `AIGuideAPIBaseURL`：完整 API 根路径，例如 `https://example.com/api/v1`。
- `AIGUIDE_SERVER_URL` / `AIGuideServerURL`：服务根路径，客户端会自动追加 `/api/v1`，健康检查使用 `/health`。
- App 内“设置 > 后端”可保存服务根路径，适合测试服、真机和现场调试；支持省略局域网地址的 `http://`，保存后业务接口使用 `/api/v1`，健康检查使用 `/health`。

主要接入点：

- `AIGuide/Services/APIClient.swift`
- `AIGuide/Services/GuideViewModel.swift`
- `AIGuide/Services/SeeAndAskService.swift`
- `AIGuide/Services/TripPlannerService.swift`

## 注意事项

- Apple Maps 底图标签语言由系统/地图数据决定，不完全受 App string catalog 控制。
- 现阶段仍是 MVP 原型，核心体验可跑，但生产化还需要权限边界、错误恢复、真实内容源、隐私合规和端到端 QA。
