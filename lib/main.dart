import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// UI Imports - Fixed Paths (Assuming files are in lib/features/...)
import 'package:sero/features/ui/home_screen.dart';
import 'package:sero/features/ui/keyboard_input_screen.dart';
import 'package:sero/features/ui/listening_screen.dart';
import 'package:sero/features/ui/settings_screen.dart';

// Chat UI Imports - Removed 'ui/' if files are in lib/features/chat/
import 'package:sero/features/chat/chat_list_screen.dart';
import 'package:sero/features/chat/chat_screen.dart';

// Provider Imports
import 'package:sero/features/voice/voice_input.dart';
import 'package:sero/features/chat/chat_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
        ChangeNotifierProvider(create: (_) => ChatProvider()..init()),
        ChangeNotifierProxyProvider<ChatProvider, VoiceInputProvider>(
          create: (context) => VoiceInputProvider(
            chatProvider: Provider.of<ChatProvider>(context, listen: false),
          )..initSpeech(),
          update: (context, chat, voice) {
            return voice!..updateChatProvider(chat);
          },
        ),
      ],
      child: Consumer<VoiceInputProvider>(
        builder: (context, voiceProvider, _) {
          return MaterialApp(
            title: 'Sero AI',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              fontFamily: 'Inter',
              scaffoldBackgroundColor: const Color(0xFF080101),
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              colorScheme: ColorScheme.dark(
                primary: voiceProvider.emotionColor,
                secondary: const Color(0xFF1AFF6B),
                surface: const Color(0xFF121212),
              ),
              textTheme: const TextTheme(
                headlineMedium: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFFB3B3),
                ),
              ),
            ),
            initialRoute: '/',
            routes: {
              '/': (_) => const HomeScreen(),
              '/keyboard': (_) => const KeyboardInputScreen(),
              '/listening': (_) => const ListeningScreen(),
              '/settings': (_) => const SettingsScreen(),
              '/chat_list': (_) => const ChatListScreen(),
              '/chat_view': (_) => const ChatScreen(),
            },
          );
        },
      ),
    );
  }
}
