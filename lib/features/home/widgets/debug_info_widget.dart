import 'package:flutter/material.dart';
import '../../../services/permission_service.dart';
import '../../../services/usage_stats_service.dart';

class DebugInfoWidget extends StatefulWidget {
  const DebugInfoWidget({super.key});

  @override
  State<DebugInfoWidget> createState() => _DebugInfoWidgetState();
}

class _DebugInfoWidgetState extends State<DebugInfoWidget> {
  String _foregroundApp = 'Unknown';
  bool _isMonitoring = false;
  List<String> _lockedApps = [];

  @override
  void initState() {
    super.initState();
    _loadInfo();
    _startPeriodicCheck();
  }

  Future<void> _loadInfo() async {
    final permissions = await PermissionService.checkAllPermissions();
    final lockedApps = await UsageStatsService.getLockedApps();
    final foregroundApp = await UsageStatsService.getForegroundApp();
    
    setState(() {
      _lockedApps = lockedApps;
      _foregroundApp = foregroundApp ?? 'Unknown';
    });
  }

  void _startPeriodicCheck() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadInfo();
        _startPeriodicCheck();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Debug Info',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Foreground App: $_foregroundApp'),
            const SizedBox(height: 4),
            Text('Locked Apps Count: ${_lockedApps.length}'),
            const SizedBox(height: 4),
            Text('Locked Apps: ${_lockedApps.join(", ")}'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () async {
                final app = await UsageStatsService.getForegroundApp();
                setState(() {
                  _foregroundApp = app ?? 'Unknown';
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Foreground: $_foregroundApp')),
                );
              },
              child: const Text('Check Foreground App'),
            ),
          ],
        ),
      ),
    );
  }
}

