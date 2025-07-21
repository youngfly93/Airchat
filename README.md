# Airchat

<div align="center">
  <img src="logo.png" alt="Airchat Logo" width="128" height="128">
  
  **A Beautiful Floating AI Chat Window for macOS**
  
  [![macOS](https://img.shields.io/badge/macOS-14.0+-blue.svg)](https://www.apple.com/macos/)
  [![Swift](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org/)
  [![Xcode](https://img.shields.io/badge/Xcode-16.0+-blue.svg)](https://developer.apple.com/xcode/)
  [![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
  
  [📦 Download Latest Release](https://github.com/youngfly93/Airchat/releases/latest) • [🚀 Quick Start](#-quick-start) • [🤖 AI Models](#-supported-ai-models)
</div>

---

## ✨ Features

- 🎯 **Menu Bar App**: Lives in your menu bar, no dock icon clutter
- 🪟 **Floating Window**: Beautiful glass morphism design with smooth animations
- ⌨️ **Global Shortcuts**: Quick access with `⌥ + Space` from anywhere
- 🤖 **Multiple AI Models**: Support for OpenRouter, Gemini, Kimi/Moonshot AI and more
- 💭 **Thinking Mode**: Visualize AI reasoning process (Gemini models)
- 🖼️ **Multi-modal**: Text and image input support
- 🔍 **Web Search**: Enhanced responses with real-time web search
- 🔒 **Secure**: API keys stored safely in macOS Keychain
- ⚡ **Streaming**: Real-time response streaming with typewriter effect
- 📱 **Collapsible UI**: Compact (480×64) and expanded (360×520) modes
- 📝 **Text Compression**: Long pasted text automatically compressed for cleaner interface

## 🎬 Demo

Coming soon! Experience the elegant floating chat window with smooth animations and multi-modal AI interactions.

## 📦 Installation

### Option 1: Download DMG (Recommended)

1. **Download** the latest `Airchat-v1.0.0.dmg` from [GitHub Releases](https://github.com/youngfly93/Airchat/releases/latest)
2. **Open** the DMG file
3. **Drag** Airchat.app to your Applications folder
4. **Launch** from Applications or Spotlight
5. **Configure** your API keys in Settings

### Option 2: Build from Source

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

## 🤖 Supported AI Models

### OpenRouter API (Proxy)
- 🧠 **Google Gemini 2.5 Pro** - Advanced reasoning
- 💭 **Claude 3.5 Sonnet** - Creative and analytical 
- ⚡ **GPT-4o** - Fast and versatile
- 🔥 **O4 Mini High** - Optimized performance
- 🦙 **Llama 3.3 70B** - Open source powerhouse

### Google Gemini Direct API
- 🚀 **Gemini 2.5 Pro** - Latest flagship model
- ⚡ **Gemini 2.5 Flash** - Speed optimized
- 💭 **Gemini 2.0 Flash (Thinking)** - With reasoning visualization
- 🎯 **MiniMax-01** - Specialized tasks

### Kimi/Moonshot AI ✨ NEW
- 📚 **Kimi 8K** - Context: 8,000 tokens
- 📖 **Kimi 32K** - Context: 32,000 tokens  
- 📑 **Kimi 128K** - Context: 128,000 tokens

## ⚙️ Configuration

### API Keys Setup

The app supports three API providers:

#### 1. OpenRouter (Multiple Models via Proxy)
- 🔗 Get your API key from [OpenRouter](https://openrouter.ai/keys)
- 💾 Format: `sk-or-v1-...`
- 🗝️ Stored in Keychain as `ark_api_key`

#### 2. Google Gemini (Direct API)
- 🔗 Get your API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
- 💾 Format: `AIza...`
- 🗝️ Stored in Keychain as `google_api_key`

#### 3. Kimi/Moonshot AI (Chinese AI)
- 🔗 Get your API key from [Kimi Console](https://platform.moonshot.cn/console/api-keys)
- 💾 Format: `sk-...`
- 🗝️ Stored in Keychain as `kimi_api_key`

### Global Shortcuts

- **Default**: `⌥ + Space` (Option + Space)
- **Customize**: Right-click menu bar icon → Settings → Keyboard Shortcuts

## 🚀 Quick Start

1. **Launch Airchat** from Applications
2. **Set up API keys** in Settings (at least one provider)
3. **Use shortcut** `⌥ + Space` to show/hide chat window
4. **Select AI model** from the dropdown in top-right
5. **Start chatting** - type message and press Enter
6. **Add images** using the 📎 button for multi-modal chat

### Usage Tips
- 📝 **Long text**: Paste large text - it will auto-compress
- 🖼️ **Images**: Supports PNG, JPG for vision models
- 🔄 **Switch models**: Click model name in top-right corner
- 🗑️ **Clear chat**: Right-click in chat area
- ⚙️ **Settings**: Right-click menu bar icon

## 🏗️ Architecture

```
┌─────────────────────────┐
│  Status Bar (Menu)      │
│  ⟶ toggleWindow()       │
└──────────┬──────────────┘
           ▼
┌─────────────────────────┐
│  NSPanel + SwiftUI      │
│  • ChatWindow           │
│  • CompressibleInput    │
│  • Glass Effects       │
└──────────┬──────────────┘
           ▼
┌─────── ViewModel ───────┐
│  @Published state       │
│  Multi-API support      │
│  Streaming responses    │
└──────────┬──────────────┘
           ▼
┌───── API Clients ───────┐
│  ArkChatAPI (OpenRouter)│
│  GeminiOfficialAPI      │
│  KimiAPI (Moonshot)     │
└─────────────────────────┘
```

### Key Components

- **AirchatApp.swift**: Main app with status bar integration and window management
- **ChatWindow.swift**: SwiftUI interface with glass morphism and animations
- **ChatVM.swift**: ViewModel managing multi-provider chat state
- **CompressibleInputView.swift**: Smart text compression for long pastes
- **ArkChatAPI.swift**: OpenRouter proxy client with SSE streaming
- **GeminiOfficialAPI.swift**: Direct Google Gemini API with thinking mode
- **KimiAPI.swift**: Moonshot AI client for Chinese market
- **WindowManager.swift**: Global window state management

## 🛠️ Development

### System Requirements
- **macOS**: 14.0+ (Sonoma or later)
- **Xcode**: 16.0+
- **Swift**: 6.0
- **Architecture**: Universal (Apple Silicon + Intel)

### Building from Source

```bash
# Build Release
xcodebuild -project Airchat.xcodeproj -scheme Airchat -configuration Release build

# Run tests  
xcodebuild -project Airchat.xcodeproj -scheme Airchat test

# Clean build
xcodebuild -project Airchat.xcodeproj -scheme Airchat clean

# Create archive (for distribution)
xcodebuild -project Airchat.xcodeproj -scheme Airchat archive -archivePath ./build/Airchat.xcarchive
```

### Swift Package Dependencies

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) `2.3.0+` - Global shortcuts
- [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) `2.4.1` - Message rendering  
- [NetworkImage](https://github.com/gonzalezreal/NetworkImage) `6.0.1` - Image loading

## 🔒 Security & Privacy

- ✅ **App Sandbox** enabled with minimal network-only permissions
- ✅ **API Keys** stored securely in macOS Keychain Services
- ✅ **Hardened Runtime** enabled for notarization and security
- ✅ **No Logging** of sensitive data or conversations
- ✅ **Local Processing** with secure HTTPS API communication only
- ✅ **Code Signed** with Apple Developer certificate

## 📋 Changelog

### v1.0.0 (2025-07-21) 🎉
- ✨ Added Kimi/Moonshot AI support (8K, 32K, 128K context)
- 🎨 Fixed white rough border around floating window  
- 🔧 Removed blue focus border on click
- 📱 Improved API Key settings window layout
- 🚀 Enhanced overall user experience
- 📦 First public DMG release

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. **Fork** the project
2. **Create** your feature branch (`git checkout -b feature/AmazingFeature`)  
3. **Commit** your changes (`git commit -m 'Add some AmazingFeature'`)
4. **Push** to the branch (`git push origin feature/AmazingFeature`)
5. **Open** a Pull Request

### Development Setup
- Ensure Xcode 16.0+ is installed
- Clone the repo and open `Airchat.xcodeproj`
- All dependencies are managed via Swift Package Manager
- Follow existing code style and architecture patterns

## 📞 Support

If you encounter any issues or have questions:

- 🐛 [Report a Bug](https://github.com/youngfly93/Airchat/issues/new?template=bug_report.md)
- 💡 [Request a Feature](https://github.com/youngfly93/Airchat/issues/new?template=feature_request.md)  
- 📖 [View Documentation](https://github.com/youngfly93/Airchat/wiki)
- 💬 [Discussions](https://github.com/youngfly93/Airchat/discussions)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- 🤖 Thanks to OpenRouter, Google, and Moonshot AI for their excellent APIs
- 🎨 Inspired by the need for quick AI access on macOS
- 💻 Built with love using SwiftUI and modern macOS technologies
- 🌟 Special thanks to the open-source Swift community

---

<div align="center">
  
**Made with ❤️ for the macOS community**

[⭐ Star this project](https://github.com/youngfly93/Airchat) • [🐦 Share on Twitter](https://twitter.com/intent/tweet?text=Check%20out%20Airchat%20-%20A%20beautiful%20floating%20AI%20chat%20window%20for%20macOS!%20https://github.com/youngfly93/Airchat)

</div>