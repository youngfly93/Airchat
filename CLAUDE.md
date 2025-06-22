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
- **ArkChatAPI.swift**: API client implementing streaming responses via Server-Sent Events (note: filename reflects legacy ARK API, but now uses Gemini)
- **KeychainHelper.swift**: Generic keychain wrapper for secure API key storage
- **VisualEffectView.swift**: NSViewRepresentable wrapper for macOS visual effects
- **Item.swift**: Contains ChatMessage model (note: filename is misleading)
- **WindowManager.swift**: Singleton manager for controlling window visibility and state
- **KeyboardShortcuts.swift**: Global keyboard shortcuts configuration using KeyboardShortcuts library

### Key Architectural Patterns
- Status bar application (no dock icon) using NSStatusBar
- Floating NSPanel with custom window masking for rounded corners
- Observable ViewModel pattern with @Published properties
- AsyncThrowingStream for streaming API responses
- Secure credential storage using Keychain Services
- Global keyboard shortcuts using KeyboardShortcuts library (default: ⌥ + Space)
- Singleton WindowManager pattern for window state control

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

### Gemini API Configuration
- **Endpoint**: https://openrouter.ai/api/v1/chat/completions
- **Model**: google/gemini-2.5-pro
- **Authentication**: Bearer token stored in Keychain
- **Response Format**: Server-Sent Events (SSE) for streaming via OpenRouter

### API Response Handling
- Uses URLSession with streaming support
- Parses SSE format with "data:" prefixed lines
- Handles partial JSON chunks and token accumulation
- Implements proper error handling for network failures

## Window Management

The floating window implementation uses several advanced techniques:
- NSPanel with `.floating` level for always-on-top behavior
- Custom window mask creation for rounded corners
- Automatic positioning below status bar item
- Smooth animations between collapsed (60x60) and expanded (360x520) states
- Glass morphism effects using NSVisualEffectView

## State Management

The app uses a centralized ChatVM for state:
- `messages`: Array of ChatMessage objects
- `currentInput`: User's input text
- `isLoading`: Loading state during API calls
- `isCollapsed`: Window collapse state
- Methods for sending messages, clearing chat, and toggling window state

## Security Considerations

- API keys are stored in Keychain (service: "com.afei.airchat", account: "ark_api_key")
- App Sandbox enabled with network client capability only
- Hardened Runtime enabled for notarization
- Note: Remove hardcoded fallback API key in KeychainHelper.swift before production (currently contains OpenRouter key for Gemini access)

## Testing

The project uses Swift Testing framework (Xcode 16+):
- Test files exist but need implementation
- Run tests with: `⌘U` in Xcode or command line build

## Common Development Tasks

### Adding New Features
1. UI changes go in ChatWindow.swift
2. State/logic changes go in ChatVM.swift
3. API modifications go in ArkChatAPI.swift

### Debugging Streaming Responses
- Check console output for SSE parsing
- Verify API key is correctly stored/retrieved
- Monitor network traffic in Xcode's Network instrument

### Window Positioning Issues
- Window position is calculated in AirchatApp.swift
- Adjust `windowOrigin` calculation if needed
- Consider multiple display scenarios

## Global Keyboard Shortcuts

The app implements global keyboard shortcuts using the KeyboardShortcuts library:

### Dependencies
- **KeyboardShortcuts**: External Swift Package from sindresorhus/KeyboardShortcuts
- **Repository**: https://github.com/sindresorhus/KeyboardShortcuts
- **Version**: 2.3.0+

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