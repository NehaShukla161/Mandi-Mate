import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/gemma_service.dart';
import '../services/voice_service.dart';
import '../theme.dart';
import 'recommendation_screen.dart';

/// Voice input screen. Flow: tap mic → STT → display transcript →
/// call Gemma (async, background) → push recommendation screen.
class VoiceScreen extends StatefulWidget {
  const VoiceScreen({super.key});

  @override
  State<VoiceScreen> createState() => _VoiceScreenState();
}

enum _Stage { idle, listening, thinking }

class _VoiceScreenState extends State<VoiceScreen> with SingleTickerProviderStateMixin {
  _Stage _stage = _Stage.idle;
  String _transcript = '';
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    final voice = context.read<VoiceService>();
    final gemma = context.read<GemmaService>();

    setState(() {
      _stage = _Stage.listening;
      _transcript = '';
    });

    try {
      final heard = await voice.listen();
      if (!mounted) return;
      setState(() {
        _transcript = heard;
        _stage = _Stage.thinking;
      });

      // Default to 18 kg grade A — in a full app, this comes from the
      // prior camera → vision pass. We persist the last vision estimate
      // in SharedPreferences between screens.
      final result = await gemma.ask(
        marathiQuestion: heard.isEmpty ? 'आज विकू का?' : heard,
        quantityKg: 18.5,
        grade: 'A',
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => RecommendationScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _stage = _Stage.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: MMColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: MMColors.ink),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'HOLD TO SPEAK',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 10),
              const Text(
                '"आज विकू का?"',
                style: TextStyle(
                  fontFamily: 'TiroDevanagariMarathi',
                  fontSize: 24,
                  color: MMColors.ink,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '"Should I sell today?"',
                style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: MMColors.inkSoft),
              ),
              const SizedBox(height: 48),
              _MicButton(
                stage: _stage,
                pulse: _pulse,
                onTap: _stage == _Stage.idle ? _startListening : null,
              ),
              const SizedBox(height: 40),
              _TranscriptBox(stage: _stage, transcript: _transcript),
            ],
          ),
        ),
      ),
    );
  }
}

class _MicButton extends StatelessWidget {
  final _Stage stage;
  final AnimationController pulse;
  final VoidCallback? onTap;

  const _MicButton({required this.stage, required this.pulse, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 200,
        height: 200,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (stage == _Stage.listening) ...[
              _pulseRing(0),
              _pulseRing(0.4),
            ],
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  center: Alignment(-0.3, -0.4),
                  radius: 1.1,
                  colors: [Color(0xFFD95F28), MMColors.terracotta, MMColors.terracottaDk],
                ),
                boxShadow: [
                  BoxShadow(
                    color: MMColors.terracottaDk.withOpacity(0.35),
                    blurRadius: 24, offset: const Offset(0, 12),
                  )
                ],
              ),
              child: Icon(
                stage == _Stage.thinking ? Icons.auto_awesome : Icons.mic,
                color: Colors.white,
                size: 56,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pulseRing(double delay) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final t = ((pulse.value + delay) % 1.0);
        return Container(
          width: 160 + t * 80,
          height: 160 + t * 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: MMColors.terracotta.withOpacity(1 - t),
              width: 3,
            ),
          ),
        );
      },
    );
  }
}

class _TranscriptBox extends StatelessWidget {
  final _Stage stage;
  final String transcript;

  const _TranscriptBox({required this.stage, required this.transcript});

  @override
  Widget build(BuildContext context) {
    late final Widget body;
    switch (stage) {
      case _Stage.idle:
        body = const Text(
          'तुमचा प्रश्न इथे दिसेल',
          style: TextStyle(
            fontFamily: 'TiroDevanagariMarathi',
            fontSize: 16,
            color: MMColors.inkSoft,
          ),
        );
      case _Stage.listening:
        body = const Text(
          'ऐकत आहे...',
          style: TextStyle(
            fontFamily: 'TiroDevanagariMarathi',
            fontSize: 18,
            color: MMColors.terracotta,
          ),
        );
      case _Stage.thinking:
        body = Column(
          children: [
            Text(
              transcript.isEmpty ? '...' : '"$transcript"',
              style: const TextStyle(
                fontFamily: 'TiroDevanagariMarathi',
                fontSize: 20,
                color: MMColors.ink,
              ),
            ),
            const SizedBox(height: 12),
            const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: MMColors.turmeric),
            ),
            const SizedBox(height: 8),
            Text(
              'Gemma 4 is reasoning · offline',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MMColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MMColors.line, style: BorderStyle.solid),
      ),
      child: Center(child: body),
    );
  }
}
