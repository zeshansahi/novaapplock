import 'package:flutter/material.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  VoidCallback? onResume;
  VoidCallback? onPause;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        onResume?.call();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        onPause?.call();
        break;
      case AppLifecycleState.hidden:
        break;
    }
  }
}

