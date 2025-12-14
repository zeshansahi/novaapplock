# Debugging App Lock - Step by Step Guide

## Quick Checklist

1. ✅ **Permissions Granted?**
   - Overlay: Settings > Apps > Special access > Display over other apps > Nova App Lock = ON
   - Usage Stats: Settings > Apps > Special access > Usage access > Nova App Lock = ON

2. ✅ **App Lock Enabled?**
   - Home screen > Toggle "App Lock" to ON

3. ✅ **App Added to Lock List?**
   - Tap "Installed Apps" > Find app > Toggle switch to ON
   - Check home screen "Locked Apps" section shows the app

4. ✅ **Monitoring Started?**
   - Check console for: "✅ UsageStats monitoring started successfully"
   - Use debug widget "Start Monitor" button if needed

## Using the Debug Widget

The home screen now has a **Debug Info** widget at the bottom that shows:

- **Foreground App**: Current app in foreground
- **Is Locked**: Whether that app is locked
- **Monitoring**: Whether monitoring is active
- **Locked Apps**: List of all locked apps

### Test Buttons:

1. **"Check App"**: Manually check current foreground app
2. **"Start Monitor"**: Manually start monitoring (if not running)

## Console Logs to Check

When you open a locked app, you should see these logs in order:

```
📱 Foreground app changed: [old app] -> [locked app]
🔍 Checking if locked: [package] -> true
🚨 LOCKED APP DETECTED: [package]
🚨 Calling callback with: [package] ([app name])
🔒 Locked app detected callback: [package]
🔒 Showing overlay for locked app: [package]
Showing lock overlay for: [package] ([app name])
```

## Common Issues & Solutions

### Issue 1: "Foreground App: Unknown"
**Problem**: Usage stats not detecting apps
**Solution**:
- Verify usage stats permission is granted
- Restart the app after granting permission
- Check native Android code is working (see logs)

### Issue 2: "Is Locked: NO" for a locked app
**Problem**: App not in locked apps list
**Solution**:
- Go to "Installed Apps"
- Find the app and toggle the switch ON
- Verify it appears in "Locked Apps" on home screen

### Issue 3: "Monitoring: Inactive"
**Problem**: Monitoring not started
**Solution**:
- Ensure app lock toggle is ON
- Tap "Start Monitor" button in debug widget
- Check console for monitoring start message

### Issue 4: No overlay appears
**Problem**: Overlay service not working
**Solution**:
- Verify overlay permission is granted
- Check console for overlay messages
- Native overlay should show a simple black screen with unlock button
- If native fails, Flutter overlay will try (only works in our app)

## Testing Procedure

1. **Setup**:
   ```
   - Open Nova App Lock
   - Enable "App Lock" toggle
   - Grant all permissions
   - Add an app to lock list (e.g., "Settings")
   ```

2. **Test Detection**:
   ```
   - Stay in Nova App Lock app
   - Check debug widget shows locked apps
   - Tap "Check App" - should show current app
   - Open the locked app (e.g., Settings)
   - Check debug widget - should show Settings as foreground
   - Check "Is Locked" - should show YES
   ```

3. **Test Overlay**:
   ```
   - Press home button
   - Open the locked app
   - Overlay should appear immediately
   - If not, check console logs
   ```

## Native Overlay vs Flutter Overlay

- **Native Overlay** (OverlayService.kt): Works over other apps, shows simple unlock button
- **Flutter Overlay** (overlay_support): Only works when our app is in foreground

The app tries native first, falls back to Flutter if native fails.

## Manual Testing Commands

Check if monitoring is running:
```bash
adb logcat | grep -i "UsageStats\|monitoring\|Locked app"
```

Check permissions:
```bash
adb shell dumpsys package com.example.novaapplock | grep -A 10 "granted=true"
```

Test foreground app detection:
```bash
# In debug widget, tap "Check App" button
# Should show the current app package name
```

## Expected Behavior

1. **When you enable app lock**:
   - Console: "Starting monitoring from home screen toggle"
   - Console: "✅ UsageStats monitoring started successfully"
   - Debug widget: "Monitoring: Active"

2. **When you open a locked app**:
   - Console: "📱 Foreground app changed..."
   - Console: "🔍 Checking if locked: ... -> true"
   - Console: "🚨 LOCKED APP DETECTED: ..."
   - Overlay appears (native or Flutter)

3. **If overlay doesn't appear**:
   - Check console for error messages
   - Verify overlay permission
   - Try "Start Monitor" button
   - Check if callback is set (should see "Locked app detected callback")

## Still Not Working?

1. **Check all console logs** - Look for error messages
2. **Verify permissions** - Both overlay and usage stats
3. **Restart app** - After granting permissions
4. **Check debug widget** - All info should be correct
5. **Try manual start** - Use "Start Monitor" button
6. **Check native code** - Verify MainActivity.kt is correct

## Next Steps if Still Failing

If monitoring is working but overlay doesn't show:
- The native overlay service might need to be a foreground service
- Consider using Accessibility Service instead (more reliable)
- Check if device has battery optimization enabled (may kill background monitoring)

