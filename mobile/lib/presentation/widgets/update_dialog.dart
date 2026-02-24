import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_colors.dart';
import '../../data/services/version_check_service.dart';

/// Shows a dialog prompting the user to update the app.
/// - Force update: user cannot dismiss (no "Để sau" button)
/// - Soft update: user can dismiss
class UpdateDialog extends StatelessWidget {
  final VersionCheckResult result;

  const UpdateDialog({super.key, required this.result});

  /// Check version and show dialog if needed.
  /// Call this from your main screen's initState.
  static Future<void> checkAndShow(BuildContext context) async {
    final result = await VersionCheckService.check();
    if (result == null) return; // Network error or version check not available

    if (!context.mounted) return;

    if (result.forceUpdate) {
      // Force update — cannot dismiss
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) =>
            PopScope(canPop: false, child: UpdateDialog(result: result)),
      );
    } else if (result.updateAvailable) {
      // Soft update — can dismiss
      showDialog(
        context: context,
        builder: (_) => UpdateDialog(result: result),
      );
    }
  }

  void _openStore() async {
    final url = Uri.parse(result.storeUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            result.forceUpdate
                ? Icons.warning_amber_rounded
                : Icons.system_update,
            color: result.forceUpdate ? Colors.red : AppColors.primary,
            size: 28,
          ),
          const SizedBox(width: 10),
          Text(
            result.forceUpdate ? 'Cập nhật bắt buộc' : 'Phiên bản mới',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phiên bản ${result.latestVersion} đã có trên Store.',
            style: const TextStyle(fontSize: 15),
          ),
          if (result.releaseNotes.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.releaseNotes,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ),
          ],
          if (result.forceUpdate) ...[
            const SizedBox(height: 12),
            Text(
              'Phiên bản hiện tại không còn được hỗ trợ. Vui lòng cập nhật để tiếp tục sử dụng MChat.',
              style: TextStyle(fontSize: 13, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
      actions: [
        // "Để sau" button — only for soft update
        if (!result.forceUpdate)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
          ),
        // "Cập nhật" button
        ElevatedButton.icon(
          onPressed: _openStore,
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Cập nhật ngay'),
          style: ElevatedButton.styleFrom(
            backgroundColor: result.forceUpdate
                ? Colors.red
                : AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}
