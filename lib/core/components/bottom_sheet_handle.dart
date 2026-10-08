import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class BottomSheetHandle extends StatelessWidget {
  final String? title;

  const BottomSheetHandle({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 36,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.textTertiary,
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
        ),
        if (title != null) ...[
          const SizedBox(height: 20),
          Text(
            title!,
            style: AppTypography.headingLarge.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}
