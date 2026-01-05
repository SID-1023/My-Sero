import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

// UI Imports
import 'package:sero/features/ui/home_screen.dart';
import 'package:sero/features/ui/keyboard_input_screen.dart';
import 'package:sero/features/ui/listening_screen.dart';
import 'package:sero/features/ui/settings_screen.dart';
import 'package:sero/features/chat/chat_list_screen.dart';
import 'package:sero/features/chat/chat_screen.dart';

// Auth Imports
import 'package:sero/features/auth/login_page.dart';
import 'package:sero/features/auth/register_page.dart';

// Provider Imports
import 'package:sero/features/voice/voice_input.dart';
import 'package:sero/features/chat/chat_provider.dart';

Future<void> main() async {
  // 1. MUST BE FIRST: Required for async calls before runApp
  WidgetsFlutterBinding.ensureInitialized();

  // 2. LOAD ENV: Required for Gemini API keys
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("Sero: Neural Memory established (.env loaded).");
  } catch (e) {
    debugPrint("CRITICAL ERROR: .env file missing. $e");
  }

  // 3. Initialize Back4app (The Neural Link)
  const keyApplicationId = 'BH1Jev9ExtOqH50y4IpPARsSjICRxPWy6JBmQwuR';
  const keyClientKey = '2KbzQTIj0lEsZCx1vTxY6oYmZxokt3o1r0oBAPds';
  const keyParseServerUrl = 'https://parseapi.back4app.com';

  await Parse().initialize(
    keyApplicationId,
    keyParseServerUrl,
    clientKey: keyClientKey,
    autoSendSessionId: true,
    debug: true,
  );

  // 4. Session Verification & Pre-Sync
  bool loggedInStatus = false;
  final ChatProvider initialChatProvider = ChatProvider();

  try {
    final ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null && currentUser.sessionToken != null) {
      final ParseResponse? response = await ParseUser.getCurrentUserFromServer(
        currentUser.sessionToken!,
      );

      loggedInStatus = response?.success ?? false;

      if (loggedInStatus) {
        // Pull cloud data into memory before the first screen appears
        await initialChatProvider.loadChatHistory();
        debugPrint("Sero: Cloud history synchronized.");
      } else {
        await currentUser.logout();
      }
    }
  } catch (e) {
    debugPrint("Session Verification Error: $e");
    loggedInStatus = false;
  }

  // 5. Start Multi-Provider Engine
  runApp(
    MultiProvider(
      providers: [
        // AI & History: ..init() wakes up the Gemini GenerativeModel
        ChangeNotifierProvider.value(value: initialChatProvider..init()),

        // Voice & Input: Proxy allows voice commands to access chat history/sessions
        ChangeNotifierProxyProvider<ChatProvider, VoiceInputProvider>(
          create: (context) => VoiceInputProvider(
            chatProvider: Provider.of<ChatProvider>(context, listen: false),
          )..initSpeech(),
          update: (context, chat, voice) {
            return voice!..updateChatProvider(chat);
          },
        ),
      ],
      child: AssistantApp(isLoggedIn: loggedInStatus),
    ),
  );
}

class AssistantApp extends StatelessWidget {
  final bool isLoggedIn;
  const AssistantApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    // Nested Consumers allow the entire app to react to voice (Emotion)
    // and data syncing (Loading state) simultaneously.
    return Consumer<VoiceInputProvider>(
      builder: (context, voiceProvider, _) {
        return Consumer<ChatProvider>(
          builder: (context, chatProvider, _) {
            return MaterialApp(
              title: 'Sero AI',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                brightness: Brightness.dark,
                fontFamily: 'Inter',
                scaffoldBackgroundColor: const Color(0xFF0B0B0F),
                colorScheme: ColorScheme.dark(
                  // Sero's primary color changes based on AI emotion
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
              initialRoute: isLoggedIn ? '/' : '/login',
              routes: {
                '/': (_) => const HomeScreen(),
                '/login': (_) => const SeroLoginPage(),
                '/register': (_) => const SeroRegisterPage(),
                '/keyboard': (_) => const KeyboardInputScreen(),
                '/listening': (_) => const ListeningScreen(),
                '/settings': (_) => const SettingsScreen(),
                '/chat_list': (_) => const ChatListScreen(),
                '/chat_view': (_) => const ChatScreen(),
              },
              // Global Overlay: Shows a blur and spinner when Sero is syncing with Cloud
              builder: (context, child) {
                return Stack(
                  children: [
                    child!,
                    if (chatProvider.isLoading)
                      Container(
                        color: Colors.black.withOpacity(0.7),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF1AFF6B),
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
