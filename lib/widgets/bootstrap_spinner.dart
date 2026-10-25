import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Web-safe indeterminate loader for bootstrap / shell loading states.
///
/// On web, [CircularProgressIndicator] can assert after hot restart when the
/// view is disposed (see flutter/flutter#175260); Cupertino’s spinner avoids that.
class BootstrapSpinner extends StatelessWidget {
  const BootstrapSpinner({
    super.key,
    this.size = 24,
    this.strokeWidth = 2,
    this.strongTint = false,
  });

  final double size;
  final double strokeWidth;
  final bool strongTint;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final color = strongTint ? primary.withValues(alpha: 0.85) : primary;
    if (kIsWeb) {
      return SizedBox(
        width: size,
        height: size,
        child: CupertinoActivityIndicator(radius: size * 0.42, color: color),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}
