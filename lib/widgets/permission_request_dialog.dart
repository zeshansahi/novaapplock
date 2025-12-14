import 'package:flutter/material.dart';
import '../services/permission_service.dart';

class PermissionRequestDialog extends StatelessWidget {
  final String permissionType;
  final String title;
  final String message;
  final VoidCallback? onGranted;
  final VoidCallback? onDenied;

  const PermissionRequestDialog({
    super.key,
    required this.permissionType,
    required this.title,
    required this.message,
    this.onGranted,
    this.onDenied,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 16),
          if (permissionType == 'overlay')
            const Text(
              'To grant this permission:\n'
              '1. Tap "Open Settings"\n'
              '2. Find "Nova App Lock"\n'
              '3. Enable "Display over other apps"\n'
              '4. Return to the app',
              style: TextStyle(fontSize: 12),
            )
          else if (permissionType == 'usageStats')
            const Text(
              'To grant this permission:\n'
              '1. Tap "Open Settings"\n'
              '2. Find "Nova App Lock"\n'
              '3. Enable "Usage access"\n'
              '4. Return to the app',
              style: TextStyle(fontSize: 12),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            onDenied?.call();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.of(context).pop();
            
            if (permissionType == 'overlay') {
              await PermissionService.openOverlaySettings();
            } else if (permissionType == 'usageStats') {
              await PermissionService.openUsageStatsSettings();
            }
            
            // Wait a bit for user to grant permission
            await Future.delayed(const Duration(seconds: 2));
            
            bool isGranted = false;
            if (permissionType == 'overlay') {
              isGranted = await PermissionService.isOverlayPermissionGranted();
            } else if (permissionType == 'usageStats') {
              isGranted = await PermissionService.isUsageStatsPermissionGranted();
            }
            
            if (isGranted) {
              onGranted?.call();
            } else {
              onDenied?.call();
            }
          },
          child: const Text('Open Settings'),
        ),
      ],
    );
  }

  static void show({
    required BuildContext context,
    required String permissionType,
    required String title,
    required String message,
    VoidCallback? onGranted,
    VoidCallback? onDenied,
  }) {
    // Ensure the context is still valid and mounted
    if (!context.mounted) return;
    
    // Use a post-frame callback to ensure layout is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => PermissionRequestDialog(
            permissionType: permissionType,
            title: title,
            message: message,
            onGranted: onGranted,
            onDenied: onDenied,
          ),
        );
      }
    });
  }
}

