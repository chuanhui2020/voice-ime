# VoiceIME

macOS 菜单栏语音输入应用。按住 Fn 键录音，松开后自动将识别文本注入当前活跃的应用程序。

## 功能特性

- 按住 Fn 键即录即停，松开自动输入
- 基于 Apple Speech 框架，支持设备端离线识别
- 支持 5 种语言：英语 (en-US)、简体中文 (zh-CN)、繁体中文 (zh-TW)、日语 (ja-JP)、韩语 (ko-KR)
- 可选的 LLM 后处理，自动纠正语音识别中的谐音错误和技术术语
- 实时波形动画和部分识别结果显示
- 自动处理 CJK/ASCII 输入法切换
- 剪贴板内容自动保存和恢复

## 项目架构

### 整体结构

```
FnKeyMonitor (CGEvent tap 监听 Fn 键)
       │
       ▼
AppDelegate (核心调度器，协调所有组件)
       │
  ┌────┴────┐
  ▼         ▼
AudioEngine    SpeechRecognizer
(AVAudioEngine   (SFSpeechRecognizer
 采集麦克风音频)    Apple 原生语音识别)
       │              │
       │         部分结果 → CapsuleWindow 实时显示
       │              │
       │         最终结果
       │              │
       ▼              ▼
  WaveformView    LLMService (可选的 LLM 后处理)
  (波形动画)           │
                      ▼
                 TextInjector
                 (剪贴板 + Cmd+V 注入文本)
```

### 源文件说明

| 文件 | 职责 |
|------|------|
| `main.swift` | 应用入口，设置菜单和代理 |
| `AppDelegate.swift` | 核心调度器，管理录音生命周期，协调所有组件 |
| `AudioEngine.swift` | 通过 AVAudioEngine 捕获麦克风音频，计算 RMS 用于波形可视化 |
| `SpeechRecognizer.swift` | 封装 Apple Speech 框架，处理语音转文字 |
| `LLMService.swift` | 调用 LLM API 对识别结果进行后处理纠错 |
| `TextInjector.swift` | 通过剪贴板 + Cmd+V 注入文本，处理输入法切换 |
| `FnKeyMonitor.swift` | 全局事件监听，检测 Fn 键按下/释放 |
| `CapsuleWindow.swift` | 录音时显示的浮动面板 |
| `CapsuleViewController.swift` | 浮动面板的视图控制器，显示文字和波形 |
| `WaveformView.swift` | 5 条柱状波形动画 |
| `StatusBarController.swift` | 菜单栏图标和下拉菜单（语言、LLM 设置、退出） |
| `LLMSettingsWindow.swift` | LLM 配置对话框 |
| `Settings.swift` | UserDefaults 封装，持久化配置 |
| `InputMethodUtils.swift` | 检测和切换 CJK/ASCII 输入法 |

### 数据流

```
用户按下 Fn 键
       │
       ▼
FnKeyMonitor 检测到 Fn 按下 (CGEvent tap)
       │
       ▼
AppDelegate.startRecording()
  ├── 显示 CapsuleWindow
  ├── 启动 AudioEngine（采集 1024 字节 PCM buffer）
  └── 启动 SpeechRecognizer（创建 SFSpeechAudioBufferRecognitionRequest）
       │
       ├── 实时返回部分识别结果 → 更新 CapsuleWindow 显示
       │
用户松开 Fn 键
       │
       ▼
AppDelegate.stopRecording()
  ├── 停止 AudioEngine
  └── 停止 SpeechRecognizer → 获取最终识别结果
       │
       ▼
AppDelegate.handleFinalResult()
  ├── 文本为空 → 隐藏浮窗，结束
  ├── LLM 未启用 → 直接注入原始文本
  └── LLM 已启用 → LLMService.refine() 纠错
       │
       ▼
TextInjector.inject()
  1. 保存当前剪贴板内容
  2. 检测当前输入法，CJK 则切换到 ASCII
  3. 将文本写入剪贴板
  4. 模拟 Cmd+V 粘贴
  5. 恢复输入法
  6. 200ms 后恢复剪贴板
       │
       ▼
文本注入到当前活跃应用
```

## 语音识别

基于 Apple 原生 `Speech` 框架（`SFSpeechRecognizer`），不依赖第三方服务：

- `AudioEngine` 使用 `AVAudioEngine` 捕获麦克风输入，1024 字节 PCM buffer 实时流式传输给识别器
- 优先使用设备端识别（`requiresOnDeviceRecognition = true`），降低延迟并支持离线使用
- 识别过程中实时返回部分结果更新 UI，提供即时反馈
- 最终结果取 `bestTranscription.formattedString`

## LLM 后处理

`LLMService` 调用 OpenAI 兼容的 `/chat/completions` 接口，对识别结果进行轻量纠错：

- 配置项：Base URL（需以 `/v1` 结尾）、API Key、Model，存储在 UserDefaults 中
- 参数：`temperature: 0.0`，`max_tokens: 2048`，10 秒超时
- System Prompt 根据当前语言动态生成（中文 prompt 处理中文场景），包含 few-shot 示例：
  - 修正中文谐音错误（同音字纠错）
  - 修正被误识别为中文的英文技术术语（如 配森→Python、杰森→JSON、爪哇→Java、西加加→C++），并鼓励 LLM 根据发音相似度自行推理
  - 不改写、不润色、不重组文本
  - 只返回修正后的文本，不附带解释
- 请求失败或返回空时，fallback 到原始识别文本
- 每次 LLM 调用的请求和响应记录在 `logs/llm_log.jsonl`，保留最近 100 条

## LLM 配置

在菜单栏图标的下拉菜单中打开 LLM Settings，填写：

- Base URL：OpenAI 兼容的 API 地址，需以 `/v1` 结尾（如 `https://api.openai.com/v1`）
- API Key：API 密钥
- Model：模型名称（如 `gpt-4o-mini`）

## 文本注入

`TextInjector` 通过剪贴板模拟粘贴实现文本注入：

1. 保存当前剪贴板内容，避免破坏用户数据
2. 检测当前输入法，如果是 CJK 输入法则临时切换到 ASCII，防止输入法干扰粘贴
3. 将识别文本写入剪贴板，通过 CGEvent 模拟 Cmd+V 粘贴
4. 恢复原始输入法和剪贴板内容（200ms 延迟确保粘贴完成）

## 构建与运行

```bash
# 构建并运行
make run

# 仅构建（生成 VoiceIME.app）
make build

# 安装到 /Applications
make install

# 清理构建产物
make clean
```

需要在系统设置中授予以下权限：
- 麦克风访问权限
- 语音识别权限
- 辅助功能权限（用于全局按键监听和模拟粘贴）

> 注意：每次重新构建后需要在系统设置 → 隐私与安全性 → 辅助功能中重新添加应用。
