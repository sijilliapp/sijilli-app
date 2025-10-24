import 'package:flutter/material.dart';

class AppLogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  const AppLogo({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.backgroundColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget logo = Image.asset(
      'assets/logo/logo.png',
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width ?? 50,
          height: height ?? 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: borderRadius ?? BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.image_not_supported,
            color: Colors.grey.shade400,
            size: (width ?? 50) * 0.5,
          ),
        );
      },
    );

    if (backgroundColor != null || borderRadius != null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: borderRadius,
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.zero,
          child: logo,
        ),
      );
    }

    return logo;
  }
}

// Widget مخصص للشعار مع النص
class AppLogoWithText extends StatelessWidget {
  final double logoSize;
  final double fontSize;
  final String text;
  final Color? textColor;
  final FontWeight fontWeight;
  final MainAxisAlignment alignment;

  const AppLogoWithText({
    super.key,
    this.logoSize = 40,
    this.fontSize = 20,
    this.text = 'سجلي',
    this.textColor,
    this.fontWeight = FontWeight.bold,
    this.alignment = MainAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppLogo(
          width: logoSize,
          height: logoSize,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: textColor ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

// Widget للشعار الدائري
class CircularAppLogo extends StatelessWidget {
  final double size;
  final Color? backgroundColor;
  final double borderWidth;
  final Color? borderColor;

  const CircularAppLogo({
    super.key,
    this.size = 60,
    this.backgroundColor,
    this.borderWidth = 0,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.white,
        border: borderWidth > 0
            ? Border.all(
                color: borderColor ?? Colors.grey.shade300,
                width: borderWidth,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.15),
          child: AppLogo(
            width: size * 0.7,
            height: size * 0.7,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
