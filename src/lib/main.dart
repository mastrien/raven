import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RavenApp());
}


void navigateAfterTap(BuildContext context, VoidCallback navigation) {
  Future<void>.delayed(Duration.zero, () {
    if (!context.mounted) return;
    navigation();
  });
}

class RavenApp extends StatefulWidget {
  const RavenApp({super.key});

  static const Color ravenBlue = Color(0xFF3D438F);
  static const Color ravenDark = Color(0xFF121426);
  static const Color pageBg = Color(0xFFF7F7FB);

  @override
  State<RavenApp> createState() => _RavenAppState();
}

class _RavenAppState extends State<RavenApp> {
  final RavenStore _store = RavenStore();

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return RavenScope(
      store: _store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Raven',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: RavenApp.ravenBlue,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: RavenApp.pageBg,
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            margin: EdgeInsets.zero,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: RavenApp.pageBg,
            foregroundColor: RavenApp.ravenDark,
            centerTitle: false,
            elevation: 0,
            titleTextStyle: TextStyle(
              color: RavenApp.ravenDark,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/gate': (context) => const AuthGateScreen(),
          '/login': (context) => const LoginScreen(),
          '/lock': (context) => const LockScreen(),
        },
      ),
    );
  }
}

class RavenScope extends InheritedNotifier<RavenStore> {
  const RavenScope({
    super.key,
    required this.store,
    required super.child,
  }) : super(notifier: store);

  final RavenStore store;

  static RavenStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RavenScope>();
    assert(scope != null, 'RavenScope was not found in the widget tree.');
    return scope!.store;
  }
}

enum VaultMode { real, decoy }

enum MessageDeliveryStatus { local, pending, sent, delivered }

extension MessageDeliveryStatusView on MessageDeliveryStatus {
  String get storageValue {
    switch (this) {
      case MessageDeliveryStatus.pending:
        return 'pending';
      case MessageDeliveryStatus.sent:
        return 'sent';
      case MessageDeliveryStatus.delivered:
        return 'delivered';
      case MessageDeliveryStatus.local:
        return 'local';
    }
  }

  String get label {
    switch (this) {
      case MessageDeliveryStatus.pending:
        return 'pending';
      case MessageDeliveryStatus.sent:
        return 'sent';
      case MessageDeliveryStatus.delivered:
        return 'delivered';
      case MessageDeliveryStatus.local:
        return 'local';
    }
  }

  IconData get icon {
    switch (this) {
      case MessageDeliveryStatus.pending:
        return Icons.schedule_rounded;
      case MessageDeliveryStatus.sent:
        return Icons.done_rounded;
      case MessageDeliveryStatus.delivered:
        return Icons.done_all_rounded;
      case MessageDeliveryStatus.local:
        return Icons.save_rounded;
    }
  }

}

MessageDeliveryStatus messageDeliveryStatusFromStorage(String? value) {
  switch (value) {
    case 'pending':
      return MessageDeliveryStatus.pending;
    case 'sent':
      return MessageDeliveryStatus.sent;
    case 'delivered':
      return MessageDeliveryStatus.delivered;
    case 'local':
    default:
      return MessageDeliveryStatus.local;
  }
}

class RavenIdService {
  static String _slug(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'user' : slug;
  }

  static String createFromName(String name) {
    final random = Random.secure().nextInt(0xFFFFF).toRadixString(16).toUpperCase().padLeft(5, '0');
    return 'rvn_${_slug(name)}_$random';
  }

  static String stableFromName(String name) {
    final base = _slug(name);
    final checksum = name.codeUnits.fold<int>(17, (sum, value) => (sum * 31 + value) & 0xFFFFF);
    return 'rvn_${base}_${checksum.toRadixString(16).toUpperCase().padLeft(5, '0')}';
  }

  static String normalizeOrCreate(String value, String fallbackName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return createFromName(fallbackName);
    final clean = trimmed.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    return clean.startsWith('rvn_') ? clean : 'rvn_$clean';
  }
}


class RavenValidation {
  static final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp ravenIdPattern = RegExp(r'^rvn_[a-zA-Z0-9_-]{3,44}$');

  static bool isValidEmail(String value) {
    final clean = value.trim();
    return clean.isNotEmpty && clean.length <= 254 && emailPattern.hasMatch(clean);
  }

  static String? ravenIdError(String value, {String? ownRavenId}) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Enter a Raven ID.';
    if (clean.length > 48) return 'Raven ID is too long.';
    if (!ravenIdPattern.hasMatch(clean)) {
      return 'Invalid Raven ID. Use a format like rvn_name_8F3A2.';
    }
    if (ownRavenId != null && clean.toLowerCase() == ownRavenId.toLowerCase()) {
      return 'You cannot start a chat with yourself.';
    }
    return null;
  }

  static String? groupNameError(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Group name is required.';
    if (clean.length > 40) return 'Group name must be at most 40 characters.';
    return null;
  }

  static String? displayNameError(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Display name is required.';
    if (clean.length < 2) return 'Display name must have at least 2 characters.';
    if (clean.length > 40) return 'Display name must be at most 40 characters.';
    return null;
  }
}

class MessageSyncService {
  const MessageSyncService();

  Future<void> simulateOutgoingStatusFlow(Future<void> Function(MessageDeliveryStatus status) onStatus) async {
    await Future.delayed(const Duration(milliseconds: 650));
    await onStatus(MessageDeliveryStatus.sent);
    await Future.delayed(const Duration(milliseconds: 900));
    await onStatus(MessageDeliveryStatus.delivered);
  }
}

enum AuthOutcomeType { real, decoy, emergency, invalid, realLocked }

class AuthOutcome {
  const AuthOutcome(this.type, {this.mode});

  final AuthOutcomeType type;
  final VaultMode? mode;
}

class RavenStore extends ChangeNotifier {
  static const String _storageKey = 'raven_local_secure_state_v5';
  static const String _legacyStorageKey = 'raven_local_mvp_state_v2';
  static const String _accountStorageKey = 'raven_account_state_v1';
  static const String _securitySettingsKey = 'raven_security_settings_v1';
  static const String _pinAttemptsKey = 'raven_pin_attempts_v1';

  final AesGcm _aesGcm = AesGcm.with256bits();
  final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 100000,
    bits: 256,
  );
  final MessageSyncService _messageSyncService = const MessageSyncService();

  SharedPreferences? _prefs;
  RavenPersistentState? _persistent;
  RavenAccountState? _account;
  RavenSecuritySettings _settings = const RavenSecuritySettings();
  PinAttemptState _pinAttempts = const PinAttemptState();
  bool _loaded = false;

  final Map<VaultMode, VaultData> _unlockedVaults = {};
  final Map<VaultMode, List<int>> _vaultKeys = {};
  final Map<VaultMode, String> _sessionPins = {};

  bool get loaded => _loaded;
  bool get hasAccount => _account?.created == true;
  bool get appLockEnabled => _settings.appLockEnabled;
  String get accountEmail => _account?.email ?? '';
  String get accountDisplayName => _account?.displayName ?? 'Raven user';
  bool get pinRecoveryEnabled => _settings.pinRecoveryEnabled;
  bool get showOnlineStatus => _settings.showOnlineStatus;
  bool get readReceiptsEnabled => _settings.readReceiptsEnabled;
  bool get hideMessagePreviews => _settings.hideMessagePreviews;
  String get groupAddPolicy => _settings.groupAddPolicy;
  bool get emergencyLocked => _persistent?.emergencyLocked ?? false;
  int get failedPinAttempts => _pinAttempts.failedAttempts;
  Duration get pinCooldownRemaining => _pinAttempts.remaining;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs!.getString(_storageKey);

    if (raw != null && raw.isNotEmpty) {
      try {
        _persistent = RavenPersistentState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        _persistent = await _createInitialPersistentState();
        await _savePersistent();
      }
    } else {
      final legacyRaw = _prefs!.getString(_legacyStorageKey);
      if (legacyRaw != null && legacyRaw.isNotEmpty) {
        try {
          _persistent = await _migrateLegacyState(jsonDecode(legacyRaw) as Map<String, dynamic>);
          await _savePersistent();
        } catch (_) {
          _persistent = await _createInitialPersistentState();
          await _savePersistent();
        }
      } else {
        _persistent = await _createInitialPersistentState();
        await _savePersistent();
      }
    }

    final accountRaw = _prefs!.getString(_accountStorageKey);
    if (accountRaw != null && accountRaw.isNotEmpty) {
      try {
        _account = RavenAccountState.fromJson(jsonDecode(accountRaw) as Map<String, dynamic>);
      } catch (_) {
        _account = null;
      }
    }

    final settingsRaw = _prefs!.getString(_securitySettingsKey);
    if (settingsRaw != null && settingsRaw.isNotEmpty) {
      try {
        _settings = RavenSecuritySettings.fromJson(jsonDecode(settingsRaw) as Map<String, dynamic>);
      } catch (_) {
        _settings = const RavenSecuritySettings();
      }
    }

    final attemptsRaw = _prefs!.getString(_pinAttemptsKey);
    if (attemptsRaw != null && attemptsRaw.isNotEmpty) {
      try {
        _pinAttempts = PinAttemptState.fromJson(jsonDecode(attemptsRaw) as Map<String, dynamic>);
      } catch (_) {
        _pinAttempts = const PinAttemptState();
      }
    }

    _loaded = true;
    notifyListeners();
  }

  VaultData vaultFor(VaultMode mode) {
    final unlocked = _unlockedVaults[mode];
    if (unlocked != null) return unlocked;
    return mode == VaultMode.real ? RavenDefaults.realVault() : RavenDefaults.decoyVault();
  }

  Future<String?> registerAccount({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName.trim();
    final nameError = RavenValidation.displayNameError(cleanName);
    if (nameError != null) return nameError;
    if (!RavenValidation.isValidEmail(cleanEmail)) return 'Enter a valid email address.';
    if (password.isEmpty) return 'Account password is required.';
    if (password.length < 8) return 'Use at least 8 characters for the account password.';
    if (password.length > 128) return 'Account password must be at most 128 characters.';
    if (_account != null && _account!.created && _account!.email.toLowerCase() == cleanEmail) {
      return 'This email is already in use.';
    }

    _account = RavenAccountState(
      created: true,
      email: cleanEmail,
      displayName: cleanName,
      passwordVerifier: await PinVerifier.create(password, _deriveKeyBytes),
      emailVerified: true,
    );
    await _saveAccount();
    await openDefaultSession();
    notifyListeners();
    return null;
  }

  Future<String?> loginAccount({required String email, required String password}) async {
    final account = _account;
    final cleanEmail = email.trim().toLowerCase();
    if (!RavenValidation.isValidEmail(cleanEmail)) return 'Enter a valid email address.';
    if (password.isEmpty) return 'Account password is required.';
    if (password.length > 128) return 'Account password must be at most 128 characters.';
    if (account == null || !account.created) return 'Invalid email or password.';
    if (cleanEmail != account.email.toLowerCase()) return 'Invalid email or password.';
    final ok = await account.passwordVerifier.verify(password, _deriveKeyBytes);
    if (!ok) return 'Invalid email or password.';
    if (!_settings.appLockEnabled) {
      await openDefaultSession();
    }
    notifyListeners();
    return null;
  }

  Future<void> openDefaultSession() async {
    final persistent = _persistent;
    if (persistent == null) return;
    try {
      await _unlockVaultWithKeyWrap(
        mode: VaultMode.real,
        vaultBox: persistent.realVault,
        keyWrap: persistent.realKeyWrap,
        pin: _settings.autoRealPin,
      );
      _sessionPins[VaultMode.real] = _settings.autoRealPin;
      if (_settings.autoDecoyPin.isNotEmpty) {
        await _unlockVaultWithKeyWrap(
          mode: VaultMode.decoy,
          vaultBox: persistent.decoyVault,
          keyWrap: persistent.decoyKeyWrap,
          pin: _settings.autoDecoyPin,
        );
        _sessionPins[VaultMode.decoy] = _settings.autoDecoyPin;
      }
    } catch (_) {
      // If a previous local state cannot be opened, keep the safe visual defaults.
    }
  }

  Future<void> logoutAccount() async {
    lockSession();
  }

  Future<String?> configureAppLock({
    required bool enabled,
    required String realPin,
    required String decoyPin,
    required String emergencyPin,
  }) async {
    if (!enabled) {
      _settings = _settings.copyWith(appLockEnabled: false);
      await _saveSettings();
      notifyListeners();
      return null;
    }

    final pinError = validateAccessPinSet(
      realPin: realPin,
      decoyPin: decoyPin,
      emergencyPin: emergencyPin,
    );
    if (pinError != null) return pinError;

    final persistent = _persistent;
    if (persistent == null) return 'Local state is not ready yet.';

    try {
      final realKey = _vaultKeys[VaultMode.real] ?? await _decryptBytesWithPin(persistent.realKeyWrap, _settings.autoRealPin);
      final decoyKey = _vaultKeys[VaultMode.decoy] ?? await _decryptBytesWithPin(persistent.decoyKeyWrap, _settings.autoDecoyPin);

      _persistent = persistent.copyWith(
        credentials: await PinCredentials.create(
          realPin: realPin,
          decoyPin: decoyPin,
          emergencyPin: emergencyPin,
          deriveKeyBytes: _deriveKeyBytes,
        ),
        realKeyWrap: await _encryptBytesWithPin(realKey, realPin),
        decoyKeyWrap: await _encryptBytesWithPin(decoyKey, decoyPin),
        emergencyDecoyKeyWrap: await _encryptBytesWithPin(decoyKey, emergencyPin),
      );
      _settings = _settings.copyWith(
        appLockEnabled: true,
        autoRealPin: realPin,
        autoDecoyPin: decoyPin,
        autoEmergencyPin: emergencyPin,
      );
      _vaultKeys[VaultMode.real] = realKey;
      _vaultKeys[VaultMode.decoy] = decoyKey;
      await _savePersistent();
      await _saveSettings();
      await resetPinAttempts();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not configure the local lock.';
    }
  }

  Future<void> recordFailedPinAttempt() async {
    final next = _pinAttempts.failedAttempts + 1;
    final cooldown = _cooldownForAttempt(next);
    _pinAttempts = PinAttemptState(
      failedAttempts: next,
      cooldownUntil: cooldown == Duration.zero ? null : DateTime.now().add(cooldown),
    );
    await _savePinAttempts();
    notifyListeners();
  }

  Future<void> resetPinAttempts() async {
    _pinAttempts = const PinAttemptState();
    await _savePinAttempts();
    notifyListeners();
  }


  Future<void> updateSecuritySettings({
    bool? pinRecoveryEnabled,
    bool? showOnlineStatus,
    bool? readReceiptsEnabled,
    bool? hideMessagePreviews,
    String? groupAddPolicy,
  }) async {
    _settings = _settings.copyWith(
      pinRecoveryEnabled: pinRecoveryEnabled,
      showOnlineStatus: showOnlineStatus,
      readReceiptsEnabled: readReceiptsEnabled,
      hideMessagePreviews: hideMessagePreviews,
      groupAddPolicy: groupAddPolicy,
    );
    await _saveSettings();
    notifyListeners();
  }

  Future<String?> updateAccountEmail(String newEmail) async {
    final account = _account;
    final cleanEmail = newEmail.trim().toLowerCase();
    if (account == null || !account.created) return 'No local account is available.';
    if (!RavenValidation.isValidEmail(cleanEmail)) return 'Enter a valid email address.';
    if (cleanEmail == account.email.toLowerCase()) return 'This is already the current email.';
    _account = account.copyWith(email: cleanEmail);
    await _saveAccount();
    notifyListeners();
    return null;
  }

  Future<void> deleteAllChatsAndGroups(VaultMode mode) async {
    final currentVault = vaultFor(mode);
    await _replaceVault(mode, currentVault.copyWith(conversations: []));
    notifyListeners();
  }

  Duration _cooldownForAttempt(int attempt) {
    if (attempt < 5) return Duration.zero;
    if (attempt == 5) return const Duration(seconds: 30);
    if (attempt == 6) return const Duration(minutes: 1);
    if (attempt == 7) return const Duration(minutes: 5);
    if (attempt == 8) return const Duration(minutes: 15);
    return const Duration(minutes: 30);
  }

  String? validateAccessPinSet({
    required String realPin,
    required String decoyPin,
    required String emergencyPin,
  }) {
    final pins = [realPin, decoyPin, emergencyPin];
    if (!pins.every((value) => RegExp(r'^\d{6}$').hasMatch(value))) {
      return 'Use exactly 6 digits for each PIN.';
    }
    if (pins.toSet().length != pins.length) {
      return 'Main, cover and emergency PINs must be different.';
    }
    for (final pin in pins) {
      final issue = _pinStrengthIssue(pin);
      if (issue != null) return issue;
    }
    return null;
  }

  String? _pinStrengthIssue(String pin) {
    if (RegExp(r'^(\d)\1{5}$').hasMatch(pin)) {
      return 'Avoid repeated PINs such as 111111.';
    }
    const ascending = '0123456789';
    const descending = '9876543210';
    if (ascending.contains(pin) || descending.contains(pin)) {
      return 'Avoid sequential PINs such as 123456 or 654321.';
    }
    final commonPins = {'000000', '111111', '123456', '654321', '121212', '112233'};
    if (commonPins.contains(pin)) {
      return 'Choose less obvious 6-digit PINs for the final setup.';
    }
    return null;
  }

  ConversationData? conversationById(VaultMode mode, String id) {
    final conversations = vaultFor(mode).conversations;
    for (final conversation in conversations) {
      if (conversation.id == id) return conversation;
    }
    return null;
  }

  Future<AuthOutcome> unlockPin(String pin) async {
    final persistent = _persistent;
    if (!_loaded || persistent == null) return const AuthOutcome(AuthOutcomeType.invalid);

    if (await persistent.credentials.emergency.verify(pin, _deriveKeyBytes)) {
      try {
        await _unlockVaultWithKeyWrap(
          mode: VaultMode.decoy,
          vaultBox: persistent.decoyVault,
          keyWrap: persistent.emergencyDecoyKeyWrap,
          pin: pin,
        );
        _persistent = persistent.copyWith(emergencyLocked: true);
        await _savePersistent();
        notifyListeners();
        return const AuthOutcome(AuthOutcomeType.emergency, mode: VaultMode.decoy);
      } catch (_) {
        return const AuthOutcome(AuthOutcomeType.invalid);
      }
    }

    if (await persistent.credentials.real.verify(pin, _deriveKeyBytes)) {
      if (persistent.emergencyLocked) {
        return const AuthOutcome(AuthOutcomeType.realLocked, mode: VaultMode.decoy);
      }

      try {
        await _unlockVaultWithKeyWrap(
          mode: VaultMode.real,
          vaultBox: persistent.realVault,
          keyWrap: persistent.realKeyWrap,
          pin: pin,
        );
        _sessionPins[VaultMode.real] = pin;
        return const AuthOutcome(AuthOutcomeType.real, mode: VaultMode.real);
      } catch (_) {
        return const AuthOutcome(AuthOutcomeType.invalid);
      }
    }

    if (await persistent.credentials.decoy.verify(pin, _deriveKeyBytes)) {
      try {
        await _unlockVaultWithKeyWrap(
          mode: VaultMode.decoy,
          vaultBox: persistent.decoyVault,
          keyWrap: persistent.decoyKeyWrap,
          pin: pin,
        );
        _sessionPins[VaultMode.decoy] = pin;
        return const AuthOutcome(AuthOutcomeType.decoy, mode: VaultMode.decoy);
      } catch (_) {
        return const AuthOutcome(AuthOutcomeType.invalid);
      }
    }

    return const AuthOutcome(AuthOutcomeType.invalid);
  }

  Future<String?> updatePins({
    required String currentRealPin,
    required String currentDecoyPin,
    required String currentEmergencyPin,
    required String newRealPin,
    required String newDecoyPin,
    required String newEmergencyPin,
  }) async {
    final persistent = _persistent;
    if (persistent == null) return 'Local state is not ready yet.';

    final currentPins = [currentRealPin, currentDecoyPin, currentEmergencyPin];
    final newPins = [newRealPin, newDecoyPin, newEmergencyPin];

    final currentValid = currentPins.every((value) => RegExp(r'^\d{6}$').hasMatch(value));
    if (!currentValid) return 'Use exactly 6 digits in every current PIN field.';

    final newPinError = validateAccessPinSet(
      realPin: newRealPin,
      decoyPin: newDecoyPin,
      emergencyPin: newEmergencyPin,
    );
    if (newPinError != null) return newPinError;

    final credentialsOk = await persistent.credentials.verifyAll(
      realPin: currentRealPin,
      decoyPin: currentDecoyPin,
      emergencyPin: currentEmergencyPin,
      deriveKeyBytes: _deriveKeyBytes,
    );

    if (!credentialsOk) {
      return 'One or more current PINs are incorrect.';
    }

    try {
      final realKey = await _decryptBytesWithPin(persistent.realKeyWrap, currentRealPin);
      final decoyKey = await _decryptBytesWithPin(persistent.decoyKeyWrap, currentDecoyPin);

      final updatedPersistent = persistent.copyWith(
        credentials: await PinCredentials.create(
          realPin: newRealPin,
          decoyPin: newDecoyPin,
          emergencyPin: newEmergencyPin,
          deriveKeyBytes: _deriveKeyBytes,
        ),
        realKeyWrap: await _encryptBytesWithPin(realKey, newRealPin),
        decoyKeyWrap: await _encryptBytesWithPin(decoyKey, newDecoyPin),
        emergencyDecoyKeyWrap: await _encryptBytesWithPin(decoyKey, newEmergencyPin),
      );

      _persistent = updatedPersistent;
      if (_vaultKeys.containsKey(VaultMode.real)) {
        _vaultKeys[VaultMode.real] = realKey;
        _sessionPins[VaultMode.real] = newRealPin;
      }
      if (_vaultKeys.containsKey(VaultMode.decoy)) {
        _vaultKeys[VaultMode.decoy] = decoyKey;
        _sessionPins[VaultMode.decoy] = newDecoyPin;
      }
      _settings = _settings.copyWith(
        autoRealPin: newRealPin,
        autoDecoyPin: newDecoyPin,
        autoEmergencyPin: newEmergencyPin,
      );
      await _savePersistent();
      await _saveSettings();
      notifyListeners();
      return null;
    } catch (_) {
      return 'Could not re-encrypt local keys.';
    }
  }

  Future<String?> updateProfile(
    VaultMode mode, {
    required String displayName,
    required String email,
    required String about,
  }) async {
    final trimmedName = displayName.trim();
    final trimmedEmail = email.trim();
    final trimmedAbout = about.trim();

    final nameError = RavenValidation.displayNameError(trimmedName);
    if (nameError != null) return nameError;
    if (!RavenValidation.isValidEmail(trimmedEmail)) return 'Enter a valid email address for the demo.';
    if (trimmedAbout.length > 160) return 'Bio/status must be at most 160 characters.';

    final currentVault = vaultFor(mode);
    await _replaceVault(
      mode,
      currentVault.copyWith(
        displayName: trimmedName,
        email: trimmedEmail,
        about: trimmedAbout.isEmpty ? 'Protected by Raven.' : trimmedAbout,
      ),
    );
    notifyListeners();
    return null;
  }

  Future<void> addContact(
    VaultMode mode, {
    required String name,
    required String handle,
    required String ravenId,
    required String note,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return;

    final cleanHandle = handle.trim().isEmpty
        ? '@${trimmedName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}'
        : handle.trim();
    final cleanRavenId = RavenIdService.normalizeOrCreate(ravenId, trimmedName);

    final contact = ContactData(
      id: _newId('contact'),
      name: trimmedName,
      handle: cleanHandle.startsWith('@') ? cleanHandle : '@$cleanHandle',
      ravenId: cleanRavenId,
      initials: _initialsFromName(trimmedName),
      colorValue: _colorFromName(trimmedName).value,
      note: note.trim(),
    );

    final currentVault = vaultFor(mode);
    final updatedVault = currentVault.copyWith(
      contacts: [contact, ...currentVault.contacts],
    );

    await _replaceVault(mode, updatedVault);
    notifyListeners();
  }

  Future<String> startConversationWithContact(VaultMode mode, ContactData contact) async {
    final currentVault = vaultFor(mode);

    for (final conversation in currentVault.conversations) {
      if (conversation.contactId == contact.id) return conversation.id;
    }

    final conversationId = _newId('conversation');
    final newConversation = ConversationData(
      id: conversationId,
      contactId: contact.id,
      name: contact.name,
      initials: contact.initials,
      colorValue: contact.colorValue,
      unread: false,
      messages: [
        ChatMessageData(
          id: _newId('message'),
          conversationId: conversationId,
          senderId: contact.effectiveRavenId,
          receiverId: currentVault.ravenId,
          text: 'Local chat started from the contact list.',
          mine: false,
          createdAt: DateTime.now(),
          deliveryStatus: MessageDeliveryStatus.local,
        ),
      ],
    );

    final updatedVault = currentVault.copyWith(
      conversations: [newConversation, ...currentVault.conversations],
    );

    await _replaceVault(mode, updatedVault);
    notifyListeners();
    return newConversation.id;
  }

  Future<String?> addConversationWithRavenId(VaultMode mode, String ravenId) async {
    final currentVault = vaultFor(mode);
    final error = RavenValidation.ravenIdError(ravenId, ownRavenId: currentVault.ravenId);
    if (error != null) return error;
    final cleanRavenId = ravenId.trim();

    final duplicate = currentVault.conversations.any(
      (conversation) => !conversation.isGroup && currentVault.contactById(conversation.contactId)?.effectiveRavenId.toLowerCase() == cleanRavenId.toLowerCase(),
    );
    if (duplicate) return 'A chat with this Raven ID already exists.';

    final namePart = cleanRavenId.replaceFirst(RegExp(r'^rvn_'), '').split('_').where((part) => part.isNotEmpty).take(2).join(' ');
    final displayName = namePart.isEmpty ? cleanRavenId : namePart.split(' ').map((part) => part[0].toUpperCase() + part.substring(1)).join(' ');
    final contact = ContactData(
      id: _newId('contact'),
      name: displayName,
      handle: '@${displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
      ravenId: cleanRavenId,
      initials: _initialsFromName(displayName),
      colorValue: _colorFromName(displayName).value,
      note: 'Created from Raven ID.',
    );

    final conversationId = _newId('conversation');
    final newConversation = ConversationData(
      id: conversationId,
      contactId: contact.id,
      name: displayName,
      initials: contact.initials,
      colorValue: contact.colorValue,
      unread: false,
      messages: [
        ChatMessageData(
          id: _newId('message'),
          conversationId: conversationId,
          senderId: cleanRavenId,
          receiverId: currentVault.ravenId,
          text: 'Direct chat created locally. Backend lookup will verify this Raven ID later.',
          mine: false,
          createdAt: DateTime.now(),
          deliveryStatus: MessageDeliveryStatus.local,
        ),
      ],
    );

    await _replaceVault(
      mode,
      currentVault.copyWith(
        contacts: [contact, ...currentVault.contacts],
        conversations: [newConversation, ...currentVault.conversations],
      ),
    );
    notifyListeners();
    return null;
  }

  Future<String?> addGroupConversation(VaultMode mode, String groupName, List<String> memberRavenIds) async {
    final currentVault = vaultFor(mode);
    final groupError = RavenValidation.groupNameError(groupName);
    if (groupError != null) return groupError;
    final uniqueMembers = <String>[];
    for (final rawId in memberRavenIds) {
      final clean = rawId.trim();
      final memberError = RavenValidation.ravenIdError(clean, ownRavenId: currentVault.ravenId);
      if (memberError != null) return memberError;
      if (!uniqueMembers.any((id) => id.toLowerCase() == clean.toLowerCase())) uniqueMembers.add(clean);
    }

    final conversationId = _newId('group');
    final cleanName = groupName.trim();
    final newConversation = ConversationData(
      id: conversationId,
      name: cleanName,
      initials: _initialsFromName(cleanName),
      colorValue: _colorFromName(cleanName).value,
      unread: false,
      isGroup: true,
      memberRavenIds: uniqueMembers,
      owner: true,
      messages: [
        ChatMessageData(
          id: _newId('message'),
          conversationId: conversationId,
          senderId: currentVault.ravenId,
          receiverId: 'group:$conversationId',
          text: uniqueMembers.isEmpty
              ? 'Group created locally with no members yet.'
              : 'Group created locally. Invites will be sent through the backend later.',
          mine: false,
          createdAt: DateTime.now(),
          deliveryStatus: MessageDeliveryStatus.local,
        ),
      ],
    );

    await _replaceVault(mode, currentVault.copyWith(conversations: [newConversation, ...currentVault.conversations]));
    notifyListeners();
    return null;
  }

  Future<String?> addGroupMember(VaultMode mode, String conversationId, String ravenId) async {
    final currentVault = vaultFor(mode);
    final error = RavenValidation.ravenIdError(ravenId, ownRavenId: currentVault.ravenId);
    if (error != null) return error;
    final clean = ravenId.trim();
    final updatedConversations = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      if (conversation.memberRavenIds.any((id) => id.toLowerCase() == clean.toLowerCase())) return conversation;
      return conversation.copyWith(memberRavenIds: [...conversation.memberRavenIds, clean]);
    }).toList();
    await _replaceVault(mode, currentVault.copyWith(conversations: updatedConversations));
    notifyListeners();
    return null;
  }

  Future<void> togglePinnedConversation(VaultMode mode, String conversationId) async {
    final currentVault = vaultFor(mode);
    final updated = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      return conversation.copyWith(pinned: !conversation.pinned);
    }).toList();
    await _replaceVault(mode, currentVault.copyWith(conversations: updated));
    notifyListeners();
  }

  Future<void> clearConversation(VaultMode mode, String conversationId) async {
    final currentVault = vaultFor(mode);
    final updated = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      return conversation.copyWith(messages: []);
    }).toList();
    await _replaceVault(mode, currentVault.copyWith(conversations: updated));
    notifyListeners();
  }

  Future<void> deleteConversation(VaultMode mode, String conversationId) async {
    final currentVault = vaultFor(mode);
    await _replaceVault(mode, currentVault.copyWith(conversations: currentVault.conversations.where((c) => c.id != conversationId).toList()));
    notifyListeners();
  }

  Future<void> blockConversation(VaultMode mode, String conversationId) async {
    final currentVault = vaultFor(mode);
    final updated = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      return conversation.copyWith(blocked: true);
    }).toList();
    await _replaceVault(mode, currentVault.copyWith(conversations: updated));
    notifyListeners();
  }

  Future<String?> renameGroup(VaultMode mode, String conversationId, String newName) async {
    final error = RavenValidation.groupNameError(newName);
    if (error != null) return error;
    final currentVault = vaultFor(mode);
    final clean = newName.trim();
    final updated = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      return conversation.copyWith(name: clean, initials: _initialsFromName(clean));
    }).toList();
    await _replaceVault(mode, currentVault.copyWith(conversations: updated));
    notifyListeners();
    return null;
  }

  Future<void> addConversation(VaultMode mode, String name) async {
    final currentVault = vaultFor(mode);
    await addConversationWithRavenId(mode, RavenIdService.createFromName(name.trim().isEmpty ? 'contact' : name.trim()));
    if (currentVault.conversations.length == vaultFor(mode).conversations.length) {
      notifyListeners();
    }
  }

  Future<String?> addMessage(VaultMode mode, String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final currentVault = vaultFor(mode);
    final messageId = _newId('message');
    final updatedConversations = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      final contact = currentVault.contactById(conversation.contactId);
      return conversation.copyWith(
        unread: false,
        messages: [
          ...conversation.messages,
          ChatMessageData(
            id: messageId,
            conversationId: conversationId,
            senderId: currentVault.ravenId,
            receiverId: contact?.effectiveRavenId ?? 'rvn_unknown',
            text: trimmed,
            mine: true,
            createdAt: DateTime.now(),
            deliveryStatus: MessageDeliveryStatus.pending,
          ),
        ],
      );
    }).toList();

    await _replaceVault(mode, currentVault.copyWith(conversations: updatedConversations));
    notifyListeners();
    return messageId;
  }

  Future<void> simulateMessageDelivery(VaultMode mode, String conversationId, String messageId) async {
    await _messageSyncService.simulateOutgoingStatusFlow(
      (status) => updateMessageStatus(mode, conversationId, messageId, status),
    );
  }

  Future<void> updateMessageStatus(
    VaultMode mode,
    String conversationId,
    String messageId,
    MessageDeliveryStatus status,
  ) async {
    final currentVault = vaultFor(mode);
    final updatedConversations = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      return conversation.copyWith(
        messages: conversation.messages.map((message) {
          if (message.id != messageId) return message;
          return message.copyWith(deliveryStatus: status);
        }).toList(),
      );
    }).toList();

    await _replaceVault(mode, currentVault.copyWith(conversations: updatedConversations));
    notifyListeners();
  }

  Future<void> addAutomaticReply(VaultMode mode, String conversationId) async {
    final replyText = mode == VaultMode.decoy
        ? 'Ok, agreed.'
        : "Received. We'll talk later in more detail.";

    final currentVault = vaultFor(mode);
    final updatedConversations = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      final contact = currentVault.contactById(conversation.contactId);
      return conversation.copyWith(
        unread: true,
        messages: [
          ...conversation.messages,
          ChatMessageData(
            id: _newId('message'),
            conversationId: conversationId,
            senderId: contact?.effectiveRavenId ?? 'rvn_unknown',
            receiverId: currentVault.ravenId,
            text: replyText,
            mine: false,
            createdAt: DateTime.now(),
            deliveryStatus: MessageDeliveryStatus.delivered,
          ),
        ],
      );
    }).toList();

    await _replaceVault(mode, currentVault.copyWith(conversations: updatedConversations));
    notifyListeners();
  }

  Future<void> resetEnvironment(VaultMode mode) async {
    final vault = mode == VaultMode.real ? RavenDefaults.realVault() : RavenDefaults.decoyVault();
    await _replaceVault(mode, vault);
    notifyListeners();
  }

  Future<void> resetDemo() async {
    _persistent = await _createInitialPersistentState();
    _settings = const RavenSecuritySettings();
    _pinAttempts = const PinAttemptState();
    _unlockedVaults.clear();
    _vaultKeys.clear();
    _sessionPins.clear();
    await _savePersistent();
    await _saveSettings();
    await _savePinAttempts();
    notifyListeners();
  }

  Future<void> clearEmergencyLock() async {
    final persistent = _persistent;
    if (persistent == null) return;
    _persistent = persistent.copyWith(emergencyLocked: false);
    await _savePersistent();
    notifyListeners();
  }

  void lockSession() {
    _unlockedVaults.clear();
    _vaultKeys.clear();
    _sessionPins.clear();
    notifyListeners();
  }

  Future<void> _replaceVault(VaultMode mode, VaultData vault) async {
    final persistent = _persistent;
    final vaultKey = _vaultKeys[mode];
    if (persistent == null || vaultKey == null) return;

    final encryptedVault = await _encryptVault(vault, vaultKey);
    _unlockedVaults[mode] = vault;
    _persistent = mode == VaultMode.real
        ? persistent.copyWith(realVault: encryptedVault)
        : persistent.copyWith(decoyVault: encryptedVault);
    await _savePersistent();
  }

  Future<void> _unlockVaultWithKeyWrap({
    required VaultMode mode,
    required EncryptedPayload vaultBox,
    required EncryptedBox keyWrap,
    required String pin,
  }) async {
    final vaultKey = await _decryptBytesWithPin(keyWrap, pin);
    final vault = await _decryptVault(vaultBox, vaultKey);
    _vaultKeys[mode] = vaultKey;
    _unlockedVaults[mode] = vault;
  }

  Future<RavenPersistentState> _createInitialPersistentState() async {
    final realKey = _randomBytes(32);
    final decoyKey = _randomBytes(32);

    return RavenPersistentState(
      emergencyLocked: false,
      credentials: await PinCredentials.create(
        realPin: '258000',
        decoyPin: '000000',
        emergencyPin: '999999',
        deriveKeyBytes: _deriveKeyBytes,
      ),
      realVault: await _encryptVault(RavenDefaults.realVault(), realKey),
      decoyVault: await _encryptVault(RavenDefaults.decoyVault(), decoyKey),
      realKeyWrap: await _encryptBytesWithPin(realKey, '258000'),
      decoyKeyWrap: await _encryptBytesWithPin(decoyKey, '000000'),
      emergencyDecoyKeyWrap: await _encryptBytesWithPin(decoyKey, '999999'),
    );
  }

  Future<RavenPersistentState> _migrateLegacyState(Map<String, dynamic> json) async {
    final realPin = json['realPin'] as String? ?? '258000';
    final decoyPin = json['decoyPin'] as String? ?? '000000';
    final emergencyPin = json['emergencyPin'] as String? ?? '999999';
    final realVault = VaultData.fromJson(json['realVault'] as Map<String, dynamic>? ?? {});
    final decoyVault = VaultData.fromJson(json['decoyVault'] as Map<String, dynamic>? ?? {});
    final realKey = _randomBytes(32);
    final decoyKey = _randomBytes(32);

    return RavenPersistentState(
      emergencyLocked: json['emergencyLocked'] as bool? ?? false,
      credentials: await PinCredentials.create(
        realPin: realPin,
        decoyPin: decoyPin,
        emergencyPin: emergencyPin,
        deriveKeyBytes: _deriveKeyBytes,
      ),
      realVault: await _encryptVault(realVault, realKey),
      decoyVault: await _encryptVault(decoyVault, decoyKey),
      realKeyWrap: await _encryptBytesWithPin(realKey, realPin),
      decoyKeyWrap: await _encryptBytesWithPin(decoyKey, decoyPin),
      emergencyDecoyKeyWrap: await _encryptBytesWithPin(decoyKey, emergencyPin),
    );
  }

  Future<EncryptedPayload> _encryptVault(VaultData vault, List<int> vaultKey) async {
    final clearBytes = utf8.encode(jsonEncode(vault.toJson()));
    return _encryptWithRawKey(clearBytes, vaultKey);
  }

  Future<VaultData> _decryptVault(EncryptedPayload payload, List<int> vaultKey) async {
    final clearBytes = await _decryptWithRawKey(payload, vaultKey);
    return VaultData.fromJson(jsonDecode(utf8.decode(clearBytes)) as Map<String, dynamic>);
  }

  Future<EncryptedBox> _encryptBytesWithPin(List<int> clearBytes, String pin) async {
    final salt = _randomBytes(16);
    final keyBytes = await _deriveKeyBytes(pin, salt);
    final encrypted = await _encryptWithRawKey(clearBytes, keyBytes);
    return EncryptedBox(salt: salt, payload: encrypted);
  }

  Future<List<int>> _decryptBytesWithPin(EncryptedBox box, String pin) async {
    final keyBytes = await _deriveKeyBytes(pin, box.salt);
    return _decryptWithRawKey(box.payload, keyBytes);
  }

  Future<EncryptedPayload> _encryptWithRawKey(List<int> clearBytes, List<int> keyBytes) async {
    final nonce = _randomBytes(12);
    final secretBox = await _aesGcm.encrypt(
      clearBytes,
      secretKey: SecretKey(keyBytes),
      nonce: nonce,
    );
    return EncryptedPayload(
      nonce: secretBox.nonce,
      cipherText: secretBox.cipherText,
      mac: secretBox.mac.bytes,
    );
  }

  Future<List<int>> _decryptWithRawKey(EncryptedPayload payload, List<int> keyBytes) async {
    final secretBox = SecretBox(
      payload.cipherText,
      nonce: payload.nonce,
      mac: Mac(payload.mac),
    );
    return _aesGcm.decrypt(secretBox, secretKey: SecretKey(keyBytes));
  }

  Future<List<int>> _deriveKeyBytes(String pin, List<int> salt) async {
    final key = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(pin)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  Future<void> _saveAccount() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final account = _account;
    if (account == null) {
      await prefs.remove(_accountStorageKey);
      return;
    }
    await prefs.setString(_accountStorageKey, jsonEncode(account.toJson()));
  }

  Future<void> _saveSettings() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_securitySettingsKey, jsonEncode(_settings.toJson()));
  }

  Future<void> _savePinAttempts() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_pinAttemptsKey, jsonEncode(_pinAttempts.toJson()));
  }

  Future<void> _savePersistent() async {
    final persistent = _persistent;
    if (persistent == null) return;
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString(_storageKey, jsonEncode(persistent.toJson()));
  }

  static List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }

  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var result = 0;
    for (var i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }
    return result == 0;
  }

  static String _newId(String prefix) => '${prefix}_${DateTime.now().microsecondsSinceEpoch}';

  static String _initialsFromName(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return '?';
    final parts = clean.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
    if (parts.length == 1) {
      return String.fromCharCodes(parts.first.runes.take(2)).toUpperCase();
    }
    final first = String.fromCharCode(parts.first.runes.first);
    final last = String.fromCharCode(parts.last.runes.first);
    return '$first$last'.toUpperCase();
  }

  static Color _colorFromName(String name) {
    const colors = [
      Color(0xFF5967D6),
      Color(0xFF2E8B80),
      Color(0xFF6B5B95),
      Color(0xFFE08D3C),
      Color(0xFF4A6572),
      Color(0xFFC76D7E),
      Color(0xFF59A96A),
    ];
    final index = name.codeUnits.fold<int>(0, (sum, value) => sum + value) % colors.length;
    return colors[index];
  }
}


class RavenAccountState {
  const RavenAccountState({
    required this.created,
    required this.email,
    required this.displayName,
    required this.passwordVerifier,
    this.emailVerified = true,
  });

  final bool created;
  final String email;
  final String displayName;
  final PinVerifier passwordVerifier;
  final bool emailVerified;

  RavenAccountState copyWith({
    bool? created,
    String? email,
    String? displayName,
    PinVerifier? passwordVerifier,
    bool? emailVerified,
  }) {
    return RavenAccountState(
      created: created ?? this.created,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      passwordVerifier: passwordVerifier ?? this.passwordVerifier,
      emailVerified: emailVerified ?? this.emailVerified,
    );
  }

  Map<String, dynamic> toJson() => {
        'created': created,
        'email': email,
        'displayName': displayName,
        'passwordVerifier': passwordVerifier.toJson(),
        'emailVerified': emailVerified,
      };

  factory RavenAccountState.fromJson(Map<String, dynamic> json) {
    return RavenAccountState(
      created: json['created'] as bool? ?? false,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Raven user',
      passwordVerifier: PinVerifier.fromJson(json['passwordVerifier'] as Map<String, dynamic>? ?? {}),
      emailVerified: json['emailVerified'] as bool? ?? true,
    );
  }
}

class RavenSecuritySettings {
  const RavenSecuritySettings({
    this.appLockEnabled = false,
    this.autoRealPin = '258000',
    this.autoDecoyPin = '000000',
    this.autoEmergencyPin = '999999',
    this.pinRecoveryEnabled = false,
    this.showOnlineStatus = true,
    this.readReceiptsEnabled = true,
    this.hideMessagePreviews = true,
    this.groupAddPolicy = 'invite',
  });

  final bool appLockEnabled;
  final String autoRealPin;
  final String autoDecoyPin;
  final String autoEmergencyPin;
  final bool pinRecoveryEnabled;
  final bool showOnlineStatus;
  final bool readReceiptsEnabled;
  final bool hideMessagePreviews;
  final String groupAddPolicy;

  RavenSecuritySettings copyWith({
    bool? appLockEnabled,
    String? autoRealPin,
    String? autoDecoyPin,
    String? autoEmergencyPin,
    bool? pinRecoveryEnabled,
    bool? showOnlineStatus,
    bool? readReceiptsEnabled,
    bool? hideMessagePreviews,
    String? groupAddPolicy,
  }) {
    return RavenSecuritySettings(
      appLockEnabled: appLockEnabled ?? this.appLockEnabled,
      autoRealPin: autoRealPin ?? this.autoRealPin,
      autoDecoyPin: autoDecoyPin ?? this.autoDecoyPin,
      autoEmergencyPin: autoEmergencyPin ?? this.autoEmergencyPin,
      pinRecoveryEnabled: pinRecoveryEnabled ?? this.pinRecoveryEnabled,
      showOnlineStatus: showOnlineStatus ?? this.showOnlineStatus,
      readReceiptsEnabled: readReceiptsEnabled ?? this.readReceiptsEnabled,
      hideMessagePreviews: hideMessagePreviews ?? this.hideMessagePreviews,
      groupAddPolicy: groupAddPolicy ?? this.groupAddPolicy,
    );
  }

  Map<String, dynamic> toJson() => {
        'appLockEnabled': appLockEnabled,
        'autoRealPin': autoRealPin,
        'autoDecoyPin': autoDecoyPin,
        'autoEmergencyPin': autoEmergencyPin,
        'pinRecoveryEnabled': pinRecoveryEnabled,
        'showOnlineStatus': showOnlineStatus,
        'readReceiptsEnabled': readReceiptsEnabled,
        'hideMessagePreviews': hideMessagePreviews,
        'groupAddPolicy': groupAddPolicy,
      };

  factory RavenSecuritySettings.fromJson(Map<String, dynamic> json) {
    return RavenSecuritySettings(
      appLockEnabled: json['appLockEnabled'] as bool? ?? false,
      autoRealPin: json['autoRealPin'] as String? ?? '258000',
      autoDecoyPin: json['autoDecoyPin'] as String? ?? '000000',
      autoEmergencyPin: json['autoEmergencyPin'] as String? ?? '999999',
      pinRecoveryEnabled: json['pinRecoveryEnabled'] as bool? ?? false,
      showOnlineStatus: json['showOnlineStatus'] as bool? ?? true,
      readReceiptsEnabled: json['readReceiptsEnabled'] as bool? ?? true,
      hideMessagePreviews: json['hideMessagePreviews'] as bool? ?? true,
      groupAddPolicy: json['groupAddPolicy'] as String? ?? 'invite',
    );
  }
}

class PinAttemptState {
  const PinAttemptState({this.failedAttempts = 0, this.cooldownUntil});

  final int failedAttempts;
  final DateTime? cooldownUntil;

  Duration get remaining {
    final until = cooldownUntil;
    if (until == null) return Duration.zero;
    final diff = until.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  bool get inCooldown => remaining > Duration.zero;

  Map<String, dynamic> toJson() => {
        'failedAttempts': failedAttempts,
        'cooldownUntil': cooldownUntil?.toIso8601String(),
      };

  factory PinAttemptState.fromJson(Map<String, dynamic> json) {
    return PinAttemptState(
      failedAttempts: json['failedAttempts'] as int? ?? 0,
      cooldownUntil: DateTime.tryParse(json['cooldownUntil'] as String? ?? ''),
    );
  }
}

class RavenPersistentState {
  const RavenPersistentState({
    required this.emergencyLocked,
    required this.credentials,
    required this.realVault,
    required this.decoyVault,
    required this.realKeyWrap,
    required this.decoyKeyWrap,
    required this.emergencyDecoyKeyWrap,
  });

  final bool emergencyLocked;
  final PinCredentials credentials;
  final EncryptedPayload realVault;
  final EncryptedPayload decoyVault;
  final EncryptedBox realKeyWrap;
  final EncryptedBox decoyKeyWrap;
  final EncryptedBox emergencyDecoyKeyWrap;

  RavenPersistentState copyWith({
    bool? emergencyLocked,
    PinCredentials? credentials,
    EncryptedPayload? realVault,
    EncryptedPayload? decoyVault,
    EncryptedBox? realKeyWrap,
    EncryptedBox? decoyKeyWrap,
    EncryptedBox? emergencyDecoyKeyWrap,
  }) {
    return RavenPersistentState(
      emergencyLocked: emergencyLocked ?? this.emergencyLocked,
      credentials: credentials ?? this.credentials,
      realVault: realVault ?? this.realVault,
      decoyVault: decoyVault ?? this.decoyVault,
      realKeyWrap: realKeyWrap ?? this.realKeyWrap,
      decoyKeyWrap: decoyKeyWrap ?? this.decoyKeyWrap,
      emergencyDecoyKeyWrap: emergencyDecoyKeyWrap ?? this.emergencyDecoyKeyWrap,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema': 3,
        'emergencyLocked': emergencyLocked,
        'credentials': credentials.toJson(),
        'realVault': realVault.toJson(),
        'decoyVault': decoyVault.toJson(),
        'realKeyWrap': realKeyWrap.toJson(),
        'decoyKeyWrap': decoyKeyWrap.toJson(),
        'emergencyDecoyKeyWrap': emergencyDecoyKeyWrap.toJson(),
      };

  factory RavenPersistentState.fromJson(Map<String, dynamic> json) {
    return RavenPersistentState(
      emergencyLocked: json['emergencyLocked'] as bool? ?? false,
      credentials: PinCredentials.fromJson(json['credentials'] as Map<String, dynamic>? ?? {}),
      realVault: EncryptedPayload.fromJson(json['realVault'] as Map<String, dynamic>? ?? {}),
      decoyVault: EncryptedPayload.fromJson(json['decoyVault'] as Map<String, dynamic>? ?? {}),
      realKeyWrap: EncryptedBox.fromJson(json['realKeyWrap'] as Map<String, dynamic>? ?? {}),
      decoyKeyWrap: EncryptedBox.fromJson(json['decoyKeyWrap'] as Map<String, dynamic>? ?? {}),
      emergencyDecoyKeyWrap: EncryptedBox.fromJson(json['emergencyDecoyKeyWrap'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class PinCredentials {
  const PinCredentials({
    required this.real,
    required this.decoy,
    required this.emergency,
  });

  final PinVerifier real;
  final PinVerifier decoy;
  final PinVerifier emergency;

  static Future<PinCredentials> create({
    required String realPin,
    required String decoyPin,
    required String emergencyPin,
    required Future<List<int>> Function(String pin, List<int> salt) deriveKeyBytes,
  }) async {
    return PinCredentials(
      real: await PinVerifier.create(realPin, deriveKeyBytes),
      decoy: await PinVerifier.create(decoyPin, deriveKeyBytes),
      emergency: await PinVerifier.create(emergencyPin, deriveKeyBytes),
    );
  }

  Future<bool> verifyAll({
    required String realPin,
    required String decoyPin,
    required String emergencyPin,
    required Future<List<int>> Function(String pin, List<int> salt) deriveKeyBytes,
  }) async {
    return await real.verify(realPin, deriveKeyBytes) &&
        await decoy.verify(decoyPin, deriveKeyBytes) &&
        await emergency.verify(emergencyPin, deriveKeyBytes);
  }

  Map<String, dynamic> toJson() => {
        'real': real.toJson(),
        'decoy': decoy.toJson(),
        'emergency': emergency.toJson(),
      };

  factory PinCredentials.fromJson(Map<String, dynamic> json) {
    return PinCredentials(
      real: PinVerifier.fromJson(json['real'] as Map<String, dynamic>? ?? {}),
      decoy: PinVerifier.fromJson(json['decoy'] as Map<String, dynamic>? ?? {}),
      emergency: PinVerifier.fromJson(json['emergency'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class PinVerifier {
  const PinVerifier({required this.salt, required this.hash});

  final List<int> salt;
  final List<int> hash;

  static Future<PinVerifier> create(
    String pin,
    Future<List<int>> Function(String pin, List<int> salt) deriveKeyBytes,
  ) async {
    final salt = RavenStore._randomBytes(16);
    final hash = await deriveKeyBytes(pin, salt);
    return PinVerifier(salt: salt, hash: hash);
  }

  Future<bool> verify(
    String pin,
    Future<List<int>> Function(String pin, List<int> salt) deriveKeyBytes,
  ) async {
    final candidate = await deriveKeyBytes(pin, salt);
    return RavenStore.constantTimeEquals(candidate, hash);
  }

  Map<String, dynamic> toJson() => {
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
      };

  factory PinVerifier.fromJson(Map<String, dynamic> json) {
    return PinVerifier(
      salt: base64Decode(json['salt'] as String? ?? ''),
      hash: base64Decode(json['hash'] as String? ?? ''),
    );
  }
}

class EncryptedBox {
  const EncryptedBox({required this.salt, required this.payload});

  final List<int> salt;
  final EncryptedPayload payload;

  Map<String, dynamic> toJson() => {
        'salt': base64Encode(salt),
        'payload': payload.toJson(),
      };

  factory EncryptedBox.fromJson(Map<String, dynamic> json) {
    return EncryptedBox(
      salt: base64Decode(json['salt'] as String? ?? ''),
      payload: EncryptedPayload.fromJson(json['payload'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class EncryptedPayload {
  const EncryptedPayload({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  Map<String, dynamic> toJson() => {
        'nonce': base64Encode(nonce),
        'cipherText': base64Encode(cipherText),
        'mac': base64Encode(mac),
      };

  factory EncryptedPayload.fromJson(Map<String, dynamic> json) {
    return EncryptedPayload(
      nonce: base64Decode(json['nonce'] as String? ?? ''),
      cipherText: base64Decode(json['cipherText'] as String? ?? ''),
      mac: base64Decode(json['mac'] as String? ?? ''),
    );
  }
}

class RavenDefaults {
  static VaultData realVault() {
    final contacts = [
      ContactData(
        id: 'contact_joao_perigoso',
        name: 'John Dangerous',
        handle: '@joao.perigoso',
        initials: 'JP',
        colorValue: const Color(0xFF6B5B95).value,
        note: 'Main vault contact.',
      ),
      ContactData(
        id: 'contact_starryskies',
        name: 'starryskies23',
        handle: '@starryskies23',
        initials: 'S',
        colorValue: const Color(0xFF2E8B80).value,
        note: 'Real contact kept only in the main vault.',
      ),
      ContactData(
        id: 'contact_nebulanomad',
        name: 'nebulanomad',
        handle: '@nebulanomad',
        initials: 'N',
        colorValue: const Color(0xFF333A73).value,
        note: 'Private contact.',
      ),
      ContactData(
        id: 'contact_emberecho',
        name: 'emberecho',
        handle: '@emberecho',
        initials: 'E',
        colorValue: const Color(0xFFC76D7E).value,
        note: 'Private contact.',
      ),
      ContactData(
        id: 'contact_lunavoyager',
        name: 'lunavoyager',
        handle: '@lunavoyager',
        initials: 'L',
        colorValue: const Color(0xFF7A7F8F).value,
        note: 'Private contact.',
      ),
      ContactData(
        id: 'contact_shadowlynx',
        name: 'shadowlynx',
        handle: '@shadowlynx',
        initials: 'Sx',
        colorValue: const Color(0xFF009688).value,
        note: 'Private contact.',
      ),
    ];

    return VaultData(
      displayName: 'Raven account',
      email: 'raven.user@email.com',
      ravenId: 'rvn_conta_raven_demo',
      about: 'Main vault: sensitive contacts and chats.',
      contacts: contacts,
      conversations: [
        ConversationData(
          id: 'real_joao_perigoso',
          contactId: 'contact_joao_perigoso',
          name: 'John Dangerous',
          initials: 'JP',
          colorValue: const Color(0xFF6B5B95).value,
          unread: true,
          messages: [
            ChatMessageData(
              id: 'r1',
              text: 'Huh?',
              mine: false,
              createdAt: DateTime(2023, 11, 30, 9, 41),
            ),
            ChatMessageData(
              id: 'r2',
              text: 'Nice',
              mine: false,
              createdAt: DateTime(2023, 11, 30, 9, 42),
            ),
            ChatMessageData(
              id: 'r3',
              text: 'How does it work?',
              mine: false,
              createdAt: DateTime(2023, 11, 30, 9, 43),
            ),
            ChatMessageData(
              id: 'r4',
              text: 'You can edit any text to insert the chat you want to show and remove the bubbles you do not need.',
              mine: true,
              createdAt: DateTime(2023, 11, 30, 9, 44),
            ),
            ChatMessageData(
              id: 'r5',
              text: 'Bum!',
              mine: true,
              createdAt: DateTime(2023, 11, 30, 9, 45),
            ),
            ChatMessageData(
              id: 'r6',
              text: 'I think I get it',
              mine: false,
              createdAt: DateTime(2023, 11, 30, 9, 47),
            ),
          ],
        ),
        ConversationData(
          id: 'real_starryskies',
          contactId: 'contact_starryskies',
          name: 'starryskies23',
          initials: 'S',
          colorValue: const Color(0xFF2E8B80).value,
          unread: false,
          messages: [
            ChatMessageData(
              id: 'r8',
              text: 'Okay, agreed',
              mine: false,
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ],
        ),
        ConversationData(
          id: 'real_nebulanomad',
          contactId: 'contact_nebulanomad',
          name: 'nebulanomad',
          initials: 'N',
          colorValue: const Color(0xFF333A73).value,
          unread: false,
          messages: [
            ChatMessageData(
              id: 'r9',
              text: 'Liked your post',
              mine: false,
              createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
            ),
          ],
        ),
        ConversationData(
          id: 'real_emberecho',
          contactId: 'contact_emberecho',
          name: 'emberecho',
          initials: 'E',
          colorValue: const Color(0xFFC76D7E).value,
          unread: false,
          messages: [
            ChatMessageData(
              id: 'r10',
              text: 'Happy birthday!!! 🎉🎉',
              mine: false,
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
        ),
        ConversationData(
          id: 'real_lunavoyager',
          contactId: 'contact_lunavoyager',
          name: 'lunavoyager',
          initials: 'L',
          colorValue: const Color(0xFF7A7F8F).value,
          unread: false,
          messages: [
            ChatMessageData(
              id: 'r11',
              text: 'Ok!',
              mine: false,
              createdAt: DateTime.now().subtract(const Duration(days: 3)),
            ),
          ],
        ),
      ],
    );
  }

  static VaultData decoyVault() {
    final contacts = [
      ContactData(
        id: 'contact_faculdade',
        name: 'College group',
        handle: '@faculdade',
        initials: 'GF',
        colorValue: const Color(0xFF5967D6).value,
        note: 'Plausible group for the cover environment.',
      ),
      ContactData(
        id: 'contact_mae',
        name: 'Mom',
        handle: '@mae',
        initials: 'M',
        colorValue: const Color(0xFFE08D3C).value,
        note: 'Family contact in the cover profile.',
      ),
      ContactData(
        id: 'contact_trabalho',
        name: 'Work',
        handle: '@trabalho',
        initials: 'TR',
        colorValue: const Color(0xFF4A6572).value,
        note: 'Ordinary contact so the account does not look empty.',
      ),
      ContactData(
        id: 'contact_mercado',
        name: 'Good Price Market',
        handle: '@mercado.bompreco',
        initials: 'MB',
        colorValue: const Color(0xFF59A96A).value,
        note: 'Plausible promotional contact.',
      ),
    ];

    return VaultData(
      displayName: 'Regular user',
      email: 'contato.demo@email.com',
      ravenId: 'rvn_usuario_comum_demo',
      about: 'Cover profile: ordinary content for coercion scenarios.',
      contacts: contacts,
      conversations: [
        ConversationData(
          id: 'decoy_faculdade',
          contactId: 'contact_faculdade',
          name: 'College group',
          initials: 'GF',
          colorValue: const Color(0xFF5967D6).value,
          unread: true,
          messages: [
            ChatMessageData(
              id: 'd1',
              text: "Hey, did you see tomorrow's schedule?",
              mine: false,
              createdAt: DateTime(2023, 11, 30, 8, 41),
            ),
            ChatMessageData(
              id: 'd2',
              text: 'Yes. I think it is at 9.',
              mine: true,
              createdAt: DateTime(2023, 11, 30, 8, 43),
            ),
            ChatMessageData(
              id: 'd3',
              text: 'Great, thanks!',
              mine: false,
              createdAt: DateTime(2023, 11, 30, 8, 44),
            ),
            ChatMessageData(
              id: 'd4',
              text: "I'll let you know if anything changes.",
              mine: true,
              createdAt: DateTime(2023, 11, 30, 8, 45),
            ),
          ],
        ),
        ConversationData(
          id: 'decoy_mae',
          contactId: 'contact_mae',
          name: 'Mom',
          initials: 'M',
          colorValue: const Color(0xFFE08D3C).value,
          unread: false,
          messages: [
            ChatMessageData(
              id: 'd5',
              text: 'Come home early today',
              mine: false,
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ],
        ),
        ConversationData(
          id: 'decoy_trabalho',
          contactId: 'contact_trabalho',
          name: 'Work',
          initials: 'TR',
          colorValue: const Color(0xFF4A6572).value,
          unread: false,
          messages: [
            ChatMessageData(
              id: 'd6',
              text: 'I sent the updated file',
              mine: true,
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
        ),
        ConversationData(
          id: 'decoy_mercado',
          contactId: 'contact_mercado',
          name: 'Good Price Market',
          initials: 'MB',
          colorValue: const Color(0xFF59A96A).value,
          unread: false,
          messages: [
            ChatMessageData(
              id: 'd7',
              text: 'Your weekly coupon is here',
              mine: false,
              createdAt: DateTime.now().subtract(const Duration(days: 4)),
            ),
          ],
        ),
      ],
    );
  }
}

class VaultData {
  const VaultData({
    required this.displayName,
    required this.email,
    required this.about,
    required this.contacts,
    required this.conversations,
    this.ravenId = 'rvn_local_user',
  });

  final String displayName;
  final String email;
  final String about;
  final List<ContactData> contacts;
  final List<ConversationData> conversations;
  final String ravenId;

  String get avatarInitials => RavenStore._initialsFromName(displayName);

  ContactData? contactById(String? id) {
    if (id == null) return null;
    for (final contact in contacts) {
      if (contact.id == id) return contact;
    }
    return null;
  }

  int get pendingMessages => conversations.fold<int>(
        0,
        (sum, conversation) => sum + conversation.messages.where((message) => message.deliveryStatus == MessageDeliveryStatus.pending).length,
      );

  VaultData copyWith({
    String? displayName,
    String? email,
    String? about,
    List<ContactData>? contacts,
    List<ConversationData>? conversations,
    String? ravenId,
  }) {
    return VaultData(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      about: about ?? this.about,
      contacts: contacts ?? this.contacts,
      conversations: conversations ?? this.conversations,
      ravenId: ravenId ?? this.ravenId,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'about': about,
        'ravenId': ravenId,
        'contacts': contacts.map((contact) => contact.toJson()).toList(),
        'conversations': conversations.map((conversation) => conversation.toJson()).toList(),
      };

  factory VaultData.fromJson(Map<String, dynamic> json) {
    final displayName = json['displayName'] as String? ?? 'Raven account';
    final ownRavenId = json['ravenId'] as String? ?? RavenIdService.stableFromName(displayName);
    final conversations = ((json['conversations'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ConversationData.fromJson)
        .toList();

    final decodedContacts = ((json['contacts'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ContactData.fromJson)
        .toList();

    final normalizedConversations = decodedContacts.isEmpty
        ? conversations
            .map(
              (conversation) => conversation.copyWith(
                contactId: conversation.contactId ?? 'contact_${conversation.id}',
              ),
            )
            .toList()
        : conversations;

    final contacts = decodedContacts.isNotEmpty
        ? decodedContacts
        : normalizedConversations
            .map(
              (conversation) => ContactData(
                id: conversation.contactId ?? 'contact_${conversation.id}',
                name: conversation.name,
                handle: '@${conversation.name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
                ravenId: RavenIdService.createFromName(conversation.name),
                initials: conversation.initials,
                colorValue: conversation.colorValue,
                note: 'Contact migrated from local chats.',
              ),
            )
            .toList();

    return VaultData(
      displayName: displayName,
      email: json['email'] as String? ?? 'raven.user@email.com',
      about: json['about'] as String? ?? 'Protected by Raven.',
      ravenId: ownRavenId,
      contacts: contacts,
      conversations: normalizedConversations,
    );
  }
}

class ContactData {
  const ContactData({
    required this.id,
    required this.name,
    required this.handle,
    required this.initials,
    required this.colorValue,
    required this.note,
    this.ravenId = '',
    this.publicKeyPreview = 'public-key-pending',
  });

  final String id;
  final String name;
  final String handle;
  final String ravenId;
  final String initials;
  final int colorValue;
  final String note;
  final String publicKeyPreview;

  String get effectiveRavenId => ravenId.isEmpty ? RavenIdService.stableFromName(name) : ravenId;

  ContactData copyWith({
    String? id,
    String? name,
    String? handle,
    String? ravenId,
    String? initials,
    int? colorValue,
    String? note,
    String? publicKeyPreview,
  }) {
    return ContactData(
      id: id ?? this.id,
      name: name ?? this.name,
      handle: handle ?? this.handle,
      ravenId: ravenId ?? this.ravenId,
      initials: initials ?? this.initials,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      publicKeyPreview: publicKeyPreview ?? this.publicKeyPreview,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'handle': handle,
        'ravenId': effectiveRavenId,
        'initials': initials,
        'colorValue': colorValue,
        'note': note,
        'publicKeyPreview': publicKeyPreview,
      };

  factory ContactData.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'Contact';
    return ContactData(
      id: json['id'] as String? ?? 'contact_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      handle: json['handle'] as String? ?? '@${name.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
      ravenId: json['ravenId'] as String? ?? RavenIdService.stableFromName(name),
      initials: json['initials'] as String? ?? RavenStore._initialsFromName(name),
      colorValue: json['colorValue'] as int? ?? RavenApp.ravenBlue.value,
      note: json['note'] as String? ?? '',
      publicKeyPreview: json['publicKeyPreview'] as String? ?? 'public-key-pending',
    );
  }
}

class ConversationData {
  const ConversationData({
    required this.id,
    required this.name,
    required this.initials,
    required this.colorValue,
    required this.unread,
    required this.messages,
    this.contactId,
    this.isGroup = false,
    this.memberRavenIds = const [],
    this.pinned = false,
    this.blocked = false,
    this.owner = true,
  });

  final String id;
  final String name;
  final String initials;
  final int colorValue;
  final bool unread;
  final List<ChatMessageData> messages;
  final String? contactId;
  final bool isGroup;
  final List<String> memberRavenIds;
  final bool pinned;
  final bool blocked;
  final bool owner;

  String get subtitle => blocked ? 'Blocked user' : (messages.isEmpty ? 'No messages yet' : messages.last.text);
  MessageDeliveryStatus? get lastOutgoingStatus {
    for (final message in messages.reversed) {
      if (message.mine) return message.deliveryStatus;
    }
    return null;
  }

  String get timeLabel {
    if (messages.isEmpty) return '';
    final now = DateTime.now();
    final last = messages.last.createdAt;
    final difference = now.difference(last);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}min';
    if (difference.inDays < 1) {
      return '${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}';
    }
    if (difference.inDays == 1) return '1d';
    return '${difference.inDays}d';
  }

  ConversationData copyWith({
    String? id,
    String? name,
    String? initials,
    int? colorValue,
    bool? unread,
    List<ChatMessageData>? messages,
    String? contactId,
    bool? isGroup,
    List<String>? memberRavenIds,
    bool? pinned,
    bool? blocked,
    bool? owner,
  }) {
    return ConversationData(
      id: id ?? this.id,
      name: name ?? this.name,
      initials: initials ?? this.initials,
      colorValue: colorValue ?? this.colorValue,
      unread: unread ?? this.unread,
      messages: messages ?? this.messages,
      contactId: contactId ?? this.contactId,
      isGroup: isGroup ?? this.isGroup,
      memberRavenIds: memberRavenIds ?? this.memberRavenIds,
      pinned: pinned ?? this.pinned,
      blocked: blocked ?? this.blocked,
      owner: owner ?? this.owner,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initials': initials,
        'colorValue': colorValue,
        'unread': unread,
        'contactId': contactId,
        'isGroup': isGroup,
        'memberRavenIds': memberRavenIds,
        'pinned': pinned,
        'blocked': blocked,
        'owner': owner,
        'messages': messages.map((message) => message.toJson()).toList(),
      };

  factory ConversationData.fromJson(Map<String, dynamic> json) {
    final conversationId = json['id'] as String? ?? 'conversation_${DateTime.now().microsecondsSinceEpoch}';
    final messages = ((json['messages'] as List<dynamic>?) ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ChatMessageData.fromJson)
        .map((message) => message.conversationId.isEmpty ? message.copyWith(conversationId: conversationId) : message)
        .toList();

    return ConversationData(
      id: conversationId,
      name: json['name'] as String? ?? 'Contact',
      initials: json['initials'] as String? ?? 'C',
      colorValue: json['colorValue'] as int? ?? RavenApp.ravenBlue.value,
      unread: json['unread'] as bool? ?? false,
      contactId: json['contactId'] as String?,
      isGroup: json['isGroup'] as bool? ?? ((json['name'] as String? ?? '').startsWith('Group:')),
      memberRavenIds: ((json['memberRavenIds'] as List<dynamic>?) ?? []).whereType<String>().toList(),
      pinned: json['pinned'] as bool? ?? false,
      blocked: json['blocked'] as bool? ?? false,
      owner: json['owner'] as bool? ?? true,
      messages: messages,
    );
  }
}

class ChatMessageData {
  const ChatMessageData({
    required this.id,
    required this.text,
    required this.mine,
    required this.createdAt,
    this.conversationId = '',
    this.senderId = '',
    this.receiverId = '',
    this.encryptedPayload = '',
    this.deliveryStatus = MessageDeliveryStatus.local,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String encryptedPayload;
  final String text;
  final bool mine;
  final DateTime createdAt;
  final MessageDeliveryStatus deliveryStatus;

  ChatMessageData copyWith({
    String? id,
    String? conversationId,
    String? senderId,
    String? receiverId,
    String? encryptedPayload,
    String? text,
    bool? mine,
    DateTime? createdAt,
    MessageDeliveryStatus? deliveryStatus,
  }) {
    return ChatMessageData(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      encryptedPayload: encryptedPayload ?? this.encryptedPayload,
      text: text ?? this.text,
      mine: mine ?? this.mine,
      createdAt: createdAt ?? this.createdAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'conversationId': conversationId,
        'senderId': senderId,
        'receiverId': receiverId,
        'encryptedPayload': encryptedPayload,
        'text': text,
        'mine': mine,
        'createdAt': createdAt.toIso8601String(),
        'deliveryStatus': deliveryStatus.storageValue,
      };

  factory ChatMessageData.fromJson(Map<String, dynamic> json) {
    return ChatMessageData(
      id: json['id'] as String? ?? 'message_${DateTime.now().microsecondsSinceEpoch}',
      conversationId: json['conversationId'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      receiverId: json['receiverId'] as String? ?? '',
      encryptedPayload: json['encryptedPayload'] as String? ?? '',
      text: json['text'] as String? ?? '',
      mine: json['mine'] as bool? ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      deliveryStatus: messageDeliveryStatusFromStorage(json['deliveryStatus'] as String?),
    );
  }
}


class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _routeWhenReady();
  }

  Future<void> _routeWhenReady() async {
    final store = RavenScope.of(context);
    while (mounted && !store.loaded) {
      await Future.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;

    if (!store.hasAccount) {
      navigateAfterTap(context, () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
      });
      return;
    }

    if (store.appLockEnabled) {
      navigateAfterTap(context, () {
        Navigator.of(context).pushReplacementNamed('/lock');
      });
      return;
    }

    await store.openDefaultSession();
    if (!mounted) return;
    navigateAfterTap(context, () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RavenShell(mode: VaultMode.real)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RavenApp.ravenDark,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final name = _nameController.text.trim();
    final store = RavenScope.of(context);

    final nameError = RavenValidation.displayNameError(name);
    if (nameError != null) {
      setState(() {
        _busy = false;
        _error = nameError;
      });
      return;
    }
    if (!RavenValidation.isValidEmail(email)) {
      setState(() {
        _busy = false;
        _error = 'Enter a valid email address.';
      });
      return;
    }
    if (store.hasAccount && store.accountEmail.toLowerCase() == email) {
      setState(() {
        _busy = false;
        _error = 'This email is already in use.';
      });
      return;
    }
    if (password.isEmpty) {
      setState(() {
        _busy = false;
        _error = 'Account password is required.';
      });
      return;
    }
    if (password.length < 8) {
      setState(() {
        _busy = false;
        _error = 'Use at least 8 characters for the account password.';
      });
      return;
    }
    if (password.length > 128) {
      setState(() {
        _busy = false;
        _error = 'Account password must be at most 128 characters.';
      });
      return;
    }

    if (!mounted) return;
    setState(() => _busy = false);
    navigateAfterTap(context, () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: email,
            password: password,
            displayName: name,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Create account',
      subtitle: 'Enter your display name, email and password to sign up for Raven.',
      child: Column(
        children: [
          TextField(
            controller: _nameController,
            maxLength: 40,
            decoration: const InputDecoration(
              labelText: 'Display name',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: 254,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            maxLength: 128,
            decoration: InputDecoration(
              labelText: 'Account password',
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              ),
            ),
            onSubmitted: (_) => _continue(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _continue,
              child: Text(_busy ? 'Please wait...' : 'Continue'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              navigateAfterTap(context, () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              });
            },
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
    );
  }
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.password,
    required this.displayName,
  });

  final String email;
  final String password;
  final String displayName;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController(text: '123456');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }
    if (code != '123456') {
      setState(() => _error = 'Invalid verification code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final store = RavenScope.of(context);
    final result = await store.registerAccount(
      email: widget.email,
      password: widget.password,
      displayName: widget.displayName,
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }

    navigateAfterTap(context, () {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RavenShell(mode: VaultMode.real)),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Verify your email',
      subtitle: 'We sent a 6-digit code to ${widget.email}. For the demo, use 123456.',
      child: Column(
        children: [
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Verification code',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            onSubmitted: (_) => _create(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _create,
              child: Text(_busy ? 'Verifying...' : 'Verify'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo code: 123456')),
            ),
            child: const Text('Resend code'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Change email'),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = RavenScope.of(context);
    if (_emailController.text.isEmpty) _emailController.text = store.accountEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = RavenScope.of(context);
    final result = await store.loginAccount(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }

    if (store.appLockEnabled) {
      navigateAfterTap(context, () {
        Navigator.of(context).pushReplacementNamed('/lock');
      });
    } else {
      navigateAfterTap(context, () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RavenShell(mode: VaultMode.real)),
          (_) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    return _AuthScaffold(
      title: 'Log in',
      subtitle: store.hasAccount
          ? 'Use your Raven account email and password on this device.'
          : 'No local account exists yet. Create one first.',
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: 254,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            maxLength: 128,
            decoration: InputDecoration(
              labelText: 'Account password',
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _login,
              child: Text(_busy ? 'Please wait...' : 'Log in'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              navigateAfterTap(context, () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              });
            },
            child: const Text('Don\'t have an account? Create account'),
          ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RavenApp.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, color: RavenApp.ravenBlue, size: 54),
                      const SizedBox(height: 14),
                      const Text(
                        'Raven',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 22),
                      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, height: 1.25)),
                      const SizedBox(height: 22),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';

  void _tap(String value) {
    final store = RavenScope.of(context);
    if (store.pinCooldownRemaining > Duration.zero) {
      final remaining = store.pinCooldownRemaining;
      final waitLabel = remaining.inSeconds < 60 ? '${remaining.inSeconds}s' : '${remaining.inMinutes}min';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Too many attempts. Try again in $waitLabel.')),
      );
      return;
    }
    if (_pin.length >= 6) return;

    setState(() => _pin += value);

    if (_pin.length == 6) {
      Future.delayed(const Duration(milliseconds: 180), _validatePin);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _validatePin() async {
    if (!mounted) return;

    final store = RavenScope.of(context);
    final outcome = await store.unlockPin(_pin);
    if (!mounted) return;

    switch (outcome.type) {
      case AuthOutcomeType.real:
        await store.resetPinAttempts();
        _openApp(mode: VaultMode.real);
        break;
      case AuthOutcomeType.decoy:
        await store.resetPinAttempts();
        _openApp(mode: VaultMode.decoy);
        break;
      case AuthOutcomeType.emergency:
        await store.resetPinAttempts();
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Emergency mode activated'),
            content: const Text(
              'Local MVP: the real vault was marked as locked and the cover environment will open.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Open cover environment'),
              ),
            ],
          ),
        );
        if (mounted) _openApp(mode: VaultMode.decoy);
        break;
      case AuthOutcomeType.realLocked:
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Real vault locked'),
            content: const Text(
              'Emergency mode is active. In this demo, restore the state from the cover environment profile.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I understand'),
              ),
            ],
          ),
        );
        if (mounted) {
          setState(() => _pin = '');
        }
        break;
      case AuthOutcomeType.invalid:
        await store.recordFailedPinAttempt();
        final remaining = store.pinCooldownRemaining;
        final waitLabel = remaining.inSeconds < 60 ? '${remaining.inSeconds}s' : '${remaining.inMinutes}min';
        final message = remaining > Duration.zero ? 'Invalid PIN. Try again in $waitLabel.' : 'Invalid PIN.';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        setState(() => _pin = '');
        break;
    }
  }

  void _openApp({required VaultMode mode}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RavenShell(mode: mode),
      ),
    );
  }


  void _forgotPin(RavenStore store) {
    if (!store.pinRecoveryEnabled) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('PIN recovery is disabled'),
          content: const Text('Raven cannot recover local PINs for this device. You can log out or reset local data.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                store.lockSession();
                Navigator.of(context).pushReplacementNamed('/login');
              },
              child: const Text('Log out'),
            ),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PinRecoveryScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);

    if (!store.loaded) {
      return const Scaffold(
        backgroundColor: RavenApp.ravenDark,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: RavenApp.ravenDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 22, 28, 18),
          child: Column(
            children: [
              const Spacer(),
              Container(
                height: 86,
                width: 86,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Raven',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your access PIN',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  6,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    height: 13,
                    width: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length ? Colors.white : Colors.white.withOpacity(0.18),
                    ),
                  ),
                ),
              ),
              if (store.emergencyLocked) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Text(
                    'Emergency mode active: the real vault is locked in this demo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.25),
                  ),
                ),
              ],
              const Spacer(),
              _Keypad(onTap: _tap, onBackspace: _backspace),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _forgotPin(store),
                child: const Text('Forgot PIN?', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Suggested setup: 258000 main • 135790 cover • 864209 emergency',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.58),
                    fontSize: 12,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Keypad extends StatelessWidget {
  const _Keypad({required this.onTap, required this.onBackspace});

  final void Function(String value) onTap;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: row.map((value) {
              if (value.isEmpty) return const SizedBox(width: 72, height: 62);
              if (value == 'back') {
                return _KeyButton(
                  onPressed: onBackspace,
                  child: const Icon(Icons.backspace_outlined, color: Colors.white70),
                );
              }
              return _KeyButton(
                onPressed: () => onTap(value),
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.child, required this.onPressed});

  final Widget child;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 62,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: child,
      ),
    );
  }
}

class PinRecoveryScreen extends StatefulWidget {
  const PinRecoveryScreen({super.key});

  @override
  State<PinRecoveryScreen> createState() => _PinRecoveryScreenState();
}

class _PinRecoveryScreenState extends State<PinRecoveryScreen> {
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController(text: '123456');
  final _real = TextEditingController();
  final _realConfirm = TextEditingController();
  final _cover = TextEditingController();
  final _coverConfirm = TextEditingController();
  final _emergency = TextEditingController();
  final _emergencyConfirm = TextEditingController();
  String? _error;
  bool _busy = false;
  int _step = 0;

  @override
  void dispose() {
    _passwordController.dispose();
    _codeController.dispose();
    _real.dispose();
    _realConfirm.dispose();
    _cover.dispose();
    _coverConfirm.dispose();
    _emergency.dispose();
    _emergencyConfirm.dispose();
    super.dispose();
  }

  Future<void> _next(RavenStore store) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (_step == 0) {
      final result = await store.loginAccount(email: store.accountEmail, password: _passwordController.text);
      if (!mounted) return;
      if (result != null) {
        setState(() {
          _busy = false;
          _error = 'Incorrect account password.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _step = 1;
      });
      return;
    }
    if (_step == 1) {
      final code = _codeController.text.trim();
      if (!RegExp(r'^\d{6}$').hasMatch(code) || code != '123456') {
        setState(() {
          _busy = false;
          _error = 'Invalid verification code.';
        });
        return;
      }
      setState(() {
        _busy = false;
        _step = 2;
      });
      return;
    }

    if (_real.text != _realConfirm.text || _cover.text != _coverConfirm.text || _emergency.text != _emergencyConfirm.text) {
      setState(() {
        _busy = false;
        _error = 'PIN confirmations must match.';
      });
      return;
    }
    final result = await store.configureAppLock(
      enabled: true,
      realPin: _real.text.trim(),
      decoyPin: _cover.text.trim(),
      emergencyPin: _emergency.text.trim(),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs recovered.')));
    Navigator.of(context).pushReplacementNamed('/lock');
  }

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('PIN recovery')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Step ${_step + 1} of 3', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (_step == 0) ...[
                      const Text('Confirm account password', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Account password', border: OutlineInputBorder()),
                      ),
                    ] else if (_step == 1) ...[
                      const Text('Verify email', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      Text('Demo code sent to ${store.accountEmail}: 123456'),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _codeController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        maxLength: 6,
                        decoration: const InputDecoration(labelText: 'Verification code', border: OutlineInputBorder(), counterText: ''),
                      ),
                    ] else ...[
                      const Text('Set new local PINs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      _PinField(controller: _real, label: 'New Main PIN'),
                      const SizedBox(height: 10),
                      _PinField(controller: _realConfirm, label: 'Confirm Main PIN'),
                      const SizedBox(height: 10),
                      _PinField(controller: _cover, label: 'New Cover PIN'),
                      const SizedBox(height: 10),
                      _PinField(controller: _coverConfirm, label: 'Confirm Cover PIN'),
                      const SizedBox(height: 10),
                      _PinField(controller: _emergency, label: 'New Emergency PIN'),
                      const SizedBox(height: 10),
                      _PinField(controller: _emergencyConfirm, label: 'Confirm Emergency PIN'),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: _busy ? null : () => _next(store),
                      child: Text(_busy ? 'Please wait...' : (_step == 2 ? 'Recover PINs' : 'Continue')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RavenShell extends StatefulWidget {
  const RavenShell({super.key, required this.mode});

  final VaultMode mode;

  @override
  State<RavenShell> createState() => _RavenShellState();
}

class _RavenShellState extends State<RavenShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatListScreen(mode: widget.mode),
      ProfileScreen(mode: widget.mode),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        height: 62,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key, required this.mode});

  final VaultMode mode;

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  bool _searching = false;
  String _query = '';

  VaultMode get mode => widget.mode;

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    final allConversations = [...store.vaultFor(mode).conversations]
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        final aTime = a.messages.isEmpty ? DateTime.fromMillisecondsSinceEpoch(0) : a.messages.last.createdAt;
        final bTime = b.messages.isEmpty ? DateTime.fromMillisecondsSinceEpoch(0) : b.messages.last.createdAt;
        return bTime.compareTo(aTime);
      });
    final query = _query.trim().toLowerCase();
    final conversations = query.isEmpty
        ? allConversations
        : allConversations.where((conversation) {
            final contact = store.vaultFor(mode).contactById(conversation.contactId);
            return conversation.name.toLowerCase().contains(query) ||
                conversation.subtitle.toLowerCase().contains(query) ||
                (contact?.effectiveRavenId.toLowerCase().contains(query) ?? false);
          }).toList();

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search chats',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() => _query = value),
              )
            : const Text('Raven'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search',
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) _query = '';
              });
            },
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) async => _handleTopMenu(context, store, value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'new_chat', child: Text('New chat')),
              PopupMenuItem(value: 'new_group', child: Text('New group')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
              PopupMenuItem(value: 'profile', child: Text('Profile')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'lock', child: Text('Lock app')),
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewChatDialog(context, store),
        backgroundColor: RavenApp.ravenBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_comment_rounded),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 88),
        children: [
          if (conversations.isEmpty)
            _EmptyState(onNewChat: () => _showNewChatDialog(context, store), searching: query.isNotEmpty)
          else
            ...conversations.map(
              (conversation) => _ConversationTile(
                conversation: conversation,
                onTap: () => _openChat(context, conversation),
                onMenuSelected: (value) => _handleConversationMenu(context, store, conversation, value),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleTopMenu(BuildContext context, RavenStore store, String value) async {
    if (value == 'new_chat') {
      await _showNewChatDialog(context, store);
    } else if (value == 'new_group') {
      await _showNewGroupDialog(context, store);
    } else if (value == 'settings') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SettingsScreen(mode: mode)));
    } else if (value == 'profile') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(mode: mode)));
    } else if (value == 'lock') {
      if (!store.appLockEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('App lock is off. Enable it in Settings > Security & privacy.')),
        );
        return;
      }
      store.lockSession();
      Navigator.of(context).pushReplacementNamed('/lock');
    } else if (value == 'logout') {
      final confirmed = await _confirm(context, 'Log out?', 'You will need your account email and password to enter again.');
      if (!confirmed) return;
      await store.logoutAccount();
      if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  void _openChat(BuildContext context, ConversationData conversation) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          conversationId: conversation.id,
          mode: mode,
        ),
      ),
    );
  }

  Future<void> _handleConversationMenu(
    BuildContext context,
    RavenStore store,
    ConversationData conversation,
    String value,
  ) async {
    if (value == 'view_contact') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactInfoScreen(mode: mode, conversationId: conversation.id)));
    } else if (value == 'group_info') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupInfoScreen(mode: mode, conversationId: conversation.id)));
    } else if (value == 'add_to_group' || value == 'add_members') {
      await _showAddMemberDialog(context, store, conversation.id, modeOverride: mode);
    } else if (value == 'pin') {
      await store.togglePinnedConversation(mode, conversation.id);
    } else if (value == 'clear') {
      final confirmed = await _confirm(context, 'Clear chat?', 'This will remove all messages from this conversation on this device. This cannot be undone.');
      if (confirmed) await store.clearConversation(mode, conversation.id);
    } else if (value == 'delete') {
      final confirmed = await _confirm(context, conversation.isGroup ? 'Delete group?' : 'Delete chat?', 'This will remove it from your chat list on this device. This cannot be undone.');
      if (confirmed) await store.deleteConversation(mode, conversation.id);
    } else if (value == 'block') {
      final confirmed = await _confirm(context, 'Block user?', 'You will no longer receive messages or invites from this user in the final app.');
      if (confirmed) await store.blockConversation(mode, conversation.id);
    } else if (value == 'leave') {
      final confirmed = await _confirm(context, 'Leave group?', 'You will stop receiving messages from this group.');
      if (confirmed) await store.deleteConversation(mode, conversation.id);
    }
  }

  Future<void> _showNewChatDialog(BuildContext context, RavenStore store) async {
    final controller = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('New chat'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 48,
                    decoration: const InputDecoration(
                      labelText: 'Raven ID',
                      hintText: 'rvn_name_8F3A2',
                      counterText: '',
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) async {
                      final result = await store.addConversationWithRavenId(mode, controller.text);
                      if (result != null) {
                        setState(() => error = result);
                        return;
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Backend lookup will later verify whether this ID exists.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final result = await store.addConversationWithRavenId(mode, controller.text);
                    if (result != null) {
                      setState(() => error = result);
                      return;
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Start chat'),
                ),
              ],
            );
          },
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showNewGroupDialog(BuildContext context, RavenStore store) async {
    final groupNameController = TextEditingController();
    final memberController = TextEditingController();
    final members = <String>[];
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void addMember() {
              final memberError = RavenValidation.ravenIdError(memberController.text, ownRavenId: store.vaultFor(mode).ravenId);
              if (memberError != null) {
                setState(() => error = memberError);
                return;
              }
              final clean = memberController.text.trim();
              if (members.any((id) => id.toLowerCase() == clean.toLowerCase())) {
                setState(() => error = 'This member is already in the group.');
                return;
              }
              setState(() {
                members.add(clean);
                memberController.clear();
                error = null;
              });
            }

            return AlertDialog(
              title: const Text('New group'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: groupNameController,
                      autofocus: true,
                      maxLength: 40,
                      decoration: const InputDecoration(labelText: 'Group name', counterText: ''),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: memberController,
                            maxLength: 48,
                            decoration: const InputDecoration(
                              labelText: 'Add member by Raven ID',
                              hintText: 'rvn_name_8F3A2',
                              counterText: '',
                            ),
                            onSubmitted: (_) => addMember(),
                          ),
                        ),
                        IconButton(onPressed: addMember, icon: const Icon(Icons.add_rounded)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (members.isEmpty)
                      Text('No members added yet. You can create the group now and add members later.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: members
                            .map(
                              (id) => InputChip(
                                label: Text(id, overflow: TextOverflow.ellipsis),
                                onDeleted: () => setState(() => members.remove(id)),
                              ),
                            )
                            .toList(),
                      ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final result = await store.addGroupConversation(mode, groupNameController.text, members);
                    if (result != null) {
                      setState(() => error = result);
                      return;
                    }
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Create group'),
                ),
              ],
            );
          },
        );
      },
    );
    groupNameController.dispose();
    memberController.dispose();
  }
}

Future<bool> _confirm(BuildContext context, String title, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
      ],
    ),
  );
  return result ?? false;
}

Future<void> _showAddMemberDialog(BuildContext context, RavenStore store, String conversationId, {VaultMode? modeOverride}) async {
  final mode = modeOverride ?? VaultMode.real;
  final controller = TextEditingController();
  String? error;
  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Add member'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 48,
              decoration: const InputDecoration(labelText: 'Raven ID', hintText: 'rvn_name_8F3A2', counterText: ''),
            ),
            Text('If the user does not allow automatic group adds, the backend will send an invitation instead.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            if (error != null) ...[
              const SizedBox(height: 10),
              Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final result = await store.addGroupMember(mode, conversationId, controller.text);
              if (result != null) {
                setState(() => error = result);
                return;
              }
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.mode});

  final VaultMode mode;

  bool get decoyMode => mode == VaultMode.decoy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: decoyMode ? Colors.orange.withOpacity(0.12) : RavenApp.ravenBlue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        decoyMode ? 'cover mode' : 'main vault',
        style: TextStyle(
          color: decoyMode ? Colors.orange.shade800 : RavenApp.ravenBlue,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.mode});

  final VaultMode mode;

  bool get decoyMode => mode == VaultMode.decoy;

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    final pending = store.vaultFor(mode).pendingMessages;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: RavenApp.ravenBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                decoyMode ? Icons.visibility_off_rounded : Icons.verified_user_rounded,
                color: RavenApp.ravenBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    decoyMode ? 'Cover account active' : 'Main vault unlocked',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    decoyMode
                        ? 'Local encrypted data separated from the main vault. Useful for plausible deniability.'
                        : 'Chats in this vault are locally persisted with encryption in the MVP.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.25),
                  ),
                  if (pending > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$pending message(s) waiting for simulated sync.',
                      style: TextStyle(color: Colors.orange.shade800, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                  if (store.emergencyLocked && decoyMode) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Emergency mode active.',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNewChat, this.searching = false});

  final VoidCallback onNewChat;
  final bool searching;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(searching ? Icons.search_off_rounded : Icons.chat_bubble_outline_rounded, color: Colors.grey.shade500, size: 42),
            const SizedBox(height: 12),
            Text(searching ? 'No results found.' : 'No chats yet', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              searching ? 'Try another name, Raven ID or message preview.' : 'Start a new conversation to begin using Raven.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if (!searching) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onNewChat,
                icon: const Icon(Icons.add_comment_rounded),
                label: const Text('New chat'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.onTap,
    required this.onMenuSelected,
  });

  final ConversationData conversation;
  final VoidCallback onTap;
  final ValueChanged<String> onMenuSelected;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _InitialsAvatar(
                    initials: conversation.initials,
                    color: Color(conversation.colorValue),
                    size: 52,
                  ),
                  if (conversation.unread)
                    Positioned(
                      left: -3,
                      top: 18,
                      child: Container(
                        height: 8,
                        width: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: RavenApp.ravenBlue,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (conversation.pinned) ...[
                          const Icon(Icons.push_pin_rounded, size: 14, color: RavenApp.ravenBlue),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conversation.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.isGroup
                          ? '${conversation.memberRavenIds.length} member${conversation.memberRavenIds.length == 1 ? '' : 's'} • ${conversation.subtitle}'
                          : conversation.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    conversation.timeLabel,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  if (conversation.lastOutgoingStatus != null) ...[
                    const SizedBox(height: 5),
                    Icon(
                      conversation.lastOutgoingStatus!.icon,
                      size: 15,
                      color: conversation.lastOutgoingStatus == MessageDeliveryStatus.pending
                          ? Colors.orange.shade700
                          : RavenApp.ravenBlue,
                    ),
                  ],
                ],
              ),
              PopupMenuButton<String>(
                tooltip: 'Chat options',
                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                onSelected: onMenuSelected,
                itemBuilder: (context) => conversation.isGroup
                    ? [
                        const PopupMenuItem(value: 'group_info', child: Text('Group info')),
                        const PopupMenuItem(value: 'add_members', child: Text('Add members')),
                        PopupMenuItem(value: 'pin', child: Text(conversation.pinned ? 'Unpin chat' : 'Pin chat')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'leave', child: Text('Leave group')),
                        if (conversation.owner) const PopupMenuItem(value: 'delete', child: Text('Delete group')),
                      ]
                    : [
                        const PopupMenuItem(value: 'view_contact', child: Text('View contact')),
                        const PopupMenuItem(value: 'add_to_group', child: Text('Add to group')),
                        PopupMenuItem(value: 'pin', child: Text(conversation.pinned ? 'Unpin chat' : 'Pin chat')),
                        const PopupMenuDivider(),
                        const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                        const PopupMenuItem(value: 'delete', child: Text('Delete chat')),
                        const PopupMenuItem(value: 'block', child: Text('Block user')),
                      ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({
    required this.initials,
    required this.color,
    this.size = 42,
  });

  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.mode,
  });

  final String conversationId;
  final VaultMode mode;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _autoReply = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send(RavenStore store) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (text.length > 4000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Messages must be at most 4000 characters.')));
      return;
    }
    _controller.clear();
    final messageId = await store.addMessage(widget.mode, widget.conversationId, text);
    if (messageId != null) {
      store.simulateMessageDelivery(widget.mode, widget.conversationId, messageId);
    }

    if (_autoReply) {
      await Future.delayed(const Duration(milliseconds: 320));
      await store.addAutomaticReply(widget.mode, widget.conversationId);
    }
  }

  Future<void> _handleMenu(RavenStore store, ConversationData conversation, String value) async {
    if (value == 'view_contact') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ContactInfoScreen(mode: widget.mode, conversationId: conversation.id)));
    } else if (value == 'group_info') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => GroupInfoScreen(mode: widget.mode, conversationId: conversation.id)));
    } else if (value == 'add_to_group' || value == 'add_members') {
      await _showAddMemberDialog(context, store, conversation.id, modeOverride: widget.mode);
    } else if (value == 'pin') {
      await store.togglePinnedConversation(widget.mode, conversation.id);
    } else if (value == 'clear') {
      final confirmed = await _confirm(context, 'Clear chat?', 'This will remove all messages from this conversation on this device. This cannot be undone.');
      if (confirmed) await store.clearConversation(widget.mode, conversation.id);
    } else if (value == 'delete') {
      final confirmed = await _confirm(context, conversation.isGroup ? 'Delete group?' : 'Delete chat?', 'This will remove it from your chat list on this device. This cannot be undone.');
      if (confirmed) {
        await store.deleteConversation(widget.mode, conversation.id);
        if (context.mounted) Navigator.of(context).pop();
      }
    } else if (value == 'block') {
      final confirmed = await _confirm(context, 'Block user?', 'You will no longer receive messages or invites from this user in the final app.');
      if (confirmed) await store.blockConversation(widget.mode, conversation.id);
    } else if (value == 'leave') {
      if (conversation.owner && conversation.memberRavenIds.isEmpty) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Assign an admin first'),
            content: const Text('You must assign another admin before leaving this group.'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
        return;
      }
      final confirmed = await _confirm(context, 'Leave group?', 'You will stop receiving messages from this group.');
      if (confirmed) {
        await store.deleteConversation(widget.mode, conversation.id);
        if (context.mounted) Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    final conversation = store.conversationById(widget.mode, widget.conversationId);

    if (conversation == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: const Center(child: Text('Chat not found.')),
      );
    }

    final contact = store.vaultFor(widget.mode).contactById(conversation.contactId);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _InitialsAvatar(
              initials: conversation.initials,
              color: Color(conversation.colorValue),
              size: 38,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: RavenApp.ravenDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    conversation.isGroup
                        ? '${conversation.memberRavenIds.length} member${conversation.memberRavenIds.length == 1 ? '' : 's'}'
                        : (contact?.effectiveRavenId ?? 'Raven contact'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Chat options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => _handleMenu(store, conversation, value),
            itemBuilder: (context) => conversation.isGroup
                ? [
                    const PopupMenuItem(value: 'group_info', child: Text('Group info')),
                    const PopupMenuItem(value: 'add_members', child: Text('Add members')),
                    PopupMenuItem(value: 'pin', child: Text(conversation.pinned ? 'Unpin chat' : 'Pin chat')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'leave', child: Text('Leave group')),
                    if (conversation.owner) const PopupMenuItem(value: 'delete', child: Text('Delete group')),
                  ]
                : [
                    const PopupMenuItem(value: 'view_contact', child: Text('View contact')),
                    const PopupMenuItem(value: 'add_to_group', child: Text('Add to group')),
                    PopupMenuItem(value: 'pin', child: Text(conversation.pinned ? 'Unpin chat' : 'Pin chat')),
                    const PopupMenuDivider(),
                    const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete chat')),
                    const PopupMenuItem(value: 'block', child: Text('Block user')),
                  ],
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              children: [
                if (conversation.messages.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Text('No messages yet.', style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  )
                else
                  ...conversation.messages.map((message) => _MessageBubble(message: message)),
              ],
            ),
          ),
          _LocalComposer(
            controller: _controller,
            autoReply: _autoReply,
            onAutoReplyChanged: (value) => setState(() => _autoReply = value),
            onSend: () => _send(store),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessageData message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: message.mine ? RavenApp.ravenBlue : const Color(0xFF3D3D3D),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(17),
              topRight: const Radius.circular(17),
              bottomLeft: Radius.circular(message.mine ? 17 : 5),
              bottomRight: Radius.circular(message.mine ? 5 : 17),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
              ),
              if (message.mine) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(message.deliveryStatus.icon, size: 13, color: Colors.white70),
                    const SizedBox(width: 3),
                    Text(
                      message.deliveryStatus.label,
                      style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _LocalComposer extends StatelessWidget {
  const _LocalComposer({
    required this.controller,
    required this.autoReply,
    required this.onAutoReplyChanged,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool autoReply;
  final ValueChanged<bool> onAutoReplyChanged;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Switch(
                  value: autoReply,
                  onChanged: onAutoReplyChanged,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Expanded(
                  child: Text(
                    'Auto-reply to simulate a conversation',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE8E9F2)),
                    ),
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Message...',
                        border: InputBorder.none,
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: FilledButton(
                    onPressed: onSend,
                    style: FilledButton.styleFrom(
                      backgroundColor: RavenApp.ravenBlue,
                      padding: EdgeInsets.zero,
                      shape: const CircleBorder(),
                    ),
                    child: const Icon(Icons.send_rounded, color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key, required this.mode});

  final VaultMode mode;

  bool get decoyMode => mode == VaultMode.decoy;

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    final vault = store.vaultFor(mode);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Contacts'),
            const SizedBox(width: 10),
            _ModeChip(mode: mode),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Novo contato',
            onPressed: () => _showAddContactDialog(context, store),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddContactDialog(context, store),
        backgroundColor: RavenApp.ravenBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Contact'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 88),
        children: [
          _ContactsIntroCard(mode: mode, contactCount: vault.contacts.length),
          const SizedBox(height: 12),
          if (vault.contacts.isEmpty)
            const _EmptyContactsState()
          else
            ...vault.contacts.map(
              (contact) => _ContactTile(
                contact: contact,
                onTap: () => _showContactDetails(context, store, contact),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showAddContactDialog(BuildContext context, RavenStore store) async {
    final nameController = TextEditingController();
    final handleController = TextEditingController();
    final ravenIdController = TextEditingController();
    final noteController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(decoyMode ? 'New cover contact' : 'New main contact'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'Ex.: John, College group',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: handleController,
                decoration: const InputDecoration(
                  labelText: 'Visual identifier',
                  hintText: '@usuario.demo',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ravenIdController,
                decoration: const InputDecoration(
                  labelText: 'Raven ID',
                  hintText: 'rvn_usuario_8F3A2',
                  helperText: 'Can be empty to generate automatically.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: noteController,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Local note',
                  hintText: 'Information only for this environment',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      await store.addContact(
        mode,
        name: nameController.text,
        handle: handleController.text,
        ravenId: ravenIdController.text,
        note: noteController.text,
      );
    }

    nameController.dispose();
    handleController.dispose();
    ravenIdController.dispose();
    noteController.dispose();
  }

  Future<void> _showContactDetails(BuildContext context, RavenStore store, ContactData contact) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _InitialsAvatar(
                  initials: contact.initials,
                  color: Color(contact.colorValue),
                  size: 70,
                ),
                const SizedBox(height: 12),
                Text(
                  contact.name,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(contact.handle, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: RavenApp.ravenBlue.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: RavenApp.ravenBlue.withOpacity(0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.alternate_email_rounded, color: RavenApp.ravenBlue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          contact.effectiveRavenId,
                          style: const TextStyle(fontWeight: FontWeight.w800, color: RavenApp.ravenBlue),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy Raven ID',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: contact.effectiveRavenId));
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(content: Text('Raven ID copied.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                      ),
                    ],
                  ),
                ),
                if (contact.note.trim().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(contact.note, textAlign: TextAlign.center),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () async {
                    final conversationId = await store.startConversationWithContact(mode, contact);
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    if (!context.mounted) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: conversationId,
                          mode: mode,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded),
                  label: const Text('Open chat'),
                ),
                const SizedBox(height: 8),
                Text(
                  decoyMode
                      ? 'This contact exists only in the cover environment.'
                      : 'This contact exists only in the main vault.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContactsIntroCard extends StatelessWidget {
  const _ContactsIntroCard({required this.mode, required this.contactCount});

  final VaultMode mode;
  final int contactCount;

  bool get decoyMode => mode == VaultMode.decoy;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: RavenApp.ravenBlue.withOpacity(0.10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                decoyMode ? Icons.badge_outlined : Icons.contacts_rounded,
                color: RavenApp.ravenBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    decoyMode ? 'Cover environment contacts' : 'Main vault contacts',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$contactCount contacts persisted in this vault, each with a local Raven ID ready for the backend.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.contact, required this.onTap});

  final ContactData contact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: _InitialsAvatar(
          initials: contact.initials,
          color: Color(contact.colorValue),
          size: 48,
        ),
        title: Text(contact.name, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(
          '${contact.effectiveRavenId} • ${contact.note.trim().isEmpty ? contact.handle : contact.note}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _EmptyContactsState extends StatelessWidget {
  const _EmptyContactsState();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(Icons.contacts_outlined, color: Colors.grey.shade500, size: 42),
            const SizedBox(height: 12),
            const Text('No contacts in this environment.', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(
              'Add local contacts to start chats separated by vault.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}


class ContactInfoScreen extends StatelessWidget {
  const ContactInfoScreen({super.key, required this.mode, required this.conversationId});

  final VaultMode mode;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    final conversation = store.conversationById(mode, conversationId);
    if (conversation == null) {
      return Scaffold(appBar: AppBar(title: const Text('Contact')), body: const Center(child: Text('Contact not found.')));
    }
    final contact = store.vaultFor(mode).contactById(conversation.contactId);
    final ravenId = contact?.effectiveRavenId ?? 'rvn_unknown';

    return Scaffold(
      appBar: AppBar(title: const Text('Contact info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  _InitialsAvatar(initials: conversation.initials, color: Color(conversation.colorValue), size: 74),
                  const SizedBox(height: 14),
                  Text(conversation.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  SelectableText(ravenId, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                  if (contact?.note.isNotEmpty ?? false) ...[
                    const SizedBox(height: 12),
                    Text(contact!.note, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileAction(
            icon: Icons.copy_rounded,
            title: 'Copy Raven ID',
            subtitle: ravenId,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: ravenId));
              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raven ID copied.')));
            },
          ),
          _ProfileAction(
            icon: Icons.chat_bubble_rounded,
            title: 'Message',
            subtitle: 'Open this conversation.',
            onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ChatScreen(conversationId: conversationId, mode: mode))),
          ),
          _ProfileAction(
            icon: Icons.group_add_rounded,
            title: 'Add to group',
            subtitle: 'Choose a group later; current MVP opens the add-member flow.',
            onTap: () => _showAddMemberDialog(context, store, conversationId, modeOverride: mode),
          ),
          _ProfileAction(
            icon: Icons.push_pin_rounded,
            title: conversation.pinned ? 'Unpin chat' : 'Pin chat',
            subtitle: 'Keep this chat at the top of the chat list.',
            onTap: () => store.togglePinnedConversation(mode, conversationId),
          ),
          _ProfileAction(
            icon: Icons.block_rounded,
            title: 'Block user',
            subtitle: 'Show a warning before blocking this user.',
            onTap: () async {
              final confirmed = await _confirm(context, 'Block user?', 'You will no longer receive messages or invites from this user in the final app.');
              if (confirmed) await store.blockConversation(mode, conversationId);
            },
          ),
          _ProfileAction(
            icon: Icons.delete_outline_rounded,
            title: 'Delete chat',
            subtitle: 'Show a warning before deleting this chat.',
            onTap: () async {
              final confirmed = await _confirm(context, 'Delete chat?', 'This will remove the conversation from your chat list. This cannot be undone.');
              if (confirmed) {
                await store.deleteConversation(mode, conversationId);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
    );
  }
}

class GroupInfoScreen extends StatelessWidget {
  const GroupInfoScreen({super.key, required this.mode, required this.conversationId});

  final VaultMode mode;
  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    final conversation = store.conversationById(mode, conversationId);
    if (conversation == null) {
      return Scaffold(appBar: AppBar(title: const Text('Group info')), body: const Center(child: Text('Group not found.')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  _InitialsAvatar(initials: conversation.initials, color: Color(conversation.colorValue), size: 74),
                  const SizedBox(height: 14),
                  Text(conversation.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${conversation.memberRavenIds.length} member${conversation.memberRavenIds.length == 1 ? '' : 's'}', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  Text(conversation.owner ? 'You are the owner/admin in this local MVP.' : 'Member', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileAction(
            icon: Icons.edit_rounded,
            title: 'Rename group',
            subtitle: 'Group name max: 40 characters.',
            onTap: () => _showRenameGroupDialog(context, store, conversation),
          ),
          _ProfileAction(
            icon: Icons.person_add_rounded,
            title: 'Add members',
            subtitle: 'Add by Raven ID or send an invitation later.',
            onTap: () => _showAddMemberDialog(context, store, conversationId, modeOverride: mode),
          ),
          _ProfileAction(
            icon: Icons.push_pin_rounded,
            title: conversation.pinned ? 'Unpin chat' : 'Pin chat',
            subtitle: 'Keep this group at the top of the chat list.',
            onTap: () => store.togglePinnedConversation(mode, conversationId),
          ),
          const SizedBox(height: 8),
          const _SettingsSectionTitle('Members'),
          if (conversation.memberRavenIds.isEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.group_outlined),
                title: const Text('No members added yet'),
                subtitle: const Text('You can create the group first and invite people later.'),
              ),
            )
          else
            ...conversation.memberRavenIds.map(
              (id) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: _InitialsAvatar(initials: 'R', color: RavenApp.ravenBlue, size: 42),
                  title: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('Member'),
                  trailing: IconButton(
                    tooltip: 'Copy Raven ID',
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: id));
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raven ID copied.')));
                    },
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          _ProfileAction(
            icon: Icons.logout_rounded,
            title: 'Leave group',
            subtitle: conversation.owner && conversation.memberRavenIds.isEmpty
                ? 'Assign another admin before leaving.'
                : 'Show a warning before leaving this group.',
            onTap: () async {
              if (conversation.owner && conversation.memberRavenIds.isEmpty) {
                await showDialog<void>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Assign an admin first'),
                    content: const Text('You must assign another admin before leaving this group.'),
                    actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                  ),
                );
                return;
              }
              final confirmed = await _confirm(context, 'Leave group?', 'You will stop receiving messages from this group.');
              if (confirmed) {
                await store.deleteConversation(mode, conversationId);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
          if (conversation.owner)
            _ProfileAction(
              icon: Icons.delete_forever_rounded,
              title: 'Delete group',
              subtitle: 'Only owner/admin can delete the group.',
              onTap: () async {
                final confirmed = await _confirm(context, 'Delete group?', 'This will delete the group locally in this MVP. This cannot be undone.');
                if (confirmed) {
                  await store.deleteConversation(mode, conversationId);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showRenameGroupDialog(BuildContext context, RavenStore store, ConversationData conversation) async {
    final controller = TextEditingController(text: conversation.name);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rename group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Group name', counterText: ''),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final result = await store.renameGroup(mode, conversation.id, controller.text);
                if (result != null) {
                  setState(() => error = result);
                  return;
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.mode});

  final VaultMode mode;

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    final vault = store.vaultFor(mode);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: _InitialsAvatar(
                initials: vault.avatarInitials,
                color: mode == VaultMode.decoy ? const Color(0xFF667085) : RavenApp.ravenBlue,
                size: 48,
              ),
              title: Text(vault.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(vault.ravenId, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(mode: mode))),
            ),
          ),
          const SizedBox(height: 16),
          const _SettingsSectionTitle('Account'),
          _SettingsTile(
            icon: Icons.person_rounded,
            title: 'Profile',
            subtitle: 'Display name, Raven ID and local profile details.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProfileScreen(mode: mode))),
          ),
          _SettingsTile(
            icon: Icons.alternate_email_rounded,
            title: 'Change account email',
            subtitle: store.accountEmail.isEmpty ? 'No local account email.' : store.accountEmail,
            onTap: () => _changeEmailDialog(context, store),
          ),
          _SettingsTile(
            icon: Icons.password_rounded,
            title: 'Change account password',
            subtitle: 'Planned for backend account management.',
            status: 'Later',
            onTap: () => _infoDialog(context, 'Change account password', 'This will be implemented with the backend account system.'),
          ),
          _SettingsTile(
            icon: Icons.delete_sweep_rounded,
            title: 'Delete all chats/groups data',
            subtitle: 'Deletes local conversations, groups and messages in this profile.',
            destructive: true,
            onTap: () async {
              final confirmed = await _confirm(context, 'Delete all chats/groups data?', 'This will delete all local conversations, groups, and messages from this profile on this device. This cannot be undone.');
              if (confirmed) {
                await store.deleteAllChatsAndGroups(mode);
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chats and groups deleted.')));
              }
            },
          ),
          _SettingsTile(
            icon: Icons.no_accounts_rounded,
            title: 'Delete account',
            subtitle: 'Planned destructive backend action.',
            status: 'Later',
            destructive: true,
            onTap: () => _infoDialog(context, 'Delete account', 'This will permanently delete the Raven account in a future backend version.'),
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Security & privacy'),
          _SettingsTile(
            icon: store.appLockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
            title: 'Security & privacy',
            subtitle: store.appLockEnabled ? 'Local lock is enabled.' : 'Local lock is off by default.',
            status: store.appLockEnabled ? 'On' : 'Off',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SecurityScreen(mode: mode))),
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Appearance'),
          _SettingsTile(
            icon: Icons.palette_rounded,
            title: 'Theme',
            subtitle: 'System, dark and light themes are planned.',
            status: 'Later',
            onTap: () => _infoDialog(context, 'Appearance', 'Future versions can include theme controls. Disguised icon stays under Security & privacy because it is a concealment feature.'),
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Notifications'),
          _SettingsTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: store.hideMessagePreviews ? 'Message previews are hidden.' : 'Message previews are visible.',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => SecurityScreen(mode: mode))),
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Help / About'),
          _SettingsTile(
            icon: Icons.help_outline_rounded,
            title: 'Help / About',
            subtitle: 'Raven MVP and threat-model notes.',
            onTap: () => _infoDialog(
              context,
              'About Raven',
              'Raven is a messaging app concept for privacy under pressure. This MVP demonstrates onboarding, local encrypted vaults, cover mode and emergency behavior before the backend is added.',
            ),
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Session'),
          _SettingsTile(
            icon: Icons.lock_outline_rounded,
            title: 'Lock app',
            subtitle: store.appLockEnabled ? 'Close the vault and require a local PIN.' : 'Enable local lock first in Security & privacy.',
            onTap: () {
              if (!store.appLockEnabled) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('App lock is off. Enable it in Security & privacy.')),
                );
                return;
              }
              store.lockSession();
              Navigator.of(context).pushReplacementNamed('/lock');
            },
          ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Log out',
            subtitle: 'Leave the account session and return to login.',
            destructive: true,
            onTap: () async {
              final confirmed = await _confirm(context, 'Log out?', 'You will need your account email and password to enter again.');
              if (!confirmed) return;
              await store.logoutAccount();
              if (context.mounted) Navigator.of(context).pushReplacementNamed('/login');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _changeEmailDialog(BuildContext context, RavenStore store) async {
    final controller = TextEditingController(text: store.accountEmail);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Change account email'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: controller,
                keyboardType: TextInputType.emailAddress,
                maxLength: 254,
                decoration: const InputDecoration(labelText: 'New email', counterText: ''),
              ),
              Text('Backend version will require account password and email verification code.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final result = await store.updateAccountEmail(controller.text);
                if (result != null) {
                  setState(() => error = result);
                  return;
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _infoDialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.status,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? Colors.red.shade700 : RavenApp.ravenBlue;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: destructive ? color : null)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(subtitle, style: const TextStyle(height: 1.2)),
        ),
        trailing: status == null
            ? const Icon(Icons.chevron_right_rounded)
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  status!,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
      ),
    );
  }
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key, required this.mode});

  final VaultMode mode;

  bool get decoyMode => mode == VaultMode.decoy;

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Security & privacy')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        children: [
          _HeroSecurityCard(mode: mode),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Access lock'),
          _SecurityTile(
            icon: store.appLockEnabled ? Icons.lock_rounded : Icons.lock_open_rounded,
            title: 'Require PIN on app open',
            subtitle: 'When enabled, Raven asks for a 6-digit local PIN before opening.',
            status: store.appLockEnabled ? 'On' : 'Off',
            onTap: () => _showAppLockDialog(context, store),
          ),
          _SecurityTile(
            icon: Icons.password_rounded,
            title: 'Change Main / Cover / Emergency PINs',
            subtitle: 'PINs must be 6 digits, different, confirmed and not obvious.',
            status: '6 digits',
            onTap: () => _showPinDialog(context, store),
          ),
          _SecuritySwitchTile(
            icon: Icons.mark_email_read_rounded,
            title: 'Allow PIN recovery via email',
            subtitle: 'If enabled before you forget the PIN, account password + email verification can recover chats.',
            value: store.pinRecoveryEnabled,
            onChanged: (value) => store.updateSecuritySettings(pinRecoveryEnabled: value),
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Privacy'),
          _SecuritySwitchTile(
            icon: Icons.online_prediction_rounded,
            title: 'Show online status',
            subtitle: 'Allow others to see when you are online. Later this may be symmetrical.',
            value: store.showOnlineStatus,
            onChanged: (value) => store.updateSecuritySettings(showOnlineStatus: value),
          ),
          _SecuritySwitchTile(
            icon: Icons.done_all_rounded,
            title: 'Read receipts',
            subtitle: 'Allow others to see when you read messages. Later this may be symmetrical.',
            value: store.readReceiptsEnabled,
            onChanged: (value) => store.updateSecuritySettings(readReceiptsEnabled: value),
          ),
          _SecuritySwitchTile(
            icon: Icons.visibility_off_rounded,
            title: 'Hide message previews',
            subtitle: 'Notifications should show generic text only.',
            value: store.hideMessagePreviews,
            onChanged: (value) => store.updateSecuritySettings(hideMessagePreviews: value),
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Coercion protection'),
          _SecurityTile(
            icon: Icons.warning_amber_rounded,
            title: 'Emergency behavior',
            subtitle: 'Default MVP behavior: emergency PIN opens the cover profile and locks the main profile.',
            status: store.emergencyLocked ? 'Active' : 'Ready',
            onTap: () => _emergencyDialog(context, store),
          ),
          _SecurityTile(
            icon: Icons.restore_rounded,
            title: 'Reset cover profile',
            subtitle: 'Restore the cover environment to default demo data.',
            status: 'Local',
            onTap: () async {
              final confirmed = await _confirm(context, 'Reset cover profile?', 'This restores the cover profile, contacts and chats to the default state.');
              if (confirmed) await store.resetEnvironment(VaultMode.decoy);
            },
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Group privacy'),
          _SecurityTile(
            icon: Icons.group_add_rounded,
            title: 'Who can add me to groups?',
            subtitle: _groupPolicyLabel(store.groupAddPolicy),
            status: 'Group',
            onTap: () => _groupPolicyDialog(context, store),
          ),
          const SizedBox(height: 12),
          const _SettingsSectionTitle('Concealment'),
          _SecurityTile(
            icon: Icons.app_shortcut_rounded,
            title: 'Disguised app icon',
            subtitle: 'Allows changing the external appearance of the app.',
            status: 'Later',
            onTap: () => _featureDialog(context, 'Disguised app icon'),
          ),
          _WarningCard(
            text:
                'Progressive cooldowns are always active internally and cannot be disabled. Destructive emergency actions are not enabled by default.',
          ),
        ],
      ),
    );
  }

  String _groupPolicyLabel(String policy) {
    switch (policy) {
      case 'everyone':
        return 'Everyone can add you to groups automatically.';
      case 'contacts':
        return 'Only contacts can add you automatically. Others send invites.';
      case 'invite':
      default:
        return 'Require invitation before joining groups.';
    }
  }

  Future<void> _groupPolicyDialog(BuildContext context, RavenStore store) async {
    var value = store.groupAddPolicy;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Who can add me to groups?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'everyone',
                groupValue: value,
                onChanged: (v) => setState(() => value = v ?? value),
                title: const Text('Everyone'),
                subtitle: const Text('Users can add you directly.'),
              ),
              RadioListTile<String>(
                value: 'contacts',
                groupValue: value,
                onChanged: (v) => setState(() => value = v ?? value),
                title: const Text('My contacts'),
                subtitle: const Text('Unknown users send an invitation.'),
              ),
              RadioListTile<String>(
                value: 'invite',
                groupValue: value,
                onChanged: (v) => setState(() => value = v ?? value),
                title: const Text('Require invitation'),
                subtitle: const Text('No one adds you automatically.'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                await store.updateSecuritySettings(groupAddPolicy: value);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAppLockDialog(BuildContext context, RavenStore store) async {
    final decoyVault = store.vaultFor(VaultMode.decoy);
    final realController = TextEditingController(text: store.appLockEnabled ? '' : '258000');
    final realConfirmController = TextEditingController(text: store.appLockEnabled ? '' : '258000');
    final decoyController = TextEditingController(text: store.appLockEnabled ? '' : '135790');
    final decoyConfirmController = TextEditingController(text: store.appLockEnabled ? '' : '135790');
    final emergencyController = TextEditingController(text: store.appLockEnabled ? '' : '864209');
    final emergencyConfirmController = TextEditingController(text: store.appLockEnabled ? '' : '864209');
    final coverNameController = TextEditingController(text: decoyVault.displayName);
    final coverEmailController = TextEditingController(text: decoyVault.email);
    final coverAboutController = TextEditingController(text: decoyVault.about);
    var enabled = store.appLockEnabled;
    var step = 0;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget stepBody;
            if (!enabled) {
              stepBody = const Text(
                'Local lock is disabled. Raven will open after account login without asking for a vault PIN.',
                style: TextStyle(height: 1.25),
              );
            } else if (step == 0) {
              stepBody = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 1 of 3: choose three different 6-digit PINs.', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  _PinField(controller: realController, label: 'Main PIN'),
                  const SizedBox(height: 10),
                  _PinField(controller: realConfirmController, label: 'Confirm main PIN'),
                  const SizedBox(height: 10),
                  _PinField(controller: decoyController, label: 'Cover PIN'),
                  const SizedBox(height: 10),
                  _PinField(controller: decoyConfirmController, label: 'Confirm cover PIN'),
                  const SizedBox(height: 10),
                  _PinField(controller: emergencyController, label: 'Emergency PIN'),
                  const SizedBox(height: 10),
                  _PinField(controller: emergencyConfirmController, label: 'Confirm emergency PIN'),
                  const SizedBox(height: 8),
                  Text(
                    'Weak patterns such as repeated or sequential PINs are rejected. Cooldowns start after repeated failures.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.25),
                  ),
                ],
              );
            } else if (step == 1) {
              stepBody = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 2 of 3: make the cover account plausible.', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: coverNameController,
                    decoration: const InputDecoration(labelText: 'Cover display name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: coverEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Cover email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: coverAboutController,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Cover bio / note', border: OutlineInputBorder()),
                  ),
                ],
              );
            } else {
              stepBody = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Step 3 of 3: review the behavior.', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  _WizardReviewRow(icon: Icons.lock_rounded, title: 'Main PIN', text: 'opens the main vault'),
                  _WizardReviewRow(icon: Icons.theater_comedy_rounded, title: 'Cover PIN', text: 'opens the cover account'),
                  _WizardReviewRow(icon: Icons.warning_amber_rounded, title: 'Emergency PIN', text: 'opens cover mode and locks the real vault in the MVP'),
                  _WizardReviewRow(icon: Icons.timer_rounded, title: 'Failed attempts', text: 'trigger progressive cooldowns'),
                ],
              );
            }

            return AlertDialog(
              title: const Text('Local lock setup'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: enabled,
                      onChanged: (value) => setState(() {
                        enabled = value;
                        step = 0;
                        error = null;
                      }),
                      title: const Text('Require PIN on app open'),
                      subtitle: const Text('Disabled by default. Enable when the user wants local coercion protection.'),
                    ),
                    const SizedBox(height: 8),
                    stepBody,
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                if (enabled && step > 0)
                  TextButton(onPressed: () => setState(() => step -= 1), child: const Text('Back')),
                FilledButton(
                  onPressed: () async {
                    if (!enabled) {
                      final result = await store.configureAppLock(enabled: false, realPin: '', decoyPin: '', emergencyPin: '');
                      if (result != null) {
                        setState(() => error = result);
                        return;
                      }
                      if (context.mounted) Navigator.pop(context);
                      return;
                    }

                    final realPin = realController.text.trim();
                    final realConfirm = realConfirmController.text.trim();
                    final decoyPin = decoyController.text.trim();
                    final decoyConfirm = decoyConfirmController.text.trim();
                    final emergencyPin = emergencyController.text.trim();
                    final emergencyConfirm = emergencyConfirmController.text.trim();

                    if (step == 0) {
                      if (realPin != realConfirm || decoyPin != decoyConfirm || emergencyPin != emergencyConfirm) {
                        setState(() => error = 'PIN confirmation does not match.');
                        return;
                      }
                      final pinError = store.validateAccessPinSet(
                        realPin: realPin,
                        decoyPin: decoyPin,
                        emergencyPin: emergencyPin,
                      );
                      if (pinError != null) {
                        setState(() => error = pinError);
                        return;
                      }
                      setState(() {
                        error = null;
                        step = 1;
                      });
                      return;
                    }

                    if (step == 1) {
                      if (coverNameController.text.trim().isEmpty || !coverEmailController.text.trim().contains('@')) {
                        setState(() => error = 'Enter a plausible cover name and email.');
                        return;
                      }
                      setState(() {
                        error = null;
                        step = 2;
                      });
                      return;
                    }

                    final result = await store.configureAppLock(
                      enabled: true,
                      realPin: realPin,
                      decoyPin: decoyPin,
                      emergencyPin: emergencyPin,
                    );
                    if (result != null) {
                      setState(() => error = result);
                      return;
                    }

                    final profileResult = await store.updateProfile(
                      VaultMode.decoy,
                      displayName: coverNameController.text.trim(),
                      email: coverEmailController.text.trim(),
                      about: coverAboutController.text.trim(),
                    );
                    if (profileResult != null) {
                      setState(() => error = profileResult);
                      return;
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(!enabled ? 'Save' : step < 2 ? 'Next' : 'Finish setup'),
                ),
              ],
            );
          },
        );
      },
    );

    realController.dispose();
    realConfirmController.dispose();
    decoyController.dispose();
    decoyConfirmController.dispose();
    emergencyController.dispose();
    emergencyConfirmController.dispose();
    coverNameController.dispose();
    coverEmailController.dispose();
    coverAboutController.dispose();
  }

  Future<void> _showPinDialog(BuildContext context, RavenStore store) async {
    final currentReal = TextEditingController();
    final currentDecoy = TextEditingController();
    final currentEmergency = TextEditingController();
    final newReal = TextEditingController();
    final newRealConfirm = TextEditingController();
    final newDecoy = TextEditingController();
    final newDecoyConfirm = TextEditingController();
    final newEmergency = TextEditingController();
    final newEmergencyConfirm = TextEditingController();

    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change PINs'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'To re-encrypt the vaults, enter the current PINs and then choose the new ones.',
                      style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                    ),
                    const SizedBox(height: 14),
                    const Text('Current PINs', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    _PinField(controller: currentReal, label: 'Current main PIN'),
                    const SizedBox(height: 10),
                    _PinField(controller: currentDecoy, label: 'Current cover PIN'),
                    const SizedBox(height: 10),
                    _PinField(controller: currentEmergency, label: 'Current emergency PIN'),
                    const SizedBox(height: 16),
                    const Text('New PINs', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    _PinField(controller: newReal, label: 'New main PIN'),
                    const SizedBox(height: 10),
                    _PinField(controller: newRealConfirm, label: 'Confirm new main PIN'),
                    const SizedBox(height: 10),
                    _PinField(controller: newDecoy, label: 'New cover PIN'),
                    const SizedBox(height: 10),
                    _PinField(controller: newDecoyConfirm, label: 'Confirm new cover PIN'),
                    const SizedBox(height: 10),
                    _PinField(controller: newEmergency, label: 'New emergency PIN'),
                    const SizedBox(height: 10),
                    _PinField(controller: newEmergencyConfirm, label: 'Confirm new emergency PIN'),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (newReal.text.trim() != newRealConfirm.text.trim() ||
                        newDecoy.text.trim() != newDecoyConfirm.text.trim() ||
                        newEmergency.text.trim() != newEmergencyConfirm.text.trim()) {
                      setState(() => error = 'PIN confirmation does not match.');
                      return;
                    }

                    final result = await store.updatePins(
                      currentRealPin: currentReal.text.trim(),
                      currentDecoyPin: currentDecoy.text.trim(),
                      currentEmergencyPin: currentEmergency.text.trim(),
                      newRealPin: newReal.text.trim(),
                      newDecoyPin: newDecoy.text.trim(),
                      newEmergencyPin: newEmergency.text.trim(),
                    );

                    if (result != null) {
                      setState(() => error = result);
                      return;
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    currentReal.dispose();
    currentDecoy.dispose();
    currentEmergency.dispose();
    newReal.dispose();
    newRealConfirm.dispose();
    newDecoy.dispose();
    newDecoyConfirm.dispose();
    newEmergency.dispose();
    newEmergencyConfirm.dispose();
  }

  void _featureDialog(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
          'This screen demonstrates the local MVP flow. The final implementation should use audited cryptography, secure key storage and careful threat-model validation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
  }

  void _emergencyDialog(BuildContext context, RavenStore store) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency mode'),
        content: Text(
          store.emergencyLocked
              ? 'Emergency mode is active in this demo. You can restore it to keep testing the main vault.'
              : 'Enter the emergency PIN on the lock screen to block the main vault and open the cover environment.',
        ),
        actions: [
          if (store.emergencyLocked)
            TextButton(
              onPressed: () async {
                await store.clearEmergencyLock();
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Disable in demo'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}


class _WizardReviewRow extends StatelessWidget {
  const _WizardReviewRow({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: RavenApp.ravenBlue, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style.copyWith(height: 1.25),
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.w900)),
                  TextSpan(text: text),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinField extends StatelessWidget {
  const _PinField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      obscureText: true,
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _HeroSecurityCard extends StatelessWidget {
  const _HeroSecurityCard({required this.mode});

  final VaultMode mode;

  bool get decoyMode => mode == VaultMode.decoy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: RavenApp.ravenBlue,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_rounded, color: Colors.white, size: 34),
          const SizedBox(height: 18),
          Text(
            decoyMode ? 'Cover environment running' : 'Protection against physical coercion',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            decoyMode
                ? 'The app looks ordinary, but the displayed data belongs to the cover account.'
                : 'Raven now has separated local data, configurable PINs and a persistent emergency flow.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.78),
              fontSize: 14,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _SecuritySwitchTile extends StatelessWidget {
  const _SecuritySwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        secondary: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: RavenApp.ravenBlue.withOpacity(0.09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: RavenApp.ravenBlue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle, style: const TextStyle(height: 1.2)),
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        leading: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: RavenApp.ravenBlue.withOpacity(0.09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: RavenApp.ravenBlue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(subtitle, style: const TextStyle(height: 1.2)),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: RavenApp.ravenBlue.withOpacity(0.08),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(
            status,
            style: const TextStyle(
              color: RavenApp.ravenBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.amber.withOpacity(0.40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Colors.amber.shade900),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.amber.shade900, height: 1.25, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.mode});

  final VaultMode mode;

  bool get decoyMode => mode == VaultMode.decoy;

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    final vault = store.vaultFor(mode);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InitialsAvatar(
                    initials: vault.avatarInitials,
                    color: decoyMode ? const Color(0xFF667085) : RavenApp.ravenBlue,
                    size: 78,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    vault.displayName,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    vault.email,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: RavenApp.ravenBlue.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.alternate_email_rounded, size: 17, color: RavenApp.ravenBlue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vault.ravenId,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: RavenApp.ravenBlue, fontWeight: FontWeight.w800),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Copy my Raven ID',
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: vault.ravenId));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Your Raven ID was copied.')),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FA),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      vault.about,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileMetric(
                          label: 'Chats',
                          value: '${vault.conversations.length}',
                          icon: Icons.chat_bubble_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileMetric(
                          label: 'Contacts',
                          value: '${vault.contacts.length}',
                          icon: Icons.contacts_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ProfileAction(
            icon: Icons.edit_rounded,
            title: 'Edit current profile',
            subtitle: 'Changes the name, email and description shown in this profile.',
            onTap: () => _showEditProfileDialog(context, store, vault),
          ),
          _ProfileAction(
            icon: Icons.logout_rounded,
            title: 'Log out / lock app',
            subtitle: 'Clears the in-memory session and returns to login or PIN lock.',
            onTap: () {
              store.lockSession();
              Navigator.of(context).pushReplacementNamed(store.appLockEnabled ? '/lock' : '/login');
            },
          ),
          _ProfileAction(
            icon: Icons.restore_rounded,
            title: 'Restore full demo',
            subtitle: 'Recreates default chats/contacts and resets demo PINs to 258000, 000000 and 999999.',
            onTap: () => _confirmResetDemo(context, store),
          ),
          _ProfileAction(
            icon: Icons.delete_sweep_rounded,
            title: 'Reset current profile data',
            subtitle: 'Recreates the default profile, contacts and chats for the current profile.',
            onTap: () => _confirmResetEnvironment(context, store),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context, RavenStore store, VaultData vault) async {
    final nameController = TextEditingController(text: vault.displayName);
    final emailController = TextEditingController(text: vault.email);
    final aboutController = TextEditingController(text: vault.about);
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit current profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Display name'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: 'Demo email'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: aboutController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Local description'),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final result = await store.updateProfile(
                      mode,
                      displayName: nameController.text,
                      email: emailController.text,
                      about: aboutController.text,
                    );

                    if (result != null) {
                      setState(() => error = result);
                      return;
                    }

                    if (context.mounted) Navigator.pop(context);
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    emailController.dispose();
    aboutController.dispose();
  }

  Future<void> _confirmResetDemo(BuildContext context, RavenStore store) async {
    final confirmed = await _confirm(
      context,
      title: 'Restore demo?',
      message: 'This deletes locally created chats and contacts and restores the initial demo data.',
    );
    if (confirmed) {
      await store.resetDemo();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demo restored. Log in again.')),
        );
        Navigator.of(context).pushReplacementNamed(store.appLockEnabled ? '/lock' : '/login');
      }
    }
  }

  Future<void> _confirmResetEnvironment(BuildContext context, RavenStore store) async {
    final confirmed = await _confirm(
      context,
      title: 'Reset environment?',
      message: 'Only this environment profile, contacts and chats will be restored to the default state.',
    );
    if (confirmed) {
      await store.resetEnvironment(mode);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Environment restored.')),
        );
      }
    }
  }

  Future<bool> _confirm(BuildContext context, {required String title, required String message}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: RavenApp.ravenBlue),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ProfileAction extends StatelessWidget {
  const _ProfileAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: RavenApp.ravenBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
