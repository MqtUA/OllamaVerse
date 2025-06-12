# OllamaVerse

![OllamaVerse Logo](assets/ic_launcher.png)

A cross-platform GUI client for Ollama with advanced features for chat management, context handling, and file processing, built with Flutter.

[![GitHub Repository](https://img.shields.io/badge/GitHub-Repository-blue.svg)](https://github.com/MqtUA/OllamaVerse)

## Features

### Chat Interface
- **Multiple Chat Sessions**: Create and manage multiple chat conversations
- **Model Selection**: Choose from available Ollama models for each chat
- **Automatic Chat Naming**: Chats are automatically named based on their content
- **Manual Chat Renaming**: Easily rename chats for better organization
- **Chat Deletion**: Delete unwanted conversations
- **Selectable Text**: All text (both user and AI responses) is selectable for easy copying
- **Enhanced Chat Bubbles**: Visually distinct chat bubbles with improved styling
- **System Prompt Configuration**: Set custom system prompts for each chat
- **Chat History Persistence**: All conversations are automatically saved and restored
- **Keyboard Shortcuts**: Use Ctrl+Enter to quickly send messages

### Response Generation
- **Live Response Streaming**: See responses as they are generated in real-time
- **Stop Button**: Cancel response generation at any time
- **Enhanced Context Memory**: Maintains comprehensive conversation history for better follow-up understanding
- **Smart Context Handling**: Automatically includes previous messages for short follow-up prompts
- **Configurable Context Length**: Adjust the token context window size (2048-32768)
- **Error Recovery**: Automatic retry mechanism for failed API calls

### File Handling
- **File Attachments**: Attach files to your messages for context
- **PDF Support**: Extract and process text from PDF files
- **Image Support**: Process images as part of your prompts
- **Multiple File Types**: Support for various text and document formats
- **File Size Limits**: Automatic handling of large files with 10MB limit
- **Smart File Cleanup**: Advanced automatic cleanup system with intelligent monitoring
- **Storage Management**: Real-time file size monitoring with configurable thresholds
- **Background Cleanup**: Isolate-based cleanup operations for better performance

### Storage & Security
- **Secure Authentication Storage**: Bearer auth tokens stored using encrypted secure storage
- **Dual Storage System**: Sensitive data in secure storage, regular settings in standard storage
- **Storage Statistics**: Monitor cache, logs, and attachment storage usage
- **Manual Cleanup Control**: Force cleanup of temporary files through settings
- **Cache Management**: Intelligent caching system for frequently accessed data

### Code Display
- **Copy Code Button**: Easily copy code snippets
- **Language Labels**: Code blocks show the programming language
- **LaTeX Support**: Render mathematical formulas and equations

### Appearance & Themes
- **Dark Mode**: Toggle between light and dark themes with instant switching
- **System Theme Sync**: Automatic theme detection on Windows (follows system preferences)
- **Font Size Control**: Adjust text size for better readability (12-24px range)
- **Responsive Design**: Fully responsive layout optimized for mobile, tablet, and desktop
- **Adaptive UI**: Different layouts for small screens (≤600px) and large screens
- **Custom Themes**: Support for Dracula dark theme and Material light theme
- **Performance-Optimized Animations**: Smooth transitions with minimal frame drops

### Performance Monitoring
- **Real-Time Performance Tracking**: Monitor frame rates, theme switching speed, and UI responsiveness
- **Performance Dashboard**: View detailed metrics in settings with recommendations
- **Frame Drop Detection**: Automatic detection and logging of performance issues
- **Theme Switch Optimization**: Ultra-fast theme switching (<50ms target)
- **Performance Logging**: Console output with detailed performance summaries
- **Metrics Reset**: Reset performance counters and export performance data

### Settings
- **Server Configuration**: Configure Ollama server host and port
- **Authentication**: Support for Bearer Auth Token when connecting to secured Ollama servers
- **Connection Testing**: Test and verify connection to the Ollama server
- **Font Size**: Adjust the font size for better readability
- **Dark Mode**: Toggle between light and dark themes
- **Live Response**: Toggle real-time response streaming
- **System Prompt**: Configure default system prompt for new chats
- **Performance Settings**: Monitor and configure app performance
- **Storage Settings**: Manage file cleanup and storage usage

### Accessibility & Navigation
- **Keyboard Shortcuts**: Ctrl+Enter to send messages, system menu shortcuts
- **Responsive Navigation**: Adaptive drawer/menu system based on screen size
- **Touch-Friendly**: Optimized touch targets for mobile devices
- **High Contrast Support**: Enhanced contrast modes for better visibility

### Server Configuration
- **Custom Host/Port**: Connect to any Ollama server
- **Model Refresh**: Update the available model list
- **Connection Status**: Real-time server connection status
- **Error Handling**: Detailed error messages for connection issues
- **Network Security**: Configured for both HTTP and HTTPS connections
- **Timeout Handling**: Robust connection timeout management

### Cross-Platform Features
- **Windows Integration**: Native window decorations with theme sync
- **Android Optimization**: Network security configuration for local connections
- **macOS Support**: Native menu integration and system preferences
- **Adaptive Icons**: Platform-specific app icons and launch screens

## Getting Started

### Prerequisites
- [Ollama](https://ollama.ai/) installed and running on your local machine or a remote server
- At least one model pulled in Ollama (e.g., `ollama pull llama3`)
- Flutter SDK (for development)

### Installation
1. Download the latest release for your platform
2. Launch the application
3. Configure the Ollama server address in Settings (default: 127.0.0.1:11434)

### Usage
1. Click "New Chat" to start a conversation
2. Select a model from the available models list
3. Type your message and press Enter or click Send
4. Attach files using the attachment button if needed
5. Use the stop button to cancel response generation
6. Adjust settings as needed through the Settings screen
7. Use Ctrl+Enter to quickly send messages

### Storage Locations

#### Windows
On Windows, the chat history is stored in the application documents directory at:
```
C:\Users\<Username>\AppData\Roaming\com.ollama.verse\chats\
```

#### Android
On Android, the chat history is stored in the application's private documents directory at:
```
/data/data/com.ollama.verse/app_flutter/chats/
```

Or on newer Android versions with scoped storage:
```
/storage/emulated/0/Android/data/com.ollama.verse/files/chats/
```

## Development

### Environment Setup
1. Install Flutter SDK
2. Clone the repository
3. Install dependencies
4. Configure your IDE

### Building from Source
```bash
# Clone the repository
git clone https://github.com/MqtUA/OllamaVerse.git

# Navigate to the project directory
cd OllamaVerse

# Install dependencies
flutter pub get

# Run the app
flutter run
```

### Testing
```bash
# Run unit tests
flutter test

# Run integration tests
flutter test integration_test
```

### Code Style
- Follow the official Dart style guide
- Use meaningful variable and function names
- Add comments for complex logic
- Write unit tests for new features

### Contributing
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Write tests for new features
5. Submit a pull request

## Packages Used

### Core Functionality
- **http**: Network requests to the Ollama API
- **provider**: State management throughout the application
- **shared_preferences**: Storing user settings and preferences
- **path_provider**: Accessing system directories for file storage
- **path**: File path manipulation and management

### Security & Storage
- **flutter_secure_storage**: Encrypted storage for sensitive data like auth tokens
- **package_info_plus**: App version and metadata information

### UI and Rendering
- **gpt_markdown**: Rendering markdown content with LaTeX support
- **flutter_highlighter**: Code syntax highlighting for various programming languages
- **highlight**: Core syntax highlighting engine
- **flutter_syntax_view**: Additional code display capabilities

### File Handling
- **file_picker**: Selecting files from the device
- **flutter_file_dialog**: Native file dialogs for saving files
- **syncfusion_flutter_pdf**: PDF processing and text extraction
- **uuid**: Generating unique identifiers for chats and messages

### Utilities
- **logging**: Application logging and debugging
- **logger**: Enhanced logging capabilities
- **flutter_launcher_icons**: App icon generation

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Ollama](https://ollama.ai/) for the amazing local LLM runtime
- [Flutter](https://flutter.dev/) for the cross-platform framework

## Troubleshooting

### Android Connection Issues

If you're experiencing connection issues on Android when trying to connect to a remote Ollama instance:

#### Common Issues and Solutions

1. **"Connection Failed" or "Connection timed out" errors:**
   - **Check Network Connectivity**: Ensure your Android device is connected to the same network as your Ollama server
   - **Verify Server Address**: Make sure you're using the correct IP address and port (not `localhost` or `127.0.0.1` when connecting remotely)
   - **Test Server Accessibility**: Try accessing `http://YOUR_SERVER_IP:11434/api/tags` in a web browser on your Android device

2. **Firewall and Network Configuration:**
   - **Server Firewall**: Ensure your Ollama server's firewall allows connections on port 11434
   - **Router/Network Firewall**: Check if your router or network firewall is blocking the connection
   - **Ollama Binding**: Make sure Ollama is bound to `0.0.0.0:11434` (not just `127.0.0.1:11434`)

3. **Android-Specific Network Issues:**
   - **Clear DNS Cache**: Go to Android Settings > Apps > OllamaVerse > Storage > Clear Cache
   - **Network Security**: The app is configured to allow HTTP connections for development
   - **Mobile Data vs WiFi**: Try switching between mobile data and WiFi to isolate network issues

#### Configuring Ollama for Remote Access

To allow remote connections to your Ollama server:

1. **Set Environment Variable** (recommended):
   ```bash
   export OLLAMA_HOST=0.0.0.0:11434
   ollama serve
   ```

2. **Or start with host binding**:
   ```bash
   ollama serve --host 0.0.0.0:11434
   ```

3. **For systemd services**, edit the service file:
   ```bash
   sudo systemctl edit ollama
   ```
   Add:
   ```ini
   [Service]
   Environment="OLLAMA_HOST=0.0.0.0:11434"
   ```

#### Testing Connection

1. **From your computer**: `curl http://YOUR_SERVER_IP:11434/api/tags`
2. **From Android browser**: Navigate to `http://YOUR_SERVER_IP:11434/api/tags`
3. **In the app**: Go to Settings and use "Test Connection"

#### Network Configuration Examples

- **Local network**: `192.168.1.100:11434`
- **Docker**: Ensure port mapping `-p 11434:11434`
- **Cloud server**: Use public IP and ensure security groups/firewall rules allow port 11434

If issues persist, check the app logs in Settings > About for detailed error messages.
