# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a fully implemented macOS floating chat window application built with SwiftUI. The app lives in the menu bar and provides a beautiful floating chat interface for interacting with AI via the Gemini API (google/gemini-2.5-pro) through OpenRouter.

## Architecture

The application follows a SwiftUI + MVVM architecture:

### Core Components
- **AirchatApp.swift**: Main app entry point with NSApplicationDelegateAdaptor, manages status bar item and floating NSPanel window, includes global keyboard shortcuts support
- **ChatWindow.swift**: SwiftUI chat interface with collapsible/expandable states, glass morphism design
- **ChatVM.swift**: ViewModel managing chat state, message history, and API interactions
- **ArkChatAPI.swift**: Legacy API client for OpenRouter/Gemini integration via Server-Sent Events
- **GeminiOfficialAPI.swift**: Direct Google Gemini API client with thinking mode support
- **KeychainHelper.swift**: Generic keychain wrapper for secure API key storage (both OpenRouter and Google API keys)
- **VisualEffectView.swift**: NSViewRepresentable wrapper for macOS visual effects
- **Item.swift**: Contains ChatMessage model and related data structures
- **WindowManager.swift**: Singleton manager for controlling window visibility and state
- **KeyboardShortcuts.swift**: Global keyboard shortcuts configuration using KeyboardShortcuts library
- **ModelConfig.swift**: Configuration for AI model selection and settings
- **WebSearchService.swift**: Service for handling web search functionality
- **ThinkingProcessView.swift**: UI component for displaying AI thinking processes
- **CollapsibleThinkingView.swift**: Collapsible view for thinking content
- **PasteHandler.swift**: Clipboard and paste functionality handlers
- **ImagePickerView.swift**: Image selection and attachment interface

### Key Architectural Patterns
- Status bar application (no dock icon) using NSStatusBar
- Floating NSPanel with custom window masking for rounded corners
- Observable ViewModel pattern with @Published properties
- AsyncThrowingStream for streaming API responses
- Secure credential storage using Keychain Services
- Global keyboard shortcuts using KeyboardShortcuts library (default: ⌥ + Space)
- Singleton WindowManager pattern for window state control
- Dual API support: OpenRouter proxy and direct Google Gemini API
- Advanced animation system with performance monitoring
- Collapsible input interface (480x64) and expanded chat view (360x520)
- Multi-modal content support (text and images)
- Web search integration for enhanced AI responses
- Thinking mode visualization for AI reasoning processes

## Development Commands

### Build and Run
```bash
# Open project in Xcode
open Airchat.xcodeproj

# Build from command line
xcodebuild -project Airchat.xcodeproj -scheme Airchat build

# Run tests
xcodebuild -project Airchat.xcodeproj -scheme Airchat test

# Clean build
xcodebuild -project Airchat.xcodeproj -scheme Airchat clean
```

### Running the App
- Build and run in Xcode (⌘R)
- App appears in menu bar (top right)
- Click menu bar icon to show/hide chat window
- Use global keyboard shortcut ⌥ + Space to toggle window from anywhere
- Customize keyboard shortcut in Settings (menu bar → right-click → Settings...)

## API Integration Details

### Dual API Support
The app supports two API configurations:

#### OpenRouter (Legacy via ArkChatAPI)
- **Endpoint**: https://openrouter.ai/api/v1/chat/completions
- **Models**: google/gemini-2.5-pro, claude-3.5-sonnet, gpt-4o, o4-mini-high, llama-3.3-70b
- **Authentication**: Bearer token stored in Keychain (key: "ark_api_key")
- **Response Format**: Server-Sent Events (SSE) for streaming

#### Google Gemini Direct API (via GeminiOfficialAPI)
- **Endpoint**: https://generativelanguage.googleapis.com/v1beta/models
- **Models**: gemini-2.5-pro, gemini-2.0-flash-thinking-exp, minimax-01
- **Authentication**: Google API key stored in Keychain (key: "google_api_key")
- **Features**: Thinking mode, multi-modal support, advanced reasoning

### Available Models (ModelConfig.swift)
- Google Gemini 2.5 Pro (both proxy and direct)
- Google Gemini 2.0 Flash Thinking
- MiniMax M1
- Claude 3.5 Sonnet
- OpenAI O4 Mini High
- GPT-4o
- Llama 3.3 70B Versatile

### API Response Handling
- Uses URLSession with streaming support
- Parses SSE format with "data:" prefixed lines
- Handles partial JSON chunks and token accumulation
- Supports thinking mode content extraction
- Implements proper error handling for network failures
- Multi-modal content support for text and images

## Window Management

The floating window implementation uses several advanced techniques:
- NSPanel with `.floating` level for always-on-top behavior
- Custom window mask creation for rounded corners
- Automatic positioning below status bar item
- Smooth animations between collapsed (480x64) and expanded (360x520) states
- Performance-optimized animation system with 60fps Timer-based updates
- Easing functions for natural motion (easeInOutCubic)
- Animation performance monitoring and frame rate tracking
- Glass morphism effects using NSVisualEffectView

## State Management

The app uses a centralized ChatVM for state:
- `messages`: Array of ChatMessage objects
- `composing`: User's input text
- `selectedImages`: Array of attached images
- `isLoading`: Loading state during API calls
- `showModelSelection`: Model picker visibility
- `isWebSearchEnabled`: Web search toggle state
- `shouldScrollToBottom`: Scroll management for streaming content
- Methods for sending messages, clearing chat, image handling, and API switching
- Dual scroll mechanism for streaming vs. normal content
- Typewriter effect system for gradual text display

## Security Considerations

- API keys are stored in Keychain (service: "com.afei.airchat")
  - OpenRouter key: account "ark_api_key"
  - Google API key: account "google_api_key"
- App Sandbox enabled with network client capability only
- Hardened Runtime enabled for notarization
- Secure image handling with base64 encoding for API transmission
- No sensitive data logged or exposed in error messages

## Testing

The project uses Swift Testing framework (Xcode 16+):
- Test files exist but need implementation
- Run tests with: `⌘U` in Xcode or command line build

## Project Requirements

- **Platform**: macOS 14.0+
- **Xcode**: 16.0+
- **Swift**: 6.0
- **Architecture**: Universal (arm64 + x86_64)

## Common Development Tasks

### Adding New Features
1. UI changes go in ChatWindow.swift (main interface) or create new view components
2. State/logic changes go in ChatVM.swift
3. OpenRouter API modifications go in ArkChatAPI.swift
4. Google API modifications go in GeminiOfficialAPI.swift
5. Model configuration changes go in ModelConfig.swift
6. Animation improvements go in AppDelegate (animation system)
7. New thinking/reasoning UI in ThinkingProcessView.swift

### Debugging Streaming Responses
- Check console output for SSE parsing
- Verify API keys are correctly stored/retrieved from Keychain
- Monitor network traffic in Xcode's Network instrument
- Use AnimationPerformanceMonitor for performance debugging
- Check thinking mode parsing for Gemini API responses
- Debug image base64 encoding for multi-modal requests

### Window Positioning Issues
- Window position is calculated in AirchatApp.swift
- Adjust `windowOrigin` calculation if needed
- Consider multiple display scenarios

## Global Keyboard Shortcuts

The app implements global keyboard shortcuts using the KeyboardShortcuts library:

### Swift Package Dependencies
- **KeyboardShortcuts**: Global keyboard shortcuts management
  - Repository: https://github.com/sindresorhus/KeyboardShortcuts
  - Version: 2.3.0+
- **MarkdownUI**: Markdown rendering for chat messages
  - Repository: https://github.com/gonzalezreal/swift-markdown-ui
  - Version: 2.4.1
  - Used for formatting AI responses with rich text
- **NetworkImage**: Image loading and caching
  - Repository: https://github.com/gonzalezreal/NetworkImage
  - Version: 6.0.1
- **swift-cmark**: CommonMark parser (dependency)
  - Version: 0.6.0

### Implementation Details
- **Default Shortcut**: ⌥ + Space (Option + Space)
- **Shortcut Definition**: Defined in KeyboardShortcuts.swift using KeyboardShortcuts.Name extension
- **Registration**: Global shortcut callback registered in AirchatApp.init()
- **Window Control**: WindowManager.shared.toggleWindow() handles show/hide logic
- **Settings UI**: Settings scene provides KeyboardShortcuts.Recorder for user customization
- **Persistence**: Shortcuts automatically saved to UserDefaults by KeyboardShortcuts library

### Usage
- Press ⌥ + Space anywhere in macOS to toggle chat window
- Access Settings via menu bar right-click → Settings... to customize
- Shortcuts work globally even when app is in background

### Troubleshooting
- Ensure KeyboardShortcuts package is added to project dependencies
- Check that showPanel() method in AppDelegate is public (not private)
- Verify WindowManager.shared.appDelegate reference is set in applicationDidFinishLaunching