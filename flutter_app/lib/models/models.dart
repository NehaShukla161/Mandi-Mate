/// Data models for Mandi Mate. Kept small and immutable; parsed from the
/// pre-computed `forecasts.json` asset bundled with the app.

class PriceObservation {
  final DateTime date;
  final double price;

  const PriceObservation({required this.date, required this.price});

  factory PriceObservation.fromJson(Map<String, dynamic> j) => PriceObservation(
        date: DateTime.parse(j['date'] as String),
        price: (j['price'] as num).toDouble(),
      );
}

class ForecastPoint {
  final DateTime date;
  final double price;        // ensemble mean
  final double sarima;
  final double holtWinters;
  final double low95;
  final double high95;

  const ForecastPoint({
    required this.date,
    required this.price,
    required this.sarima,
    required this.holtWinters,
    required this.low95,
    required this.high95,
  });

  factory ForecastPoint.fromJson(Map<String, dynamic> j) => ForecastPoint(
        date: DateTime.parse(j['date'] as String),
        price: (j['price'] as num).toDouble(),
        sarima: (j['sarima'] as num).toDouble(),
        holtWinters: (j['holt_winters'] as num).toDouble(),
        low95: (j['low_95'] as num).toDouble(),
        high95: (j['high_95'] as num).toDouble(),
      );
}

class MandiForecast {
  final String mandi;
  final DateTime generatedAt;
  final List<PriceObservation> history;
  final List<ForecastPoint> forecast;

  const MandiForecast({
    required this.mandi,
    required this.generatedAt,
    required this.history,
    required this.forecast,
  });

  factory MandiForecast.fromJson(String name, Map<String, dynamic> j) => MandiForecast(
        mandi: name,
        generatedAt: DateTime.parse(j['generated_at'] as String),
        history: (j['history'] as List)
            .map((e) => PriceObservation.fromJson(e as Map<String, dynamic>))
            .toList(),
        forecast: (j['forecast'] as List)
            .map((e) => ForecastPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  double get currentPrice => history.last.price;
  ForecastPoint forecastAtDay(int daysAhead) =>
      forecast[daysAhead.clamp(0, forecast.length - 1)];
}

/// Net-profit breakdown for one mandi on one day, used by the
/// `calculate_net_profit` tool.
class ProfitBreakdown {
  final String mandi;
  final double pricePerKg;
  final double quantityKg;
  final double grossRevenue;
  final double transportCost;
  final double commission;
  final double netProfit;
  final DateTime forDate;
  final bool isForecast;

  const ProfitBreakdown({
    required this.mandi,
    required this.pricePerKg,
    required this.quantityKg,
    required this.grossRevenue,
    required this.transportCost,
    required this.commission,
    required this.netProfit,
    required this.forDate,
    required this.isForecast,
  });

  Map<String, dynamic> toJson() => {
        'mandi': mandi,
        'date': forDate.toIso8601String().split('T').first,
        'price_per_kg': pricePerKg,
        'quantity_kg': quantityKg,
        'gross': grossRevenue,
        'transport': transportCost,
        'commission': commission,
        'net': netProfit,
        'is_forecast': isForecast,
      };
}

enum RecommendationAction { sellToday, holdThenSell, transportToMandi }

/// The agent's final output, rendered on the recommendation screen.
class Recommendation {
  final RecommendationAction action;
  final String mandi;
  final int holdDays;
  final ProfitBreakdown bestOption;
  final List<ProfitBreakdown> alternatives;
  final String reasoningMarathi;
  final String reasoningEnglish;

  const Recommendation({
    required this.action,
    required this.mandi,
    required this.holdDays,
    required this.bestOption,
    required this.alternatives,
    required this.reasoningMarathi,
    required this.reasoningEnglish,
  });
}
