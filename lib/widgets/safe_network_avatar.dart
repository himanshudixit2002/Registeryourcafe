import 'package:flutter/material.dart';

/// Circular avatar: network image when [imageUrl] is valid, else [fallbackIcon].
class SafeNetworkAvatar extends StatelessWidget {
  const SafeNetworkAvatar({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.fallbackIcon,
    this.fallbackBackgroundColor,
    this.fallbackIconColor,
  });

  final String? imageUrl;
  final double radius;
  final IconData fallbackIcon;
  final Color? fallbackBackgroundColor;
  final Color? fallbackIconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = fallbackBackgroundColor ?? theme.colorScheme.primaryContainer;
    final fg = fallbackIconColor ?? theme.colorScheme.onPrimaryContainer;
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Icon(fallbackIcon, color: fg, size: radius * 1.1),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(
          url,
          width: radius * 2,
          height: radius * 2,
          cacheWidth: 120,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
                ),
              ),
            );
          },
          errorBuilder: (_, _, _) => Icon(
            fallbackIcon,
            color: fg,
            size: radius * 1.1,
          ),
        ),
      ),
    );
  }
}
