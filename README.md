# SayIt (TapReply)

TapReply is an invisible, frictionless AI communication assistant. Most people struggle to find the right words, overthink their replies, or waste time switching between chat apps and AI tools. TapReply solves this by living exactly where the user needs it—as a non-intrusive floating bubble on top of their screen. It reads the room, understands the conversation, and provides the perfect reply in seconds, without the user ever leaving their current app.

## Product Vision

*   **Invisible until needed:** Rests quietly on the edge of the screen as a bubble.
*   **Context Awareness:** Automatically reads and understands the visible conversation on the screen.
*   **Multi-Modal Input:** Accepts context via automatic screen reading, manual typing, or voice dictation.
*   **Tone Adaptation:** Adjusts the personality of the response to fit the situation (Professional, Friendly, Crush, Normal).
*   **Seamless Injection:** Automatically pastes the generated response directly into the user's active chat box, ready to send.

## The User Flow

1.  **The Idle State:** The user is scrolling through a chat app. A small, semi-transparent bubble rests quietly on the edge of the screen.
2.  **The Trigger:** The user taps the bubble. It expands into a clean dashboard panel and automatically scans the background chat.
3.  **Tone Selection:** The user selects a mood (Professional, Friendly, Crush, Normal).
4.  **AI Generation:** The app generates 2-3 distinct, ready-to-send reply options based on context and tone.
5.  **The "Magic Send":** The user taps "Insert" next to their favorite reply. The dashboard collapses, and the text is magically typed into the chat box, ready to send.

## Technical Architecture

This application is built using Flutter for the UI and state management, heavily integrating with Native Android services for deep OS-level functionality.

### Core Technologies
*   **Flutter:** Cross-platform UI, animations, state management.
*   **Android System Alert Window:** For the floating bubble overlay (`SYSTEM_ALERT_WINDOW` permission).
*   **Android Accessibility Service:** To read screen text (`AccessibilityNodeInfo`) and inject text into active text fields (`ACTION_SET_TEXT`).
*   **Platform Channels:** To communicate between the Flutter UI and the native Android Kotlin services.
*   **Foreground Service:** To ensure the bubble remains active in the background.

## Getting Started

1.  Clone the repository.
2.  Copy `.env.example` to `.env` (or create a `.env` file) and add your AI API keys.
3.  Run `flutter pub get`.
4.  Build and run on an Android device (Emulators may have limited Accessibility Service capabilities).

*Note: You must manually grant "Display Over Other Apps" and "Accessibility" permissions in your Android settings for the app to function correctly.*
