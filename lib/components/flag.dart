import 'package:flutter/material.dart';

/// Shows an aging flag based on days since [createdAtMillis].
///
/// - < 20 days: neutral (secondary color)
/// - >= 20 days: green
/// - >= 40 days: yellow
/// - >= 60 days: red
class AgingFlag extends StatelessWidget {
  final int createdAtMillis;
  final double size;
  final EdgeInsets padding;

  const AgingFlag({
    super.key,
    required this.createdAtMillis,
    this.size = 12,
    this.padding = const EdgeInsets.all(0),
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final created = DateTime.fromMillisecondsSinceEpoch(createdAtMillis).toLocal();
    final days = now.difference(created).inDays;

    Color color;
    if (days >= 60) {
      color = Colors.red;
    } else if (days >= 40) {
      color = Colors.yellow.shade700;
    } else if (days >= 20) {
      color = Colors.green;
    } else {
      color = Theme.of(context).colorScheme.secondary; // neutral
    }

    return Padding(
      padding: padding,
      child: Tooltip(
        message: '$days day(s) old',
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).colorScheme.surface,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}


