import '../models/models.dart';
import 'forecast_service.dart';

/// Transport cost model: flat ₹/km/quintal baseline for Maharashtra
/// State Transport rates, scaled by quintals. Real production should
/// read from a district-level config, but this is close enough for demo.
const double _costPerKmPerQuintal = 2.8;

/// APMC commission rate for vegetables (6% is the Maharashtra norm for
/// tomatoes); published on each APMC's bylaws.
const double _commissionRate = 0.06;

/// Hardcoded road distances (km) from a notional farm in Nashik district
/// (Niphad taluka) to each mandi. A real app would use the phone's
/// cached GPS + a bundled road distance matrix.
const Map<String, double> _distanceFromFarmKm = {
  'Nashik':     22.0,
  'Pune':       198.0,
  'Aurangabad': 145.0,
  'Nagpur':     520.0,
  'Kolhapur':   385.0,
};

/// Grade-based discount factor applied to the published mandi price.
/// Grade A = full price, B = 85%, C = 70%. Reflects real sorting discounts.
const Map<String, double> _gradeDiscount = {
  'A': 1.00,
  'B': 0.85,
  'C': 0.70,
};

/// ToolService exposes three tools that Gemma 4 invokes via function
/// calling. Each tool is deterministic, pure, and returns a JSON-able
/// Map. The string returned to the model is a terse human-readable
/// summary; the full structured data is kept separately for the UI.
class ToolService {
  final ForecastService forecast;
  ToolService(this.forecast);

  /// TOOL 1 — Get the most recent mandi prices.
  /// Signature for the model: get_mandi_prices(mandis?: string[])
  Map<String, dynamic> getMandiPrices({List<String>? mandis}) {
    final list = mandis ?? forecast.mandis;
    final rows = list
        .map((m) => forecast.forecastFor(m))
        .whereType<MandiForecast>()
        .map((f) => {
              'mandi': f.mandi,
              'price_per_kg': f.currentPrice,
              'date': f.history.last.date.toIso8601String().split('T').first,
            })
        .toList();
    return {'prices': rows};
  }

  /// TOOL 2 — Compute net profit for selling at a specific mandi on a
  /// specific day offset (0 = today, otherwise a forecast day).
  /// Signature: calculate_net_profit(mandi, quantity_kg, grade, days_ahead=0)
  Map<String, dynamic> calculateNetProfit({
    required String mandi,
    required double quantityKg,
    required String grade,
    int daysAhead = 0,
  }) {
    final publishedPrice = forecast.priceInDays(mandi, daysAhead);
    if (publishedPrice == null) {
      return {'error': 'Unknown mandi or horizon: $mandi / $daysAhead'};
    }

    final pricePerKg = publishedPrice * (_gradeDiscount[grade] ?? 1.0);
    final distanceKm = _distanceFromFarmKm[mandi] ?? 100.0;
    final quintals = quantityKg / 100.0;
    final transportCost = distanceKm * quintals * _costPerKmPerQuintal;
    final gross = pricePerKg * quantityKg;
    final commission = gross * _commissionRate;
    final net = gross - transportCost - commission;

    final breakdown = ProfitBreakdown(
      mandi: mandi,
      pricePerKg: pricePerKg,
      quantityKg: quantityKg,
      grossRevenue: gross,
      transportCost: transportCost,
      commission: commission,
      netProfit: net,
      forDate: DateTime.now().add(Duration(days: daysAhead)),
      isForecast: daysAhead > 0,
    );
    return breakdown.toJson();
  }

  /// TOOL 3 — Retrieve forecast for a mandi over the given horizon.
  /// Signature: forecast_price(mandi, horizon_days)
  Map<String, dynamic> forecastPrice({
    required String mandi,
    int horizonDays = 7,
  }) {
    final f = forecast.forecastFor(mandi);
    if (f == null) return {'error': 'Unknown mandi: $mandi'};

    final pts = f.forecast.take(horizonDays).map((p) => {
          'date': p.date.toIso8601String().split('T').first,
          'price': p.price,
          'low_95': p.low95,
          'high_95': p.high95,
        }).toList();

    return {
      'mandi': mandi,
      'horizon_days': horizonDays,
      'current_price': f.currentPrice,
      'forecast': pts,
      'peak_day': pts.reduce((a, b) =>
          (a['price'] as double) > (b['price'] as double) ? a : b),
    };
  }

  /// JSON schema for all three tools, passed to Gemma 4's function-calling
  /// interface. Kept close to the OpenAI/Anthropic tool-schema shape.
  static const List<Map<String, dynamic>> schema = [
    {
      'name': 'get_mandi_prices',
      'description':
          "Get today's prices across Maharashtra tomato mandis. Always call this first when the farmer asks about pricing or selling decisions.",
      'parameters': {
        'type': 'object',
        'properties': {
          'mandis': {
            'type': 'array',
            'items': {'type': 'string'},
            'description': 'Optional list of specific mandis. Omit for all.'
          }
        },
      }
    },
    {
      'name': 'calculate_net_profit',
      'description':
          'Compute net revenue (gross minus transport and commission) for selling a given quantity at a specific mandi, optionally on a future day.',
      'parameters': {
        'type': 'object',
        'required': ['mandi', 'quantity_kg', 'grade'],
        'properties': {
          'mandi': {'type': 'string', 'enum': ['Nashik','Pune','Aurangabad','Nagpur','Kolhapur']},
          'quantity_kg': {'type': 'number'},
          'grade': {'type': 'string', 'enum': ['A','B','C']},
          'days_ahead': {'type': 'integer', 'default': 0},
        },
      }
    },
    {
      'name': 'forecast_price',
      'description':
          'Get the SARIMA+Holt-Winters ensemble forecast for a mandi, up to 14 days ahead. Use when deciding whether to hold or sell.',
      'parameters': {
        'type': 'object',
        'required': ['mandi'],
        'properties': {
          'mandi': {'type': 'string'},
          'horizon_days': {'type': 'integer', 'default': 7},
        }
      }
    }
  ];
}
