import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/models.dart';

/// Loads the pre-computed `forecasts.json` that ships as an asset and
/// serves lookups to the function-calling layer.
///
/// Design: forecasts are baked in at build time rather than trained
/// on-device. This keeps inference fast and memory-cheap. The CI
/// pipeline re-runs `forecast_engine.py` nightly and ships a new
/// app asset bundle on a weekly cadence.
class ForecastService {
  Map<String, MandiForecast> _forecasts = {};
  DateTime? _generatedAt;

  Future<void> load() async {
    final raw = await rootBundle.loadString('assets/forecasts.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    _forecasts = decoded.map(
      (mandi, data) => MapEntry(mandi, MandiForecast.fromJson(mandi, data as Map<String, dynamic>)),
    );
    if (_forecasts.isNotEmpty) {
      _generatedAt = _forecasts.values.first.generatedAt;
    }
  }

  List<String> get mandis => _forecasts.keys.toList()..sort();
  DateTime? get generatedAt => _generatedAt;

  MandiForecast? forecastFor(String mandi) => _forecasts[mandi];

  /// Current prices across all mandis, sorted highest-first.
  /// Used on the home screen and by the `get_mandi_prices` tool.
  List<({String mandi, double price})> currentPrices() {
    final rows = _forecasts.entries
        .map((e) => (mandi: e.key, price: e.value.currentPrice))
        .toList();
    rows.sort((a, b) => b.price.compareTo(a.price));
    return rows;
  }

  /// Forecasted price for a specific mandi and day offset.
  /// Returns null if mandi not found or horizon out of range.
  double? priceInDays(String mandi, int daysAhead) {
    final f = _forecasts[mandi];
    if (f == null) return null;
    if (daysAhead <= 0) return f.currentPrice;
    if (daysAhead > f.forecast.length) return null;
    return f.forecastAtDay(daysAhead - 1).price;
  }
}
