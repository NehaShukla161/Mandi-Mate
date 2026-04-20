import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/forecast_service.dart';
import '../theme.dart';
import '../widgets/offline_pill.dart';
import 'voice_screen.dart';
import 'camera_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final forecasts = context.read<ForecastService>();
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());
    final prices = forecasts.currentPrices().take(3).toList();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _TopBar(),
              const SizedBox(height: 24),
              Text(
                'नमस्कार रमेश',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Good morning, Ramesh · $today',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              _ActionCard(
                icon: '📷',
                tint: MMColors.turmeric,
                title: 'Check my tomatoes',
                subtitle: 'माझे टोमॅटो तपासा — grade quality, estimate weight',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CameraScreen()),
                ),
              ),
              const SizedBox(height: 10),
              _ActionCard(
                icon: '🎙️',
                tint: MMColors.terracotta,
                title: 'Ask a question',
                subtitle: 'काहीतरी विचारा — speak in Marathi',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoiceScreen()),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(child: _MandiStrip(rows: prices, generatedAt: forecasts.generatedAt)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Mandi·Mate',
          style: Theme.of(context).textTheme.displayLarge!.copyWith(fontSize: 22),
        ),
        const SizedBox(width: 8),
        const OfflinePill(),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color tint;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MMColors.card,
          border: Border.all(color: MMColors.lineSoft),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tint.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(icon, style: const TextStyle(fontSize: 26)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MandiStrip extends StatelessWidget {
  final List<({String mandi, double price})> rows;
  final DateTime? generatedAt;
  const _MandiStrip({required this.rows, required this.generatedAt});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: MMColors.card,
        border: Border.all(color: MMColors.lineSoft),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('NEARBY MANDI PRICES',
                  style: Theme.of(context).textTheme.labelSmall),
              Text(
                generatedAt != null
                    ? 'synced ${_humanize(DateTime.now().difference(generatedAt!))}'
                    : '',
                style: const TextStyle(fontSize: 10, color: MMColors.inkSoft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...rows.map((r) => _MandiRow(name: r.mandi, price: r.price)),
        ],
      ),
    );
  }

  String _humanize(Duration d) {
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _MandiRow extends StatelessWidget {
  final String name;
  final double price;
  const _MandiRow({required this.name, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            '₹${price.toStringAsFixed(2)}',
            style: const TextStyle(
              fontFamily: 'Fraunces',
              fontWeight: FontWeight.w500,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
