import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionUtils {
  static Future<bool> requestWithRationale(
    BuildContext context,
    Permission permission,
    String title,
    String rationale,
  ) async {
    final status = await permission.status;
    if (status.isGranted) return true;

    if (context.mounted) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(rationale),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('موافق'),
            ),
          ],
        ),
      );
      
      if (proceed != true) return false;
    }

    final newStatus = await permission.request();
    return newStatus.isGranted;
  }
}
