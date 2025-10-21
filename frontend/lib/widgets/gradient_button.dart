import 'package:flutter/material.dart';
import '../app/theme.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // تغيير إلى nullable
  final bool isFullWidth;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed, // إزالة required
    this.isFullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: isFullWidth ? double.infinity : null,
      decoration: onPressed != null
          ? AppTheme.gradientButton
          : BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(32),
            ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Center(
              child: Text(
                text,
                style: TextStyle(
                  color: onPressed != null ? Colors.white : Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
