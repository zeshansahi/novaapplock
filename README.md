# Nova App Lock

A production-ready MVP Android app built with Flutter that provides app locking functionality. This MVP includes the complete UI and local logic, ready to be extended with actual app-locking via Accessibility API in future versions.

## Features

### MVP Features

- **Splash Screen**: Checks if PIN exists and navigates accordingly
- **PIN Setup**: Create and confirm a 4-digit PIN, stored securely
- **Lock Screen**: Protects the app itself with PIN authentication
- **Home Screen**: Toggle app lock, view installed apps
- **Installed Apps List**: Browse all installed apps with search functionality
- **Settings**: Change PIN, reset all data

### Architecture

- **Clean Architecture**: Features-based structure with services and storage layers
- **State Management**: Riverpod for reactive state management
- **Local Storage**: 
  - `shared_preferences` for app settings
  - `flutter_secure_storage` for PIN storage
- **Installed Apps**: `device_apps` package for reading installed applications

## Project Structure

```
lib/
├── core/
│   ├── constants/          # App constants and routes
│   ├── theme/              # App theme configuration
│   └── utils/              # Utility classes
├── features/
│   ├── auth_pin/           # PIN setup and lock screens
│   │   ├── providers/      # Riverpod providers
│   │   ├── screens/        # PIN setup and lock screens
│   │   └── widgets/        # PIN input widget
│   ├── home/               # Home screen
│   ├── installed_apps/     # Installed apps list
│   │   ├── providers/      # Apps list providers
│   │   ├── screens/        # Apps list screen
│   │   └── widgets/        # App details bottom sheet
│   ├── settings/           # Settings screen
│   └── splash/              # Splash screen
└── services/               # Core services
    ├── secure_storage_service.dart
    ├── preferences_service.dart
    ├── installed_apps_service.dart
    └── providers.dart
```

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator (API 21+)

### Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd novaapplock
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:
```bash
flutter run
```

### Building for Android

To build an APK:
```bash
flutter build apk
```

To build an App Bundle:
```bash
flutter build appbundle
```

## Permissions

The app requires the following Android permissions (already configured in `AndroidManifest.xml`):

- `QUERY_ALL_PACKAGES`: Required to query installed applications

## Usage

1. **First Launch**: The app will prompt you to set up a 4-digit PIN
2. **Enable App Lock**: Toggle the switch on the home screen to enable/disable app locking
3. **View Installed Apps**: Tap "Installed Apps" to browse all installed applications
4. **Change PIN**: Go to Settings to change your PIN (requires old PIN)
5. **Reset Data**: Use Settings to reset all app data

## Future Enhancements

The following features are marked with TODO comments in the codebase for future implementation:

- **Real App Locking**: Integration with Android Accessibility API or Device Admin API
- **Biometric Authentication**: Fingerprint/Face unlock support
- **App-Specific Locking**: Lock individual apps (currently UI-only)
- **Lock Patterns**: Support for pattern-based authentication
- **Time-Based Locking**: Schedule automatic locking

## Technical Notes

- **Null Safety**: All code is null-safe
- **Error Handling**: Comprehensive error handling for permissions and storage operations
- **State Management**: Riverpod providers for reactive state management
- **Secure Storage**: PIN is stored using Android's encrypted shared preferences

## Development

### Adding New Features

When extending the app with real app-locking functionality:

1. Look for `// TODO: Integrate real app lock engine here` comments
2. Implement the Accessibility Service or Device Admin functionality
3. Update the lock providers to integrate with the new service
4. Test thoroughly on physical devices

### Code Style

- Follow Flutter/Dart style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep widgets small and reusable

## License

This project is provided as-is for MVP purposes.
