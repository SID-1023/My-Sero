import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  /// Sign up a new user on Back4app
  Future<ParseResponse> signUp(
    String username,
    String password,
    String email,
  ) async {
    final user = ParseUser(username, password, email);

    // Default metadata for a new Sero user
    user.set('role', 'user');
    user.set('accentColor', '0xFF00FF11'); // Default Sero Green

    final ParseResponse response = await user.signUp();

    if (response.success) {
      debugPrint("New Identity Created: $username");
    }
    return response;
  }

  /// Log in an existing user
  Future<ParseResponse> login(String username, String password) async {
    final user = ParseUser(username, password, null);
    final ParseResponse response = await user.login();

    if (response.success) {
      debugPrint("Sero Initialized for: $username");
    }
    return response;
  }

  /// Log out and clear local session cache completely
  Future<void> logout() async {
    final ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser != null) {
      final response = await currentUser.logout();
      if (response.success) {
        debugPrint("Session Terminated Successfully.");
      }
    }
  }

  /// Verification: Checks if the user is logged in AND if the session is valid on server
  Future<bool> hasUserLoggedIn() async {
    ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
    if (currentUser == null || currentUser.sessionToken == null) {
      return false;
    }

    try {
      // Pings Back4app to ensure the session hasn't been deleted or expired
      final ParseResponse? response = await ParseUser.getCurrentUserFromServer(
        currentUser.sessionToken!,
      );

      if (response != null && response.success) {
        return true;
      } else {
        // Ghost session detected: clear local data
        await currentUser.logout();
        return false;
      }
    } catch (e) {
      // In case of no internet, we allow the cached session to proceed
      debugPrint("Network error during handshake: $e");
      return true;
    }
  }

  /// NEW: Update specific user fields (like Name or Accent Color)
  Future<bool> updateUserProfile({
    String? fullName,
    String? accentColorHex,
  }) async {
    try {
      ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;
      if (currentUser == null) return false;

      if (fullName != null) currentUser.set('username', fullName);
      if (accentColorHex != null)
        currentUser.set('accentColor', accentColorHex);

      final response = await currentUser.save();
      return response.success;
    } catch (e) {
      debugPrint("Failed to sync profile: $e");
      return false;
    }
  }

  /// NEW: Get the current user object with all custom fields
  Future<ParseUser?> getCurrentUser() async {
    return await ParseUser.currentUser() as ParseUser?;
  }
}
