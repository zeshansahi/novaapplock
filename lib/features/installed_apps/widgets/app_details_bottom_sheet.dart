import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';

class AppDetailsBottomSheet extends StatelessWidget {
  final Application app;

  const AppDetailsBottomSheet({
    super.key,
    required this.app,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (app is ApplicationWithIcon)
                Image.memory(
                  (app as ApplicationWithIcon).icon,
                  width: 64,
                  height: 64,
                )
              else
                const Icon(Icons.android, size: 64),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      app.appName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      app.packageName,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withOpacity(0.6),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (app.versionName != null)
            _buildDetailRow(
              context,
              'Version',
              app.versionName!,
            ),
          if (app.versionCode != null)
            _buildDetailRow(
              context,
              'Version Code',
              app.versionCode.toString(),
            ),
          _buildDetailRow(
            context,
            'System App',
            app.systemApp ? 'Yes' : 'No',
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock this app'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Premium / Coming soon',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
            textAlign: TextAlign.center,
          ),
          // TODO: Integrate real app lock engine here
          // This will enable actual app locking when implemented
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

