import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../data/models/call_log_model.dart';
import '../../../providers/call_log_provider.dart';
import '../../../widgets/common/custom_avatar.dart';
import '../../call/call_screen.dart' as cs;

class CallsTab extends StatelessWidget {
  const CallsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // App Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Text(
                'Cuộc gọi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Consumer<CallLogProvider>(
                builder: (context, provider, _) {
                  if (provider.logs.isEmpty) return const SizedBox();
                  return IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => _showClearDialog(context, provider),
                  );
                },
              ),
            ],
          ),
        ),

        // Call list
        Expanded(
          child: Consumer<CallLogProvider>(
            builder: (context, provider, _) {
              if (provider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                );
              }

              if (provider.logs.isEmpty) {
                return _buildEmptyState();
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: provider.logs.length,
                itemBuilder: (context, index) {
                  return _CallLogItem(log: provider.logs[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.call_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Chưa có cuộc gọi nào',
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Lịch sử cuộc gọi sẽ hiện tại đây',
            style: TextStyle(color: Colors.grey[400], fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _showClearDialog(BuildContext context, CallLogProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Xóa lịch sử',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          'Bạn có chắc muốn xóa toàn bộ lịch sử cuộc gọi?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.clearAll();
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CallLogItem extends StatelessWidget {
  final CallLog log;

  const _CallLogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final isMissed = log.status == CallStatus.missed;
    final isRejected = log.status == CallStatus.rejected;
    final isIncoming = log.direction == CallDirection.incoming;
    final isVideo = log.callType == CallType.video;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: CustomAvatar(
        imageUrl: log.otherUserAvatar,
        name: log.otherUserName,
        size: 48,
      ),
      title: Text(
        log.otherUserName,
        style: TextStyle(
          color: isMissed ? Colors.red : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Row(
        children: [
          // Direction arrow
          Icon(
            isIncoming ? Icons.call_received : Icons.call_made,
            size: 14,
            color: isMissed || isRejected
                ? Colors.red
                : isIncoming
                ? Colors.green
                : AppColors.primary,
          ),
          const SizedBox(width: 4),
          // Call type text
          Text(
            _getStatusText(isIncoming, isMissed, isRejected),
            style: TextStyle(
              color: isMissed ? Colors.red[400] : AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          if (log.durationSeconds > 0) ...[
            Text(
              ' · ${_formatDuration(log.durationSeconds)}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _formatTime(log.startedAt),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Icon(
            isVideo ? Icons.videocam : Icons.call,
            size: 20,
            color: AppColors.primary,
          ),
        ],
      ),
      onTap: () {
        // Tap to call back
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => cs.CallScreen(
              calleeName: log.otherUserName,
              calleeAvatar: log.otherUserAvatar,
              callType: log.callType == CallType.video
                  ? cs.CallType.video
                  : cs.CallType.audio,
              callRole: cs.CallRole.caller,
              otherUserId: log.otherUserId,
            ),
          ),
        );
      },
    );
  }

  String _getStatusText(bool isIncoming, bool isMissed, bool isRejected) {
    if (isMissed) return 'Cuộc gọi nhỡ';
    if (isRejected) return isIncoming ? 'Đã từ chối' : 'Bị từ chối';
    return isIncoming ? 'Cuộc gọi đến' : 'Cuộc gọi đi';
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    if (m > 0) return '${m}p${s.toString().padLeft(2, '0')}s';
    return '${s}s';
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Hôm qua';
    } else if (diff.inDays < 7) {
      const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}';
    }
  }
}
