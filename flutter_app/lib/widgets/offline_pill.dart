import 'package:flutter/material.dart';

import '../theme.dart';

/// The persistent "OFFLINE" indicator. Appears in the top bar of every
/// screen. This is intentionally prominent — it's the feature, not a
/// warning. Pulses subtly to draw the eye without being annoying.
class OfflinePill extends StatefulWidget {
  const OfflinePill({super.key});

  @override
  State<OfflinePill> createState() => _OfflinePillState();
}

class _OfflinePillState extends State<OfflinePill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: MMColors.terracotta,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Container(
              width: 6, height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4 + _ctrl.value * 0.6),
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 5),
          const Text(
            'OFFLINE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}
