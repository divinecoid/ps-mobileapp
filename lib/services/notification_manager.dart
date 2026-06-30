import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/notification_provider.dart';

class NotificationManager {
  static NotificationManager? _instance;
  Timer? _timer;

  NotificationManager._();

  static NotificationManager get instance {
    _instance ??= NotificationManager._();
    return _instance!;
  }

  void start(BuildContext context) {
    // Run immediately then every 1 minute
    _runOnce(context);
    _timer?.cancel();
    _timer = Timer.periodic(Duration(minutes: 1), (_) => _runOnce(context));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _runOnce(BuildContext context) async {
    try {
      final provider = Provider.of<NotificationProvider>(context, listen: false);
      await provider.fetchLowStockAndSync();
    } catch (e) {
      // ignore errors silently for polling
      // optionally log
    }
  }
}
