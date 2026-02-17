import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';

class FilterPills extends StatefulWidget {
  final bool isSelectionMode;
  final VoidCallback? onSelectAll;
  final bool allSelected;

  const FilterPills({
    super.key,
    this.isSelectionMode = false,
    this.onSelectAll,
    this.allSelected = false,
  });

  @override
  State<FilterPills> createState() => _FilterPillsState();
}

class _FilterPillsState extends State<FilterPills> {
  String selectedFilter = 'Tất cả';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildPill(
            'Tất cả',
            isSelected: widget.isSelectionMode
                ? widget.allSelected
                : selectedFilter == 'Tất cả',
          ),
          const SizedBox(width: 8),
          _buildAddPill(),
        ],
      ),
    );
  }

  Widget _buildPill(String label, {required bool isSelected}) {
    return GestureDetector(
      onTap: () {
        if (widget.isSelectionMode && widget.onSelectAll != null) {
          // In selection mode, "Tất cả" toggles select/deselect all
          widget.onSelectAll!();
        } else {
          setState(() {
            selectedFilter = label;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: AppTextStyles.filterPill.copyWith(
            color: isSelected ? AppColors.background : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildAddPill() {
    return GestureDetector(
      onTap: () {
        // TODO: Add new filter
      },
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.add, color: AppColors.textPrimary, size: 20),
      ),
    );
  }
}
