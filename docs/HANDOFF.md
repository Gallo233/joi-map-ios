# 新会话交接说明

## 仓库定位

这是 AIGuide 的 iOS SwiftUI 独立仓库。继续工作时优先围绕这个仓库，不再从旧 monorepo 的 Android、Expo/RN、backend 分支扩散。

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

## 当前建议的下一步

1. 把后端 LLM 接入做稳定：统一 API base URL、语言上下文、错误态、重试。
2. 收敛旧实验页：确认哪些 View 仍有入口，没入口的删除或归档。
3. 做真机 QA：定位、相机、语音、慢网、深色模式。
4. 提升行程生成质量：增加兴趣/时长/人群输入，避免泛泛介绍。
5. 建立景点知识库 schema：名称、别名、城市、国家、坐标、类型、可信来源、官方链接。

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
