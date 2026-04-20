import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../services/forecast_service.dart';
import '../services/gemma_service.dart';
import '../services/voice_service.dart';
import '../theme.dart';

/// The payoff screen — shows Ramesh what to do, why, and lets him hear
/// the reasoning in Marathi.
class RecommendationScreen extends StatelessWidget {
  final AgentResult result;
  const RecommendationScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final rec = result.recommendation;
    return Scaffold(
      backgroundColor: MMColors.bg,
      appBar: AppBar(
        backgroundColor: MMColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: MMColors.ink),
      ),
      body: SafeArea(
        child: rec == null
            ? const _FallbackView()
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _RecommendationCard(
                      rec: rec,
                      marathi: result.marathiAnswer,
                    ),
                    const SizedBox(height: 18),
                    Text('WHY THIS DECISION',
                        style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: 8),
                    _ComparisonList(rec: rec),
                    const SizedBox(height: 18),
                    _ForecastChart(mandi: rec.mandi),
                    const SizedBox(height: 18),
                    _TraceSection(trace: result.toolTrace),
                  ],
                ),
              ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final Recommendation rec;
  final String marathi;
  const _RecommendationCard({required this.rec, required this.marathi});

  @override
  Widget build(BuildContext context) {
    // Compose Marathi action line from the structured recommendation. We
    // prefer the free-form Marathi from the model, but fall back to this
    // canonical phrasing when needed.
    final marathiAction = marathi.isNotEmpty
        ? marathi
        : _canonicalMarathi(rec);
    final english = _englishGloss(rec);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MMColors.turmeric, MMColors.terracotta],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MMColors.terracottaDk.withOpacity(0.25),
            blurRadius: 16, offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RECOMMENDATION',
            style: TextStyle(
              color: Colors.white70, fontSize: 11,
              fontWeight: FontWeight.w700, letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            marathiAction,
            style: const TextStyle(
              fontFamily: 'TiroDevanagariMarathi',
              color: Colors.white,
              fontSize: 26, height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            english,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: _SpeakButton(marathi: marathiAction),
          ),
        ],
      ),
    );
  }

  String _canonicalMarathi(Recommendation rec) {
    switch (rec.action) {
      case RecommendationAction.sellToday:
        return 'आजच विका — ${rec.mandi}';
      case RecommendationAction.holdThenSell:
        return 'थांबा ${rec.holdDays} दिवस —\n${rec.mandi} ला न्या';
      case RecommendationAction.transportToMandi:
        return '${rec.mandi} मध्ये विका';
    }
  }

  String _englishGloss(Recommendation rec) {
    switch (rec.action) {
      case RecommendationAction.sellToday:
        return 'Sell today at ${rec.mandi}';
      case RecommendationAction.holdThenSell:
        return 'Hold ${rec.holdDays} days, then take to ${rec.mandi}';
      case RecommendationAction.transportToMandi:
        return 'Take to ${rec.mandi}';
    }
  }
}

class _SpeakButton extends StatelessWidget {
  final String marathi;
  const _SpeakButton({required this.marathi});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => context.read<VoiceService>().speak(marathi),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          border: Border.all(color: Colors.white.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.volume_up, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text(
              'Play in Marathi',
              style: TextStyle(
                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonList extends StatelessWidget {
  final Recommendation rec;
  const _ComparisonList({required this.rec});

  @override
  Widget build(BuildContext context) {
    final rows = [rec.bestOption, ...rec.alternatives];
    return Column(
      children: [
        for (final (i, r) in rows.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _OptionRow(p: r, isBest: i == 0),
          ),
      ],
    );
  }
}

class _OptionRow extends StatelessWidget {
  final ProfitBreakdown p;
  final bool isBest;
  const _OptionRow({required this.p, required this.isBest});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        gradient: isBest
            ? const LinearGradient(
                colors: [Color(0xFFF0F4E4), Color(0xFFDEE5CB)],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: isBest ? null : MMColors.card,
        border: Border.all(
          color: isBest ? MMColors.sage : MMColors.lineSoft,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '${p.mandi}${p.isForecast ? " (hold ${_daysFromNow(p.forDate)} days)" : " today"}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,
                    ),
                  ),
                  if (isBest) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star, color: MMColors.sage, size: 14),
                  ],
                ],
              ),
              Text(
                '₹${p.netProfit.toStringAsFixed(0)} net',
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontWeight: FontWeight.w500, fontSize: 14,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 10,
            children: [
              _chipText('₹${p.pricePerKg.toStringAsFixed(2)}/kg'),
              _chipText('Transport ₹${p.transportCost.toStringAsFixed(0)}'),
              _chipText('Commission ₹${p.commission.toStringAsFixed(0)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipText(String s) => Text(
        s,
        style: const TextStyle(fontSize: 11, color: MMColors.inkSoft),
      );

  int _daysFromNow(DateTime d) =>
      d.difference(DateTime.now()).inDays.clamp(0, 14);
}

class _ForecastChart extends StatelessWidget {
  final String mandi;
  const _ForecastChart({required this.mandi});

  @override
  Widget build(BuildContext context) {
    final f = context.read<ForecastService>().forecastFor(mandi);
    if (f == null) return const SizedBox.shrink();

    final hist = f.history.sublist((f.history.length - 14).clamp(0, f.history.length));
    final fc = f.forecast.take(14).toList();
    final allPoints = [
      ...hist.map((p) => p.price),
      ...fc.map((p) => p.price),
      ...fc.map((p) => p.low95),
      ...fc.map((p) => p.high95),
    ];
    final yMin = (allPoints.reduce((a, b) => a < b ? a : b) - 2).floorToDouble();
    final yMax = (allPoints.reduce((a, b) => a > b ? a : b) + 2).ceilToDouble();

    final histSpots = [for (var i = 0; i < hist.length; i++) FlSpot(i.toDouble(), hist[i].price)];
    final fcSpots = [
      FlSpot((hist.length - 1).toDouble(), hist.last.price),
      for (var i = 0; i < fc.length; i++)
        FlSpot((hist.length + i).toDouble(), fc[i].price),
    ];
    final lowBand = [for (var i = 0; i < fc.length; i++) FlSpot((hist.length + i).toDouble(), fc[i].low95)];
    final highBand = [for (var i = 0; i < fc.length; i++) FlSpot((hist.length + i).toDouble(), fc[i].high95)];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
      decoration: BoxDecoration(
        color: MMColors.card,
        border: Border.all(color: MMColors.lineSoft),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$mandi price forecast · 14 days',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 4),
          Text('SARIMA + Holt-Winters ensemble · 95% confidence band',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                minY: yMin, maxY: yMax,
                minX: 0, maxX: (hist.length + fc.length - 1).toDouble(),
                gridData: FlGridData(
                  show: true, drawVerticalLine: false,
                  horizontalInterval: ((yMax - yMin) / 3).ceilToDouble(),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: MMColors.lineSoft, strokeWidth: 1, dashArray: [3, 3],
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true, reservedSize: 36,
                      interval: ((yMax - yMin) / 3).ceilToDouble(),
                      getTitlesWidget: (v, _) => Text(
                        '₹${v.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontFamily: 'Fraunces', fontSize: 10,
                          color: MMColors.inkSoft,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Confidence band — shaded between high and low
                  LineChartBarData(
                    spots: highBand,
                    isCurved: false, color: Colors.transparent, barWidth: 0,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      color: MMColors.sage.withOpacity(0.18),
                      cutOffY: 0, applyCutOffY: false,
                      spotsLine: BarAreaSpotsLine(show: false),
                    ),
                  ),
                  LineChartBarData(
                    spots: lowBand,
                    isCurved: false, color: Colors.transparent, barWidth: 0,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true, color: MMColors.bg,
                    ),
                  ),
                  // History — solid ink line
                  LineChartBarData(
                    spots: histSpots,
                    isCurved: true, curveSmoothness: 0.2,
                    color: MMColors.ink, barWidth: 2,
                    dotData: const FlDotData(show: false),
                  ),
                  // Forecast — dashed turmeric line
                  LineChartBarData(
                    spots: fcSpots,
                    isCurved: true, curveSmoothness: 0.2,
                    color: MMColors.turmeric, barWidth: 2.2,
                    dashArray: [5, 3],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 14,
            children: [
              _LegendChip(color: MMColors.ink, label: 'History'),
              _LegendChip(color: MMColors.turmeric, label: 'Forecast', dashed: true),
              _LegendChip(color: MMColors.sage, label: '95% CI', band: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  final bool band;
  const _LegendChip({
    required this.color, required this.label,
    this.dashed = false, this.band = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: band ? 10 : 3,
          decoration: BoxDecoration(
            color: band ? color.withOpacity(0.25) : color,
          ),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 10, color: MMColors.inkSoft)),
      ],
    );
  }
}

class _TraceSection extends StatelessWidget {
  final List<ToolInvocation> trace;
  const _TraceSection({required this.trace});

  @override
  Widget build(BuildContext context) {
    if (trace.isEmpty) return const SizedBox.shrink();
    return ExpansionTile(
      title: Text('Agent trace · ${trace.length} tool calls',
          style: Theme.of(context).textTheme.labelSmall),
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      children: [
        for (final t in trace)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MMColors.card,
              border: Border.all(color: MMColors.lineSoft),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${t.name}()',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w600,
                    color: MMColors.terracottaDk, fontSize: 11,
                  ),
                ),
                Text(
                  t.args.toString(),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 10, color: MMColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 4),
                Text('→ ${t.elapsed.inMilliseconds}ms',
                    style: const TextStyle(fontSize: 10, color: MMColors.sage)),
              ],
            ),
          ),
      ],
    );
  }
}

class _FallbackView extends StatelessWidget {
  const _FallbackView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          "Mandi Mate couldn't reach a confident recommendation. "
          "Please try again with more detail.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
