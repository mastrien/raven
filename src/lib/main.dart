library raven_app;

import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'splash_screen.dart';

part 'app/app.dart';
part 'core/enums.dart';
part 'core/services/id_validation_services.dart';
part 'core/services/raven_api_client.dart';
part 'core/services/raven_store.dart';
part 'models/account_security_models.dart';
part 'models/chat_models.dart';
part 'screens/auth/auth_screens.dart';
part 'screens/security/lock_screens.dart';
part 'screens/chats/chat_list_screen.dart';
part 'screens/chats/chat_screen.dart';
part 'screens/contacts/contact_screens.dart';
part 'screens/settings/settings_screens.dart';
part 'screens/profile/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RavenApp());
}


