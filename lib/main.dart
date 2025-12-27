import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/ui/home_screen.dart';
import 'features/voice/voice_input.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AssistantApp());
}

class AssistantApp extends StatelessWidget {
  const AssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<VoiceInputProvider>(
      create: (_) => VoiceInputProvider()..initSpeech(),
      child: MaterialApp(
        title: 'Sero',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Inter',
          scaffoldBackgroundColor: const Color(0xFF080101),
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
