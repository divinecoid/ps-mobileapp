import 'package:flutter/material.dart';

class Toast {
  static OverlayEntry? _activeToast;
  static String? _activeMessage;
  static DateTime? _lastShownAt;

  static void show(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    final now = DateTime.now();
    if (_activeMessage == message &&
        _lastShownAt != null &&
        now.difference(_lastShownAt!) < const Duration(seconds: 2)) {
      return;
    }

    _activeToast?.remove();

    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 50,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isError
                  ? Colors.red.withOpacity(0.9)
                  : Colors.green.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isError ? Icons.error : Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    _activeToast = overlayEntry;
    _activeMessage = message;
    _lastShownAt = now;

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2)).then((_) {
      if (_activeToast == overlayEntry) {
        _activeToast = null;
        _activeMessage = null;
        _lastShownAt = null;
      }
      overlayEntry.remove();
    });
  }
}
