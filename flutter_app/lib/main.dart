import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/forecast_service.dart';
import 'services/gemma_service.dart';
import 'services/voice_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  // Bootstrap core services. All initialize synchronously so the home screen
  // can show data immediately; Gemma warmup happens in the background.
  final forecastService = ForecastService();
  await forecastService.load();

  final voiceService = VoiceService();
  await voiceService.initialize();

  final gemmaService = GemmaService(forecastService: forecastService);
  // Warm up the model in the background — first inference is expensive.
  // On a mid-range Android this takes ~3s.
  unawaited(gemmaService.warmup());

  runApp(
    MultiProvider(
      providers: [
        Provider<ForecastService>.value(value: forecastService),
        Provider<VoiceService>.value(value: voiceService),
        Provider<GemmaService>.value(value: gemmaService),
      ],
      child: const MandiMateApp(),
    ),
  );
}

void unawaited(Future<void> f) {}

class MandiMateApp extends StatelessWidget {
  const MandiMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mandi Mate',
      theme: mandiMateTheme,
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
