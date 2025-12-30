import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/ui/home_screen.dart';
import 'features/ui/keyboard_input_screen.dart';
import 'features/ui/listening_screen.dart';
import 'features/voice/voice_input.dart'; // Ensure this points to your VoiceInputProvider
import 'features/chat/chat_provider.dart';

Future<void> main() async {
  // Required for loading assets/plugins before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file with a safety check
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint(
      "Warning: Could not load .env file. AI features may require an API key.",
    );
  }

  runApp(const AssistantApp());
}

class AssistantApp extends StatelessWidget {
  const AssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 1. ChatProvider: Handles the message history and AI logic
        ChangeNotifierProvider(create: (_) => ChatProvider()..init()),

        // 2. VoiceInputProvider: Linked to ChatProvider for command processing
        // Using ProxyProvider ensures that if ChatProvider updates, VoiceInput stays in sync
        ChangeNotifierProxyProvider<ChatProvider, VoiceInputProvider>(
          create: (context) => VoiceInputProvider(
            chatProvider: Provider.of<ChatProvider>(context, listen: false),
          )..initSpeech(),
          update: (context, chat, voice) => voice!,
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
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFB11226),
            secondary: Color(0xFF1AFF6B), // Added accent color for Calm state
            surface: Color(0xFF121212),
          ),
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
