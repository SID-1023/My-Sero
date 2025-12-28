import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'features/ui/home_screen.dart';
import 'features/ui/keyboard_input_screen.dart';
import 'features/ui/listening_screen.dart';
import 'features/voice/voice_input.dart';
import 'features/chat/chat_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AssistantApp());
}

class AssistantApp extends StatelessWidget {
  const AssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider()..init()),
        ChangeNotifierProvider(
          create: (context) =>
              VoiceInputProvider(chatProvider: context.read<ChatProvider>())
                ..initSpeech(),
        ),
      ],
      child: MaterialApp(
        title: 'Sero',
        debugShowCheckedModeBanner: false,

        /* ================= THEME ================= */
        theme: ThemeData(
          brightness: Brightness.dark,
          fontFamily: 'Inter',
          scaffoldBackgroundColor: const Color(0xFF080101),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),

        /* ================= ROUTES ================= */
        initialRoute: '/',
        routes: {
          '/': (_) => const HomeScreen(),
          '/keyboard': (_) => const KeyboardInputScreen(),
          '/listening': (_) => const ListeningScreen(),
        },
      ),
    );
  }
}
