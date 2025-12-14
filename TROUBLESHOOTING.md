# Troubleshooting Guide - App Lock Not Working

## Issue: Locked apps are not being protected

If you've set up app lock for an app but it's not being protected when opened, follow these steps:

## Step 1: Verify Permissions

1. **Overlay Permission**:
   - Go to Settings > Apps > Special app access > Display over other apps
   - Find "Nova App Lock" and ensure it's enabled

2. **Usage Stats Permission**:
   - Go to Settings > Apps > Special app access > Usage access
   - Find "Nova App Lock" and ensure it's enabled

## Step 2: Check Debug Info

The home screen now includes a debug widget that shows:
- Current foreground app
- List of locked apps
- Locked apps count

Use the "Check Foreground App" button to verify the app detection is working.

## Step 3: Verify Monitoring is Running

1. Enable App Lock toggle on home screen
2. Check the console/logcat for these messages:
   - "Initializing usage stats monitoring"
   - "Usage stats permission granted: true"
   - "Starting usage stats monitoring"
   - "UsageStats monitoring started"
   - "Foreground app changed to: [package name]"
   - "Is [package] locked? true"
   - "Locked app detected: [package]"
   - "Showing overlay for locked app: [package]"

## Step 4: Check Logs

Run the app with:
```bash
flutter run
```

Then check the console output. You should see:
- Monitoring status messages
- Foreground app changes
- Lock detection messages

## Common Issues

### Issue 1: Monitoring Not Starting
**Symptoms**: No log messages about monitoring
**Solution**: 
- Ensure usage stats permission is granted
- Restart the app after granting permission
- Check that app lock toggle is enabled

### Issue 2: App Detection Not Working
**Symptoms**: Foreground app always shows "Unknown"
**Solution**:
- Verify usage stats permission is granted
- Check native Android code in MainActivity.kt
- Ensure the platform channel is properly set up

### Issue 3: Overlay Not Showing
**Symptoms**: Locked app detected but no overlay appears
**Solution**:
- Verify overlay permission is granted
- Check if native overlay service is working
- The native overlay should show a simple lock screen
- If native overlay fails, it falls back to Flutter overlay (only works in our app)

## Testing Steps

1. **Enable App Lock**:
   - Open the app
   - Toggle "App Lock" to ON
   - Grant all permissions when prompted

2. **Add App to Lock List**:
   - Tap "Installed Apps"
   - Find an app you want to lock
   - Toggle the switch to lock it

3. **Test Locking**:
   - Press home button (go to home screen)
   - Open the locked app
   - The overlay should appear immediately

4. **Check Debug Info**:
   - Return to Nova App Lock app
   - Check the debug widget on home screen
   - Verify the locked app is in the list
   - Use "Check Foreground App" to test detection

## Native Overlay Implementation

The app now uses a native Android service (`OverlayService.kt`) to show system overlays. This service:
- Creates a system overlay window using WindowManager
- Shows a simple lock screen over locked apps
- Requires SYSTEM_ALERT_WINDOW permission

**Note**: The native overlay currently shows a simple unlock button. The full PIN input will be implemented in the Flutter overlay which appears when our app is in foreground.

## Limitations

1. **Background Overlay**: The Flutter overlay (overlay_support) only works when our app is in the foreground. For true system-wide overlays, we use the native Android service.

2. **Monitoring Frequency**: The app checks for foreground app changes every 500ms. There may be a slight delay before the overlay appears.

3. **Battery Optimization**: Some devices may kill background monitoring. Ensure the app is excluded from battery optimization.

## Next Steps for Full Implementation

To make the overlay work perfectly:

1. **Implement Full PIN in Native Overlay**: 
   - Add PIN input to OverlayService.kt
   - Communicate with Flutter to verify PIN

2. **Use Foreground Service**:
   - Convert OverlayService to a foreground service
   - This ensures it keeps running in background

3. **Add Accessibility Service** (Alternative):
   - More reliable for detecting app launches
   - Better for Play Store compliance
   - Requires user to enable in accessibility settings

## Debug Commands

Check if monitoring is active:
```bash
adb logcat | grep -i "UsageStats\|Overlay\|Locked app"
```

Check permissions:
```bash
adb shell dumpsys package com.example.novaapplock | grep -A 5 "granted=true"
```

## Still Not Working?

1. Check the debug widget on home screen
2. Review console logs for error messages
3. Verify all permissions are granted
4. Try restarting the device
5. Reinstall the app and grant permissions again

