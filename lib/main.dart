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
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Back4app
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

  // 2. Robust Session Check
  bool loggedInStatus = false;
  try {
    final ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null && currentUser.sessionToken != null) {
      // FIX: Added '?' to handle the nullable return type
      final ParseResponse? response = await ParseUser.getCurrentUserFromServer(
        currentUser.sessionToken!,
      );

      // Check if response is not null and successful
      loggedInStatus = response?.success ?? false;

      if (!loggedInStatus) {
        await currentUser.logout();
      }
    }
  } catch (e) {
    debugPrint("Session Verification Error: $e");
    loggedInStatus = false;
  }

  // 3. Load Env for AI features
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("Warning: Could not load .env file.");
  }

  runApp(
    MultiProvider(
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
      child: AssistantApp(isLoggedIn: loggedInStatus),
    ),
  );
}

class AssistantApp extends StatelessWidget {
  final bool isLoggedIn;
  const AssistantApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return Consumer<VoiceInputProvider>(
      builder: (context, voiceProvider, _) {
        return MaterialApp(
          title: 'Sero AI',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            fontFamily: 'Inter',
            scaffoldBackgroundColor: const Color(0xFF0B0B0F),
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
        );
      },
    );
  }
}
