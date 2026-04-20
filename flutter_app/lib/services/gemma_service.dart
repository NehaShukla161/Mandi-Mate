import 'dart:async';
import 'dart:convert';

import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/models.dart';
import 'forecast_service.dart';
import 'tools.dart';

/// System prompt for Gemma 4 — kept short because on-device context is
/// precious. The critical safety clause is the last sentence: never
/// invent prices. Grounding in tool outputs is non-negotiable.
const String _systemPrompt = '''
You are Mandi Mate — a trusted advisor to a smallholder tomato farmer in Maharashtra, India.

Rules:
- Respond in simple spoken Marathi (Devanagari script).
- Keep answers short: 2–3 sentences max.
- For any "should I sell / hold / transport" question, always call get_mandi_prices and at least two forecast_price calls before answering.
- Always back recommendations with specific numbers from tool results.
- End with exactly one clear action: "विका" (sell), "थांबा N दिवस" (wait N days), or "N मंडी मध्ये जा" (go to N mandi).
- Never invent prices, forecasts, or numbers. Only use tool outputs.
- If tool calls fail or data is missing, say so honestly in Marathi.
''';

/// Result returned by [GemmaService.ask]. The Marathi text is what the
/// TTS layer will speak; the structured recommendation drives the UI.
class AgentResult {
  final String marathiAnswer;
  final String englishGloss;
  final Recommendation? recommendation;
  final List<ToolInvocation> toolTrace;

  const AgentResult({
    required this.marathiAnswer,
    required this.englishGloss,
    required this.recommendation,
    required this.toolTrace,
  });
}

class ToolInvocation {
  final String name;
  final Map<String, dynamic> args;
  final Map<String, dynamic> result;
  final Duration elapsed;

  const ToolInvocation({
    required this.name,
    required this.args,
    required this.result,
    required this.elapsed,
  });
}

class GemmaService {
  final ForecastService forecastService;
  late final ToolService tools;

  InferenceModel? _model;
  Completer<void>? _warmupCompleter;

  GemmaService({required this.forecastService}) {
    tools = ToolService(forecastService);
  }

  /// First-time model load. Expensive (~3s on midrange Android).
  /// Kicked off in background at app start.
  Future<void> warmup() async {
    if (_warmupCompleter != null) return _warmupCompleter!.future;
    _warmupCompleter = Completer<void>();

    try {
      // flutter_gemma picks up the bundled model from the app's asset
      // directory. The model file itself (Gemma 4 E2B/E4B int4 quantized)
      // is not committed to this repo — see docs/MODEL_SETUP.md.
      final gemma = FlutterGemmaPlugin.instance;
      await gemma.modelManager.installModelFromAsset('gemma4_e2b_q4.task');
      _model = await gemma.createModel(
        modelType: ModelType.gemmaIt,
        preferredBackend: PreferredBackend.gpu, // falls back to CPU automatically
        maxTokens: 1024,
        supportImage: true,
      );
      _warmupCompleter!.complete();
    } catch (e, st) {
      _warmupCompleter!.completeError(e, st);
      rethrow;
    }
  }

  /// The main entrypoint: take a farmer's Marathi question (plus optional
  /// image + weight estimate from the vision step) and return a grounded
  /// Marathi answer with a structured recommendation.
  Future<AgentResult> ask({
    required String marathiQuestion,
    double? quantityKg,
    String grade = 'A',
  }) async {
    await warmup();
    final model = _model!;
    final session = await model.createSession(
      temperature: 0.3,
      randomSeed: 1,
      topK: 40,
    );

    await session.addQueryChunk(Message.text(
      text: _systemPrompt + '\n\nFarmer weight estimate: '
          '${quantityKg?.toStringAsFixed(1) ?? "unknown"} kg, grade $grade.\n\n'
          'Farmer question (Marathi): $marathiQuestion',
      isUser: true,
    ));

    final trace = <ToolInvocation>[];
    String finalAnswer = '';

    // Function-calling loop: iterate until the model stops requesting tools
    // or we hit a safety cap. In practice 4–6 iterations is plenty.
    for (int step = 0; step < 8; step++) {
      final response = await session.getResponse();

      // flutter_gemma returns a Message that may contain text or tool-call
      // blocks. The exact API shape has shifted across versions — this is
      // written against the 0.9.x contract.
      final toolCalls = _extractToolCalls(response);
      if (toolCalls.isEmpty) {
        finalAnswer = response.text;
        break;
      }

      for (final call in toolCalls) {
        final sw = Stopwatch()..start();
        final result = _dispatch(call.name, call.args);
        sw.stop();
        trace.add(ToolInvocation(
          name: call.name,
          args: call.args,
          result: result,
          elapsed: sw.elapsed,
        ));
        await session.addQueryChunk(Message.toolResponse(
          toolName: call.name,
          content: jsonEncode(result),
        ));
      }
    }

    await session.close();
    return _parseFinal(finalAnswer, trace, quantityKg: quantityKg, grade: grade);
  }

  Map<String, dynamic> _dispatch(String name, Map<String, dynamic> args) {
    switch (name) {
      case 'get_mandi_prices':
        return tools.getMandiPrices(
          mandis: (args['mandis'] as List?)?.cast<String>(),
        );
      case 'calculate_net_profit':
        return tools.calculateNetProfit(
          mandi: args['mandi'] as String,
          quantityKg: (args['quantity_kg'] as num).toDouble(),
          grade: args['grade'] as String,
          daysAhead: (args['days_ahead'] as int?) ?? 0,
        );
      case 'forecast_price':
        return tools.forecastPrice(
          mandi: args['mandi'] as String,
          horizonDays: (args['horizon_days'] as int?) ?? 7,
        );
      default:
        return {'error': 'Unknown tool: $name'};
    }
  }

  List<_Call> _extractToolCalls(dynamic response) {
    // Adapt to whatever shape flutter_gemma exposes. Pseudocode shape:
    // response.toolCalls: List<{name, args}>. If the SDK returns free-form
    // text with inline JSON tool markup instead, parse here.
    try {
      final raw = (response as dynamic).toolCalls as List? ?? [];
      return raw
          .map((c) => _Call(c.name as String, (c.args as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Best-effort: derive a structured Recommendation from the Marathi
  /// answer plus the tool trace. In practice we rely on the trace, since
  /// parsing free-form Marathi is unreliable.
  AgentResult _parseFinal(
    String marathi,
    List<ToolInvocation> trace, {
    double? quantityKg,
    required String grade,
  }) {
    // Find the best profit among all calculate_net_profit invocations.
    final profits = trace
        .where((t) => t.name == 'calculate_net_profit' && t.result['error'] == null)
        .map((t) => ProfitBreakdown(
              mandi: t.result['mandi'] as String,
              pricePerKg: (t.result['price_per_kg'] as num).toDouble(),
              quantityKg: (t.result['quantity_kg'] as num).toDouble(),
              grossRevenue: (t.result['gross'] as num).toDouble(),
              transportCost: (t.result['transport'] as num).toDouble(),
              commission: (t.result['commission'] as num).toDouble(),
              netProfit: (t.result['net'] as num).toDouble(),
              forDate: DateTime.parse(t.result['date'] as String),
              isForecast: t.result['is_forecast'] as bool,
            ))
        .toList()
      ..sort((a, b) => b.netProfit.compareTo(a.netProfit));

    Recommendation? rec;
    if (profits.isNotEmpty) {
      final best = profits.first;
      final today = DateTime.now();
      final holdDays = best.forDate.difference(today).inDays;
      rec = Recommendation(
        action: holdDays > 0
            ? RecommendationAction.holdThenSell
            : (best.mandi == 'Nashik' ? RecommendationAction.sellToday : RecommendationAction.transportToMandi),
        mandi: best.mandi,
        holdDays: holdDays.clamp(0, 14),
        bestOption: best,
        alternatives: profits.skip(1).take(3).toList(),
        reasoningMarathi: marathi,
        reasoningEnglish: '(English gloss generated separately from tool trace)',
      );
    }

    return AgentResult(
      marathiAnswer: marathi,
      englishGloss: '', // could be filled with a second Gemma call if desired
      recommendation: rec,
      toolTrace: trace,
    );
  }
}

class _Call {
  final String name;
  final Map<String, dynamic> args;
  _Call(this.name, this.args);
}
