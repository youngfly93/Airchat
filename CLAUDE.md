# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a macOS floating window AI chat application built with SwiftUI and SwiftData. The app is designed to be a menu bar application that provides a floating chat interface for interacting with AI via the ARK API.

## Architecture

The application follows a typical SwiftUI + SwiftData architecture:
- **AirchatApp.swift**: Main app entry point with SwiftData model container setup
- **ContentView.swift**: Default template view (to be replaced with chat interface)
- **Item.swift**: SwiftData model (template - will be replaced with ChatMessage model)

The intended architecture (based on guide.md) includes:
- Status bar menu application (no dock icon)
- Floating NSPanel chat window
- SwiftUI-based chat interface with message bubbles
- ARK API integration for AI chat
- Observable ViewModel pattern for state management

## Development Commands

### Build and Run
```bash
# Open project in Xcode
open Airchat.xcodeproj

# Build from command line
xcodebuild -project Airchat.xcodeproj -scheme Airchat build

# Run tests
xcodebuild -project Airchat.xcodeproj -scheme Airchat test
```

### Testing
- Unit tests: `AirchatTests/AirchatTests.swift`
- UI tests: `AirchatUITests/AirchatUITests.swift` and `AirchatUITestsLaunchTests.swift`

## Key Configuration

- **Target**: macOS 14.0+
- **Language**: Swift 5.0
- **Framework**: SwiftUI + SwiftData
- **Development Team**: 5SAM7RT8QQ
- **Bundle ID**: afei.Airchat
- **Capabilities**: App Sandbox enabled, Hardened Runtime

## API Integration

The project is designed to integrate with ARK API:
- **Endpoint**: https://ark.cn-beijing.volces.com/api/v3/chat/completions
- **Model**: deepseek-v3-250324
- **Authentication**: Bearer token (should be stored in Keychain)
- **Features**: Streaming response support via Server-Sent Events

## Implementation Notes

When implementing the chat functionality:
- Replace the default SwiftData Item model with ChatMessage
- Implement NSStatusBar integration for menu bar presence
- Use NSPanel with floating level for the chat window
- Implement streaming chat responses with AsyncStream
- Store API keys securely in Keychain (never hardcode)
- Follow the architectural pattern outlined in guide.md

## Security Considerations

- API keys must be stored in Keychain, not hardcoded
- App Sandbox should only enable network client capabilities
- Use proper code signing for distribution