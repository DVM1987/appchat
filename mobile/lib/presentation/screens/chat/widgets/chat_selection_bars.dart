import 'package:flutter/material.dart';

/// Bottom bar shown during forward selection mode.
class ForwardSelectionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onForward;

  const ForwardSelectionBar({
    super.key,
    required this.selectedCount,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(
              onPressed: onForward,
              icon: const Icon(Icons.forward_outlined, size: 30),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Đã chọn $selectedCount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onForward,
              icon: const Icon(Icons.ios_share_outlined, size: 28),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom bar shown during delete selection mode.
class DeleteSelectionBar extends StatelessWidget {
  final int selectedCount;
  final VoidCallback onDelete;

  const DeleteSelectionBar({
    super.key,
    required this.selectedCount,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: Colors.white,
        child: Row(
          children: [
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, size: 30),
              color: const Color(0xFFE53935),
            ),
            Expanded(
              child: Center(
                child: Text(
                  'Đã chọn $selectedCount',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.check, size: 28),
              color: const Color(0xFFE53935),
            ),
          ],
        ),
      ),
    );
  }
}
