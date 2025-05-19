# OllamaVerse

![OllamaVerse Logo](assets/ic_launcher.png)

A cross-platform GUI client for Ollama with advanced features for chat management, context handling, and file processing, built with Flutter.

## Features

### Chat Interface
- **Multiple Chat Sessions**: Create and manage multiple chat conversations
- **Model Selection**: Choose from available Ollama models for each chat
- **Automatic Chat Naming**: Chats are automatically named based on their content
- **Manual Chat Renaming**: Easily rename chats for better organization
- **Chat Deletion**: Delete unwanted conversations
- **Selectable Text**: All text (both user and AI responses) is selectable for easy copying
- **Enhanced Chat Bubbles**: Visually distinct chat bubbles with improved styling

### Response Generation
- **Live Response Streaming**: See responses as they are generated in real-time
- **Stop Button**: Cancel response generation at any time
- **Enhanced Context Memory**: Maintains comprehensive conversation history for better follow-up understanding
- **Smart Context Handling**: Automatically includes previous messages for short follow-up prompts
- **Configurable Context Length**: Adjust the token context window size (2048-32768)

### File Handling
- **File Attachments**: Attach files to your messages for context
- **PDF Support**: Extract and process text from PDF files
- **Image Support**: Process images as part of your prompts
- **Multiple File Types**: Support for various text and document formats

### Code Display
- **Syntax Highlighting**: Proper formatting for code blocks with language-specific coloring
- **Dark Mode Support**: Code blocks display correctly in both light and dark themes
- **Copy Button**: Easily copy code snippets
- **Language Labels**: Code blocks show the programming language
- **LaTeX Support**: Render mathematical formulas and equations

### Appearance
- **Dark Mode**: Toggle between light and dark themes
- **Font Size Control**: Adjust text size for better readability
- **Responsive Design**: Works on different screen sizes

### Settings
- **Server Configuration**: Configure Ollama server host and port
- **Authentication**: Support for Bearer Auth Token when connecting to secured Ollama servers
- **Connection Testing**: Test and verify connection to the Ollama server
- **Font Size**: Adjust the font size for better readability
- **Dark Mode**: Toggle between light and dark themes
- **Live Response**: Toggle real-time response streaming

### Server Configuration
- **Custom Host/Port**: Connect to any Ollama server
- **Model Refresh**: Update the available model list

## Getting Started

### Prerequisites
- [Ollama](https://ollama.ai/) installed and running on your local machine or a remote server
- At least one model pulled in Ollama (e.g., `ollama pull llama3`)

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

This project is built with Flutter and can be run on Windows and Android platforms.

```bash
# Clone the repository
git clone https://github.com/yourusername/ollamaverse.git

# Navigate to the project directory
cd ollamaverse

# Install dependencies
flutter pub get

# Run the app
flutter run
```

## Packages Used

OllamaVerse leverages several Flutter packages to provide its functionality:

### Core Functionality
- **http**: Network requests to the Ollama API
- **provider**: State management throughout the application
- **shared_preferences**: Storing user settings and preferences
- **path_provider**: Accessing system directories for file storage
- **path**: File path manipulation and management

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
- **flutter_launcher_icons**: App icon generation

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgments

- [Ollama](https://ollama.ai/) for the amazing local LLM runtime
- [Flutter](https://flutter.dev/) for the cross-platform framework
