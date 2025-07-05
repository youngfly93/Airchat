# Airchat

<div align="center">
  <img src="logo.png" alt="Airchat Logo" width="128" height="128">
  
  **A Beautiful Floating AI Chat Window for macOS**
  
  [![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
  [![Xcode](https://img.shields.io/badge/Xcode-16.0+-blue.svg)](https://developer.apple.com/xcode/)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
</div>

## ✨ Features

- 🎯 **Menu Bar App**: Lives in your menu bar, no dock icon clutter
- 🪟 **Floating Window**: Beautiful glass morphism design with smooth animations
- ⌨️ **Global Shortcuts**: Quick access with `⌥ + Space` from anywhere
- 🤖 **Multiple AI Models**: Support for Gemini, Claude, GPT-4, and more
- 💭 **Thinking Mode**: Visualize AI reasoning process (Gemini models)
- 🖼️ **Multi-modal**: Text and image input support
- 🔍 **Web Search**: Enhanced responses with real-time web search
- 🔒 **Secure**: API keys stored safely in macOS Keychain
- ⚡ **Streaming**: Real-time response streaming with typewriter effect
- 📱 **Collapsible UI**: Compact (480×64) and expanded (360×520) modes

## 🎬 Demo

![Airchat Demo](demo.gif)

## 🚀 Quick Start

### Prerequisites

- macOS 14.0 or later
- Xcode 16.0 or later
- Swift 6.0

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/youngfly93/Airchat.git
   cd Airchat
   ```

2. **Open in Xcode**
   ```bash
   open Airchat.xcodeproj
   ```

3. **Build and Run**
   - Press `⌘R` in Xcode to build and run
   - The app will appear in your menu bar

4. **Setup API Keys**
   - Click the menu bar icon
   - Go to Settings to configure your API keys
   - Supports both OpenRouter and Google Gemini APIs

## 🤖 Supported AI Models

### OpenRouter API
- Google Gemini 2.5 Pro
- Claude 3.5 Sonnet
- GPT-4o
- O4 Mini High
- Llama 3.3 70B Versatile

### Google Gemini Direct API
- Gemini 2.5 Pro
- Gemini 2.0 Flash Thinking
- MiniMax M1

## ⚙️ Configuration

### API Keys Setup

The app supports two API providers:

1. **OpenRouter** (Proxy for multiple models)
   - Get your API key from [OpenRouter](https://openrouter.ai/)
   - Stored in Keychain as `ark_api_key`

2. **Google Gemini** (Direct API)
   - Get your API key from [Google AI Studio](https://aistudio.google.com/)
   - Stored in Keychain as `google_api_key`

### Global Shortcuts

- **Default**: `⌥ + Space` (Option + Space)
- **Customize**: Right-click menu bar icon → Settings → Keyboard Shortcuts

## 🏗️ Architecture

```
┌─────────────────────────┐
│  Status Bar (Menu)      │
│  ⟶ toggleFloating()     │
└──────────┬──────────────┘
           ▼
┌─────────────────────────┐
│  NSPanel / SwiftUI      │
│  • ChatWindow           │
│  • InputBar             │
│  • Animations           │
└──────────┬──────────────┘
           ▼
┌─────── ViewModel ───────┐
│  @Published messages    │
│  send(text)             │
│  stream(token)          │
└──────────┬──────────────┘
           ▼
┌───── Network Layer ─────┐
│  URLSession + async     │
│  SSE / Streaming        │
│  Multi-modal Support    │
└─────────────────────────┘
```

### Key Components

- **AirchatApp.swift**: Main app entry point with status bar management
- **ChatWindow.swift**: SwiftUI chat interface with glass morphism
- **ChatVM.swift**: ViewModel managing chat state and API interactions
- **ArkChatAPI.swift**: OpenRouter API client with SSE support
- **GeminiOfficialAPI.swift**: Direct Google Gemini API client
- **WindowManager.swift**: Singleton for window state management

## 🛠️ Development

### Building from Source

```bash
# Build
xcodebuild -project Airchat.xcodeproj -scheme Airchat build

# Run tests
xcodebuild -project Airchat.xcodeproj -scheme Airchat test

# Clean
xcodebuild -project Airchat.xcodeproj -scheme Airchat clean
```

### Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - Global keyboard shortcuts
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) - Markdown rendering
- [NetworkImage](https://github.com/gonzalezreal/NetworkImage) - Image loading and caching

## 🔒 Security & Privacy

- ✅ App Sandbox enabled with minimal permissions
- ✅ API keys stored securely in macOS Keychain
- ✅ Hardened Runtime for notarization
- ✅ No sensitive data logging
- ✅ Local processing with secure API communication

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 🙏 Acknowledgments

- Thanks to all AI model providers for their APIs
- Inspired by the need for quick AI access on macOS
- Built with love using SwiftUI and modern macOS technologies

## 📞 Support

If you encounter any issues or have questions:

- 🐛 [Report a bug](https://github.com/youngfly93/Airchat/issues)
- 💡 [Request a feature](https://github.com/youngfly93/Airchat/issues)
- 📧 Contact: [Your Email]

---

<div align="center">
  Made with ❤️ for the macOS community
</div>
