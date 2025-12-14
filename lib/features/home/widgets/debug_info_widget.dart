import 'dart:async';
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
  Timer? _refreshTimer;

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
    final isLocked = foregroundApp != null ? await UsageStatsService.isAppLocked(foregroundApp) : false;
    
    setState(() {
      _lockedApps = lockedApps;
      _foregroundApp = foregroundApp ?? 'Unknown';
      _isMonitoring = UsageStatsService.onLockedAppDetected != null;
    });
    
    if (foregroundApp != null && isLocked) {
      print('🔍 Debug: Foreground app $foregroundApp is in locked list');
    }
  }

  void _startPeriodicCheck() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (mounted) {
        _loadInfo();
      } else {
        timer.cancel();
      }
    });
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
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
            FutureBuilder<bool>(
              future: _foregroundApp != 'Unknown' 
                  ? UsageStatsService.isAppLocked(_foregroundApp)
                  : Future.value(false),
              builder: (context, snapshot) {
                final isLocked = snapshot.data ?? false;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Foreground App: $_foregroundApp'),
                    const SizedBox(height: 4),
                    Text('Is Locked: ${isLocked ? "YES" : "NO"}'),
                    const SizedBox(height: 4),
                    Text('Monitoring: ${_isMonitoring ? "Active" : "Inactive"}'),
                  ],
                );
              },
            ),
            const SizedBox(height: 4),
            Text('Locked Apps Count: ${_lockedApps.length}'),
            const SizedBox(height: 4),
            Text('Locked Apps: ${_lockedApps.isEmpty ? "None" : _lockedApps.join(", ")}'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final app = await UsageStatsService.getForegroundApp();
                      final isLocked = app != null ? await UsageStatsService.isAppLocked(app) : false;
                      setState(() {
                        _foregroundApp = app ?? 'Unknown';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Foreground: $_foregroundApp\nLocked: $isLocked'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text('Check App'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      UsageStatsService.startMonitoring();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Monitoring started')),
                      );
                    },
                    child: const Text('Start Monitor'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

