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

  // 2. LOAD ENV FIRST: Critical to prevent 'NotInitializedError'
  // We wrap this in a try-catch to ensure the app doesn't crash on boot
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("Sero: Neural Memory established (.env loaded).");
  } catch (e) {
    debugPrint(
      "CRITICAL ERROR: Could not load .env file. Verify its location in root. $e",
    );
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

  // 4. Session Check & Data Warm-up
  bool loggedInStatus = false;

  // We initialize the provider instance here so we can pre-load data
  final ChatProvider initialChatProvider = ChatProvider();

  try {
    final ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null && currentUser.sessionToken != null) {
      final ParseResponse? response = await ParseUser.getCurrentUserFromServer(
        currentUser.sessionToken!,
      );

      loggedInStatus = response?.success ?? false;

      if (loggedInStatus) {
        // PRE-FETCH: Sync chat history from Back4app cloud before UI builds
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

  // 5. Run the Multi-Provider Engine
  runApp(
    MultiProvider(
      providers: [
        // Initialize Gemini AI and Chat Logic
        ChangeNotifierProvider.value(value: initialChatProvider..init()),
        // Bridge Chat and Voice providers via Proxy
        ChangeNotifierProxyProvider<ChatProvider, VoiceInputProvider>(
          create: (context) => VoiceInputProvider(
            chatProvider: Provider.of<ChatProvider>(context, listen: false),
          )..initSpeech(), // Wake up the microphone
          update: (context, chat, voice) {
            // Ensure VoiceInputProvider always has the latest ChatProvider state
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
              // The primary theme color now reacts to Sero's emotion
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
          // Route logic: Send user to Home if session exists, else Login
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
