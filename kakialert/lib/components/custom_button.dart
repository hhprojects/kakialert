import 'package:flutter/material.dart';
import '../utils/TColorTheme.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final Color? borderColor;
  final double? width;
  final double? height;
  final double? fontSize;
  final FontWeight? fontWeight;
  final double? borderRadius;
  final double? elevation;
  final EdgeInsetsGeometry? padding;
  final bool isEnabled;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderColor,
    this.width,
    this.height = 56,
    this.fontSize = 18,
    this.fontWeight = FontWeight.w600,
    this.borderRadius = 28,
    this.elevation = 2,
    this.padding,
    this.isEnabled = true,
  });

  // Factory constructors for common button styles
  factory CustomButton.primary({
    required String text,
    VoidCallback? onPressed,
    double? width,
    double? height,
    bool isEnabled = true,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      backgroundColor: TColorTheme.white,
      textColor: TColorTheme.gray,
      width: width,
      height: height,
      isEnabled: isEnabled,
    );
  }

  factory CustomButton.secondary({
    required String text,
    VoidCallback? onPressed,
    double? width,
    double? height,
    bool isEnabled = true,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      backgroundColor: TColorTheme.white,
      textColor: TColorTheme.primaryOrange,
      borderColor: TColorTheme.lightGray,
      width: width,
      height: height,
      isEnabled: isEnabled,
    );
  }

  factory CustomButton.outline({
    required String text,
    VoidCallback? onPressed,
    Color? borderColor,
    Color? textColor,
    double? width,
    double? height,
    bool isEnabled = true,
  }) {
    return CustomButton(
      text: text,
      onPressed: onPressed,
      backgroundColor: Colors.transparent,
      textColor: textColor ?? TColorTheme.primaryBlue,
      borderColor: borderColor ?? TColorTheme.primaryBlue,
      width: width,
      height: height,
      elevation: 0,
      isEnabled: isEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: ElevatedButton(
        onPressed: isEnabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? TColorTheme.white,
          foregroundColor: textColor ?? TColorTheme.primaryOrange,
          elevation: elevation,
          shadowColor: Colors.black26,
          disabledBackgroundColor: TColorTheme.gray.withOpacity(0.3),
          disabledForegroundColor: TColorTheme.gray,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius ?? 28),
            side: BorderSide(
              color: isEnabled 
                ? (borderColor ?? TColorTheme.lightGray)
                : TColorTheme.gray.withOpacity(0.3),
              width: 1,
            ),
          ),
          padding: padding,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
} 