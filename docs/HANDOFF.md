# 新会话交接说明

## 仓库定位

这是 Joi Map 的 iOS SwiftUI 独立仓库。继续工作时优先围绕这个仓库，不再从旧 monorepo 的 Android、Expo/RN、backend 分支扩散。

## 当前最重要的代码入口

- `AIGuide/ContentView.swift`：主 Tab 和 Settings。
- `AIGuide/Views/GuideView.swift`：导览主界面、地图、抽屉、POI 介绍和追问。
- `AIGuide/Services/GuideViewModel.swift`：导览状态、定位、附近候选、后端连接。
- `AIGuide/Views/SeeAndAskView.swift`：识景 UI。
- `AIGuide/Services/SeeAndAskService.swift`：识景和问答逻辑。
- `AIGuide/Views/TripPlannerView.swift`：行程 UI。
- `AIGuide/Services/TripPlannerService.swift`：搜索目的地、生成行程、缓存行程。
- `AIGuide/Services/LocalizationService.swift`：语言上下文和 L10n。
- `AIGuide/Localizable.xcstrings`：五语言文案。
- `AIGuide/Character/`：Joi 角色状态和 SwiftUI/Live2D 桥接。
- `Vendor/Live2D/`：Cubism XCFramework、Objective-C++ 运行时源码、许可证和接入说明。
- `scripts/build_live2d_runtime.sh`：使用官方 Cubism SDK 重建运行时。

## 当前建议的下一步

1. 完善 Joi 角色包：补齐 Motion、Expression、Physics、Pose，再将导览状态映射到原生动作组；当前程序化动作仅作为 fallback。
2. 接真实后端做端到端联调：客户端已统一 API base URL、语言上下文、错误解析和重试；下一步需要确认部署地址、接口 schema、限流错误和 UI 提示。
3. 做真机 QA：定位、相机、语音、Live2D 性能、慢网、深色模式。
4. 收敛旧实验页：确认哪些 View 仍有入口，没入口的删除或归档。
5. 提升行程生成质量，并建立带可信来源的景点知识库 schema。

## 构建命令

```bash
xcodebuild \
  -project AIGuide.xcodeproj \
  -scheme AIGuide \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/AIGuideDerived \
  build
```

## 本地化检查

```bash
python3 -m json.tool AIGuide/Localizable.xcstrings >/dev/null
```

新加文案时不要直接写死可见中文/英文，优先加到 `Localizable.xcstrings`，并补齐 `zh-Hans`、`zh-Hant`、`en`、`ja`、`ko`。

## 安全注意

不要把真实 API key 写进客户端仓库。模型 key 应该放到后端或本机环境变量里，通过后端代理调用。
