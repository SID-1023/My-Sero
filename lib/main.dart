import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Add this import

import 'features/ui/home_screen.dart';
import 'features/ui/keyboard_input_screen.dart';
import 'features/ui/listening_screen.dart';
import 'features/voice/voice_input.dart';
import 'features/chat/chat_provider.dart';

// Update main to be Future and async
Future<void> main() async {
  // Required for loading assets before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // Load the .env file containing your GEMINI_API_KEY
  await dotenv.load(fileName: ".env");

  runApp(const AssistantApp());
}

class AssistantApp extends StatelessWidget {
  const AssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ChatProvider handles the AI logic
        ChangeNotifierProvider(create: (_) => ChatProvider()..init()),

        // VoiceInputProvider depends on ChatProvider to send text
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
          // Clean UI: removes gray boxes when tapping buttons
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          // Custom color scheme for Sero (optional)
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFFB11226),
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
