# Nova App Lock

A production-ready Android app built with Flutter that provides app locking functionality using overlay windows and usage stats monitoring. The app allows users to lock selected apps with a PIN and optionally use biometrics.

## Features

### Core Features

- **PIN-based Authentication**: Secure 4-digit PIN stored using flutter_secure_storage
- **Biometric Authentication**: Fingerprint/Face unlock support (when enabled)
- **App Locking**: Lock selected apps with overlay lock screen
- **Usage Stats Monitoring**: Detects when locked apps are opened
- **Overlay Lock Screen**: Full-screen overlay that blocks access to locked apps
- **Premium Features**: In-app purchases for unlimited app locking and advanced features

### Premium Features

- **Unlimited App Locking**: Lock unlimited apps (Free version: 3 apps max)
- **Biometric Unlock**: Use fingerprint/face to unlock apps
- **Fake Crash Screen**: Shows fake crash after 3 failed PIN attempts
- **Intruder Selfie**: Takes photo after multiple failed attempts (TODO: Implementation needed)
- **Lock Schedules**: Time-based app locking (TODO: Implementation needed)

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
│   │   ├── screens/        # PIN setup, lock screen, overlay
│   │   └── widgets/        # PIN input widget
│   ├── home/               # Home screen with locked apps list
│   ├── installed_apps/     # Installed apps list with lock toggles
│   ├── settings/           # Settings screen
│   └── splash/             # Splash screen
└── services/               # Core services
    ├── secure_storage_service.dart
    ├── preferences_service.dart
    ├── installed_apps_service.dart
    ├── overlay_service.dart
    ├── usage_stats_service.dart
    ├── purchase_service.dart
    ├── biometric_service.dart
    └── providers.dart
```

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Android Studio / VS Code with Flutter extensions
- Android device or emulator (API 21+)
- Google Play Console account (for in-app purchases)

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

3. **Important**: Fix the `device_apps` package namespace issue:
```bash
# Add namespace to device_apps build.gradle
# Location: ~/.pub-cache/hosted/pub.dev/device_apps-2.2.0/android/build.gradle
# Add: namespace = "fr.g123k.deviceapps" in the android block
```

4. **Implement Platform Channels for Usage Stats**:
   The app uses platform channels to access Android Usage Stats API. You need to implement the native Android code:

   **File**: `android/app/src/main/kotlin/com/example/novaapplock/MainActivity.kt`

   Add the following method channel handler:
   ```kotlin
   import android.app.usage.UsageStatsManager
   import android.content.Context
   import android.content.Intent
   import android.provider.Settings
   import io.flutter.embedding.android.FlutterActivity
   import io.flutter.embedding.engine.FlutterEngine
   import io.flutter.plugin.common.MethodChannel

   class MainActivity: FlutterActivity() {
       private val CHANNEL = "com.example.novaapplock/usage_stats"

       override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
           super.configureFlutterEngine(flutterEngine)
           MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
               when (call.method) {
                   "checkUsageStatsPermission" -> {
                       val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                       val time = System.currentTimeMillis()
                       val stats = usageStatsManager.queryUsageStats(
                           UsageStatsManager.INTERVAL_DAILY,
                           time - 1000 * 60,
                           time
                       )
                       result.success(stats != null)
                   }
                   "requestUsageStatsPermission" -> {
                       startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                       result.success(null)
                   }
                   "getForegroundApp" -> {
                       // Implement foreground app detection
                       // This requires UsageStatsManager and ActivityManager
                       result.success(null) // Return package name
                   }
                   "getAppName" -> {
                       val packageName = call.argument<String>("packageName")
                       val pm = packageManager
                       try {
                           val appInfo = pm.getApplicationInfo(packageName, 0)
                           val appName = pm.getApplicationLabel(appInfo).toString()
                           result.success(appName)
                       } catch (e: Exception) {
                           result.success(packageName)
                       }
                   }
                   else -> result.notImplemented()
               }
           }
       }
   }
   ```

5. **Request Overlay Permission**:
   The app needs to request overlay permission at runtime. Add this to your app initialization:
   ```dart
   import 'package:permission_handler/permission_handler.dart';
   
   // Request overlay permission
   await Permission.systemAlertWindow.request();
   ```

6. Run the app:
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

The app requires the following Android permissions:

### Required Permissions

1. **QUERY_ALL_PACKAGES**: To query installed applications
2. **SYSTEM_ALERT_WINDOW**: To show overlay lock screen (requested at runtime)
3. **PACKAGE_USAGE_STATS**: To detect foreground app (requested at runtime)
4. **USE_BIOMETRIC / USE_FINGERPRINT**: For biometric authentication
5. **CAMERA**: For intruder selfie feature (optional)

### Permission Setup

1. **Overlay Permission**: 
   - The app will prompt users to grant overlay permission
   - Users need to go to Settings > Apps > Special app access > Display over other apps

2. **Usage Stats Permission**:
   - The app will prompt users to grant usage stats permission
   - Users need to go to Settings > Apps > Special app access > Usage access

3. **Biometric Permission**:
   - Automatically requested when enabling biometric authentication

## Usage

1. **First Launch**: The app will prompt you to set up a 4-digit PIN
2. **Enable App Lock**: Toggle the switch on the home screen to enable/disable app locking
3. **Select Apps to Lock**: 
   - Tap "Installed Apps" to browse all installed applications
   - Toggle the switch next to apps you want to lock
   - Free version: Up to 3 apps
   - Premium: Unlimited apps
4. **View Locked Apps**: See all locked apps on the home screen
5. **Unlock Apps**: When a locked app is opened, enter PIN or use biometrics
6. **Settings**: 
   - Change PIN
   - Enable/disable biometric authentication
   - Restore purchases
   - Reset all data

## In-App Purchases Setup

1. **Google Play Console**:
   - Create your app in Google Play Console
   - Set up in-app products:
     - Monthly Premium: `monthly_premium` ($4.99)
     - Yearly Premium: `yearly_premium` ($29.99)

2. **Update Product IDs**:
   - Edit `lib/services/purchase_service.dart`
   - Update `monthlyProductId` and `yearlyProductId` with your actual product IDs

3. **Testing**:
   - Use test accounts in Google Play Console
   - Test purchases in sandbox environment

## Premium Features Implementation Status

- ✅ **Unlimited App Locking**: Implemented
- ✅ **Biometric Unlock**: Implemented
- ✅ **Fake Crash Screen**: Implemented
- ⏳ **Intruder Selfie**: TODO - Needs camera integration
- ⏳ **Lock Schedules**: TODO - Needs time-based locking logic

## Technical Notes

- **Null Safety**: All code is null-safe
- **State Management**: Riverpod for reactive state management
- **Secure Storage**: PIN is stored using Android's encrypted shared preferences
- **Overlay**: Uses `overlay_support` package for displaying lock screen overlay
- **Usage Stats**: Implemented via platform channels (requires native Android code)
- **Error Handling**: Comprehensive error handling for permissions and storage operations

## Play Store Compliance

### Permission Justifications

When submitting to Play Store, provide clear justifications for sensitive permissions:

1. **Usage Access (PACKAGE_USAGE_STATS)**:
   - "This permission is required to detect when locked apps are opened and display the lock screen overlay."

2. **Overlay (SYSTEM_ALERT_WINDOW)**:
   - "This permission is required to display the lock screen overlay when a locked app is detected."

3. **Camera**:
   - "This permission is used for the intruder selfie feature, which takes a photo after multiple failed unlock attempts for security purposes."

### Privacy Policy

Ensure you have a privacy policy that explains:
- How user data is stored (PIN, locked apps list)
- That all data is stored locally on the device
- No data is transmitted to external servers
- Biometric data is handled by the device's secure hardware

## Development

### Adding New Features

When extending the app:

1. **Intruder Selfie**:
   - Implement camera capture in `lock_overlay_screen.dart`
   - Save images to app's private directory
   - Add UI to view captured images

2. **Lock Schedules**:
   - Create schedule service
   - Add schedule management UI
   - Integrate with usage stats monitoring

3. **Usage Stats Platform Channel**:
   - Complete the native Android implementation
   - Test on various Android versions
   - Handle edge cases and permissions

### Code Style

- Follow Flutter/Dart style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep widgets small and reusable

## Troubleshooting

### Build Issues

1. **device_apps namespace error**:
   - Fix: Add namespace to `~/.pub-cache/hosted/pub.dev/device_apps-2.2.0/android/build.gradle`

2. **Overlay not showing**:
   - Check if overlay permission is granted
   - Verify `overlay_support` package is properly initialized

3. **Usage stats not working**:
   - Ensure platform channel is implemented
   - Check if usage stats permission is granted
   - Verify native Android code is correct

### Runtime Issues

1. **Lock screen not appearing**:
   - Check usage stats permission
   - Verify app is in locked apps list
   - Check if overlay permission is granted

2. **Biometric not working**:
   - Ensure device supports biometrics
   - Check if biometric is enabled in settings
   - Verify local_auth package is properly configured

## License

This project is provided as-is for development purposes.

## Support

For issues and questions, please refer to the Flutter documentation and Android developer guides for:
- Platform channels
- Usage Stats API
- Overlay permissions
- In-app purchases
