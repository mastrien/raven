part of raven_app;

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
  final RavenApiClient _apiClient = RavenApiClient();

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
  bool get isLoggedIn => (_account?.sessionToken ?? '').isNotEmpty;
  bool get appLockEnabled => _settings.appLockEnabled;
  String get accountEmail => _account?.email ?? '';
  String get accountDisplayName => _account?.displayName ?? 'Raven User';
  String get accountRavenId => _account?.ravenId ?? '';
  String get sessionToken => _account?.sessionToken ?? '';
  bool get pinRecoveryEnabled => _settings.pinRecoveryEnabled;
  bool get emergencyPinEnabled => _settings.emergencyPinEnabled;
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

  String _apiErrorMessage(Object error) {
    if (error is RavenApiException) return error.message;
    return 'Unexpected Raven backend error.';
  }

  Future<String?> beginAccountRegistration({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName.trim().isEmpty ? 'Raven User' : displayName.trim();
    if (!RavenValidation.isValidEmail(cleanEmail)) return 'Enter a valid email address.';
    if (password.isEmpty) return 'Account password is required.';
    if (password.length < 8) return 'Use at least 8 characters for the account password.';
    if (password.length > 128) return 'Account password must be at most 128 characters.';
    if (_account != null && _account!.created && _account!.email.toLowerCase() == cleanEmail) {
      return 'This email is already in use on this device.';
    }

    try {
      await _apiClient.register(email: cleanEmail, password: password, displayName: cleanName);
      return null;
    } catch (error) {
      return _apiErrorMessage(error);
    }
  }

  Future<String?> registerAccount({
    required String email,
    required String password,
    required String displayName,
    required String code,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = displayName.trim().isEmpty ? 'Raven User' : displayName.trim();
    if (!RavenValidation.isValidEmail(cleanEmail)) return 'Enter a valid email address.';
    if (password.isEmpty) return 'Account password is required.';
    if (password.length < 8) return 'Use at least 8 characters for the account password.';
    if (password.length > 128) return 'Account password must be at most 128 characters.';
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) return 'Enter the 6-digit verification code.';

    late final RavenAuthApiResponse response;
    try {
      response = await _apiClient.verifyEmail(email: cleanEmail, code: code.trim());
    } catch (error) {
      return _apiErrorMessage(error);
    }

    final apiUser = response.user;
    _account = RavenAccountState(
      created: true,
      email: cleanEmail,
      displayName: apiUser.displayName.isEmpty ? cleanName : apiUser.displayName,
      passwordVerifier: await PinVerifier.create(password, _deriveKeyBytes),
      emailVerified: apiUser.emailVerified,
      ravenId: apiUser.ravenId,
      sessionToken: response.sessionToken ?? '',
    );
    await _saveAccount();
    await openDefaultSession();
    final unlockedReal = _unlockedVaults[VaultMode.real];
    if (unlockedReal != null) {
      await _replaceVault(
        VaultMode.real,
        unlockedReal.copyWith(
          displayName: _account!.displayName,
          email: cleanEmail,
          about: 'Protected by Raven.',
          ravenId: apiUser.ravenId.isEmpty ? unlockedReal.ravenId : apiUser.ravenId,
        ),
      );
    }
    notifyListeners();
    return null;
  }

  Future<String?> loginAccount({required String email, required String password}) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!RavenValidation.isValidEmail(cleanEmail)) return 'Enter a valid email address.';
    if (password.isEmpty) return 'Account password is required.';
    if (password.length > 128) return 'Account password must be at most 128 characters.';

    late final RavenAuthApiResponse response;
    try {
      response = await _apiClient.login(email: cleanEmail, password: password);
    } catch (error) {
      return _apiErrorMessage(error);
    }

    final apiUser = response.user;
    _account = RavenAccountState(
      created: true,
      email: cleanEmail,
      displayName: apiUser.displayName.isEmpty ? 'Raven User' : apiUser.displayName,
      passwordVerifier: await PinVerifier.create(password, _deriveKeyBytes),
      emailVerified: apiUser.emailVerified,
      ravenId: apiUser.ravenId,
      sessionToken: response.sessionToken ?? '',
    );
    await _saveAccount();

    if (!_settings.appLockEnabled) {
      await openDefaultSession();
      final unlockedReal = _unlockedVaults[VaultMode.real];
      if (unlockedReal != null && apiUser.ravenId.isNotEmpty) {
        await _replaceVault(
          VaultMode.real,
          unlockedReal.copyWith(
            displayName: apiUser.displayName,
            email: cleanEmail,
            ravenId: apiUser.ravenId,
          ),
        );
      }
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
    final account = _account;
    if (account != null) {
      _account = account.copyWith(sessionToken: '');
      await _saveAccount();
    }
    notifyListeners();
  }

  Future<String?> configureAppLock({
    required bool enabled,
    required String realPin,
    required String decoyPin,
    required String emergencyPin,
    bool emergencyPinEnabled = true,
  }) async {
    if (!enabled) {
      _settings = _settings.copyWith(appLockEnabled: false, emergencyPinEnabled: false);
      await _saveSettings();
      notifyListeners();
      return null;
    }

    final pinError = validateAccessPinSet(
      realPin: realPin,
      decoyPin: decoyPin,
      emergencyPin: emergencyPinEnabled ? emergencyPin : null,
    );
    if (pinError != null) return pinError;

    final persistent = _persistent;
    if (persistent == null) return 'Local state is not ready yet.';

    try {
      final realKey = _vaultKeys[VaultMode.real] ?? await _decryptBytesWithPin(persistent.realKeyWrap, _settings.autoRealPin);
      final decoyKey = _vaultKeys[VaultMode.decoy] ?? await _decryptBytesWithPin(persistent.decoyKeyWrap, _settings.autoDecoyPin);

      final effectiveEmergencyPin = emergencyPinEnabled ? emergencyPin : _newId('disabled_emergency_pin');
      _persistent = persistent.copyWith(
        credentials: await PinCredentials.create(
          realPin: realPin,
          decoyPin: decoyPin,
          emergencyPin: effectiveEmergencyPin,
          deriveKeyBytes: _deriveKeyBytes,
        ),
        realKeyWrap: await _encryptBytesWithPin(realKey, realPin),
        decoyKeyWrap: await _encryptBytesWithPin(decoyKey, decoyPin),
        emergencyDecoyKeyWrap: await _encryptBytesWithPin(decoyKey, effectiveEmergencyPin),
      );
      _settings = _settings.copyWith(
        appLockEnabled: true,
        emergencyPinEnabled: emergencyPinEnabled,
        autoRealPin: realPin,
        autoDecoyPin: decoyPin,
        autoEmergencyPin: emergencyPinEnabled ? emergencyPin : '',
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
    bool? emergencyPinEnabled,
    bool? showOnlineStatus,
    bool? readReceiptsEnabled,
    bool? hideMessagePreviews,
    String? groupAddPolicy,
  }) async {
    _settings = _settings.copyWith(
      pinRecoveryEnabled: pinRecoveryEnabled,
      emergencyPinEnabled: emergencyPinEnabled,
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
    String? emergencyPin,
  }) {
    final pins = <String>[realPin, decoyPin, if (emergencyPin != null && emergencyPin.isNotEmpty) emergencyPin];
    if (!pins.every((value) => RegExp(r'^\d{6}$').hasMatch(value))) {
      return emergencyPin == null || emergencyPin.isEmpty
          ? 'Use exactly 6 digits for the main and cover PINs.'
          : 'Use exactly 6 digits for each enabled PIN.';
    }
    if (pins.toSet().length != pins.length) {
      return emergencyPin == null || emergencyPin.isEmpty
          ? 'Main and cover PINs must be different.'
          : 'Main, cover and emergency PINs must be different.';
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

    if (_settings.emergencyPinEnabled && await persistent.credentials.emergency.verify(pin, _deriveKeyBytes)) {
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
    String? avatarUrl,
  }) async {
    final trimmedName = displayName.trim();
    final trimmedEmail = email.trim();
    final trimmedAbout = about.trim();

    final nameError = RavenValidation.displayNameError(trimmedName);
    if (nameError != null) return nameError;
    if (!RavenValidation.isValidEmail(trimmedEmail)) return 'Enter a valid email address for the demo.';
    if (trimmedAbout.length > 160) return 'Bio/status must be at most 160 characters.';
    final photoError = RavenValidation.optionalPhotoUrlError(avatarUrl ?? '');
    if (photoError != null) return photoError;

    var effectiveName = trimmedName;
    if (mode == VaultMode.real && sessionToken.isNotEmpty) {
      try {
        final apiUser = await _apiClient.updateMyProfile(sessionToken: sessionToken, displayName: trimmedName);
        if (apiUser.displayName.trim().isNotEmpty) effectiveName = apiUser.displayName.trim();
        final account = _account;
        if (account != null) {
          _account = account.copyWith(displayName: effectiveName);
          await _saveAccount();
        }
      } catch (error) {
        return _apiErrorMessage(error);
      }
    }

    final currentVault = vaultFor(mode);
    await _replaceVault(
      mode,
      currentVault.copyWith(
        displayName: effectiveName,
        email: trimmedEmail,
        about: trimmedAbout.isEmpty ? 'Protected by Raven.' : trimmedAbout,
        avatarUrl: avatarUrl?.trim(),
      ),
    );
    notifyListeners();
    return null;
  }


  Future<String?> updateContactAlias(VaultMode mode, String contactId, String alias) async {
    final cleanAlias = alias.trim();
    final nameError = RavenValidation.displayNameError(cleanAlias);
    if (nameError != null) return nameError;
    final currentVault = vaultFor(mode);
    final updatedContacts = currentVault.contacts.map((contact) {
      if (contact.id != contactId) return contact;
      return contact.copyWith(name: cleanAlias, initials: _initialsFromName(cleanAlias));
    }).toList();
    final updatedConversations = currentVault.conversations.map((conversation) {
      if (conversation.contactId != contactId) return conversation;
      return conversation.copyWith(name: cleanAlias, initials: _initialsFromName(cleanAlias));
    }).toList();
    await _replaceVault(mode, currentVault.copyWith(contacts: updatedContacts, conversations: updatedConversations));
    notifyListeners();
    return null;
  }

  Future<String?> updateGroupVisuals(VaultMode mode, String conversationId, {String? name, String? avatarUrl}) async {
    final currentVault = vaultFor(mode);
    final cleanName = name?.trim();
    if (cleanName != null) {
      final error = RavenValidation.groupNameError(cleanName);
      if (error != null) return error;
    }
    final photoError = RavenValidation.optionalPhotoUrlError(avatarUrl ?? '');
    if (photoError != null) return photoError;

    final conversation = conversationById(mode, conversationId);
    if (conversation != null && conversation.isGroup && cleanName != null && sessionToken.isNotEmpty && !conversation.id.startsWith('group_')) {
      try {
        final apiGroup = await _apiClient.renameGroup(sessionToken: sessionToken, groupId: conversation.id, name: cleanName);
        final updatedVault = _upsertGroupConversationFromApi(currentVault, apiGroup);
        await _replaceVault(mode, updatedVault);
        notifyListeners();
        return null;
      } catch (error) {
        return _apiErrorMessage(error);
      }
    }

    final updated = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
      return conversation.copyWith(
        name: cleanName ?? conversation.name,
        initials: cleanName == null ? conversation.initials : _initialsFromName(cleanName),
        avatarUrl: avatarUrl?.trim(),
      );
    }).toList();
    await _replaceVault(mode, currentVault.copyWith(conversations: updated));
    notifyListeners();
    return null;
  }

  Future<String?> addContactToGroup(VaultMode mode, {required String directConversationId, required String groupConversationId}) async {
    final currentVault = vaultFor(mode);
    final directConversation = conversationById(mode, directConversationId);
    final groupConversation = conversationById(mode, groupConversationId);
    if (directConversation == null || directConversation.isGroup) return 'Direct chat not found.';
    if (groupConversation == null || !groupConversation.isGroup) return 'Group not found.';
    final contact = currentVault.contactById(directConversation.contactId);
    if (contact == null) return 'Contact not found.';
    final ravenId = contact.effectiveRavenId;
    if (groupConversation.memberRavenIds.any((id) => id.toLowerCase() == ravenId.toLowerCase())) {
      return 'This user is already in the selected group.';
    }
    return addGroupMember(mode, groupConversationId, ravenId);
  }


  Future<List<RavenApiUser>> searchBackendUsers(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];
    if (cleanQuery.length > 64) {
      throw const RavenApiException('Search query is too long.');
    }
    final users = await _apiClient.searchUsers(cleanQuery);
    final ownId = vaultFor(VaultMode.real).ravenId.toLowerCase();
    return users
        .where((user) => user.ravenId.toLowerCase() != ownId)
        .toList();
  }

  Future<List<RavenApiGroup>> searchBackendGroups(VaultMode mode, String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];
    if (cleanQuery.length > 64) {
      throw const RavenApiException('Search query is too long.');
    }
    if (sessionToken.isEmpty) {
      throw const RavenApiException('Log in before searching groups.');
    }
    return _apiClient.searchGroups(sessionToken: sessionToken, query: cleanQuery);
  }

  Future<String?> addContactToBackendGroup(VaultMode mode, {required String directConversationId, required RavenApiGroup group}) async {
    final currentVault = vaultFor(mode);
    final updatedVault = _upsertGroupConversationFromApi(currentVault, group);
    await _replaceVault(mode, updatedVault);
    return addContactToGroup(mode, directConversationId: directConversationId, groupConversationId: group.id);
  }

  Future<String?> addConversationWithBackendUser(VaultMode mode, RavenApiUser user) async {
    if (user.ravenId.isEmpty) return 'User not found.';
    final currentVault = vaultFor(mode);
    final error = RavenValidation.ravenIdError(user.ravenId, ownRavenId: currentVault.ravenId);
    if (error != null) return error;

    final duplicate = currentVault.conversations.any(
      (conversation) => !conversation.isGroup &&
          currentVault.contactById(conversation.contactId)?.effectiveRavenId.toLowerCase() == user.ravenId.toLowerCase(),
    );
    if (duplicate) return 'A chat with this user already exists.';

    final displayName = user.displayName.trim().isEmpty ? user.ravenId : user.displayName.trim();
    final contact = ContactData(
      id: _newId('contact'),
      name: displayName,
      handle: '@${displayName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
      ravenId: user.ravenId,
      remoteDisplayName: displayName,
      initials: _initialsFromName(displayName),
      colorValue: _colorFromName(displayName).value,
      note: 'Added from the Raven backend directory.',
    );

    final conversationId = _newId('conversation');
    final newConversation = ConversationData(
      id: conversationId,
      contactId: contact.id,
      name: displayName,
      initials: contact.initials,
      colorValue: contact.colorValue,
      unread: false,
      messages: const [],
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

  Future<String?> addConversationWithBackendLookup(VaultMode mode, String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return 'Enter a Raven ID or display name.';
    if (RavenValidation.ravenIdError(cleanQuery, ownRavenId: vaultFor(mode).ravenId) == null) {
      try {
        final user = await _apiClient.getUser(cleanQuery);
        return addConversationWithBackendUser(mode, user);
      } catch (error) {
        return _apiErrorMessage(error);
      }
    }

    try {
      final users = await searchBackendUsers(cleanQuery);
      if (users.isEmpty) return 'No users found.';
      if (users.length > 1) return 'Select one result from the list.';
      return addConversationWithBackendUser(mode, users.first);
    } catch (error) {
      return _apiErrorMessage(error);
    }
  }

  Future<String?> sendDirectMessageViaBackend(VaultMode mode, String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 4000) return 'Messages must be at most 4000 characters.';

    final currentVault = vaultFor(mode);
    final conversation = conversationById(mode, conversationId);
    if (conversation == null) return 'Conversation not found.';
    if (!conversation.canSendMessages) {
      return conversation.isGroup ? 'You are no longer an active member of this group.' : 'This conversation is blocked.';
    }

    final messageId = await addMessage(mode, conversationId, trimmed);
    if (messageId == null) return null;

    if (conversation.isGroup) {
      if (sessionToken.isEmpty || currentVault.ravenId.isEmpty || conversationId.startsWith('group_')) {
        await simulateMessageDelivery(mode, conversationId, messageId);
        return null;
      }
      try {
        await _apiClient.sendGroupMessage(
          sessionToken: sessionToken,
          groupId: conversationId,
          clientMessageId: messageId,
          senderRavenId: currentVault.ravenId,
          encryptedPayload: trimmed,
        );
        await updateMessageStatus(mode, conversationId, messageId, MessageDeliveryStatus.sent);
        return null;
      } catch (error) {
        return _apiErrorMessage(error);
      }
    }

    final contact = currentVault.contactById(conversation.contactId);
    final recipientId = contact?.effectiveRavenId ?? '';
    final senderId = currentVault.ravenId;
    if (sessionToken.isEmpty || senderId.isEmpty) {
      await updateMessageStatus(mode, conversationId, messageId, MessageDeliveryStatus.local);
      return 'Message saved locally. Log in through the backend to send it.';
    }

    final recipientError = RavenValidation.ravenIdError(recipientId, ownRavenId: senderId);
    if (recipientError != null) {
      await updateMessageStatus(mode, conversationId, messageId, MessageDeliveryStatus.local);
      return recipientError;
    }

    try {
      await _apiClient.sendMessage(
        sessionToken: sessionToken,
        clientMessageId: messageId,
        senderRavenId: senderId,
        recipientRavenId: recipientId,
        encryptedPayload: trimmed,
      );
      await updateMessageStatus(mode, conversationId, messageId, MessageDeliveryStatus.sent);
      return null;
    } catch (error) {
      return _apiErrorMessage(error);
    }
  }

  Future<int> syncInboxFromBackend(VaultMode mode) async {
    final currentVault = vaultFor(mode);
    final token = sessionToken;
    if (token.isEmpty || currentVault.ravenId.isEmpty) {
      throw const RavenApiException('Log in before syncing messages.');
    }

    final incoming = await _apiClient.fetchInbox(sessionToken: token, ravenId: currentVault.ravenId);
    if (incoming.isEmpty) return 0;

    var updatedVault = currentVault;
    var imported = 0;

    for (final apiMessage in incoming) {
      final alreadyImported = updatedVault.conversations.any(
        (conversation) => conversation.messages.any((message) => message.id == apiMessage.id),
      );
      if (!alreadyImported) {
        RavenApiUser? sender;
        try {
          sender = await _apiClient.getUser(apiMessage.senderRavenId);
        } catch (_) {
          sender = null;
        }
        final senderName = sender?.displayName.trim().isNotEmpty == true ? sender!.displayName.trim() : apiMessage.senderRavenId;
        final senderId = apiMessage.senderRavenId;

        var contacts = updatedVault.contacts;
        var contact = contacts.cast<ContactData?>().firstWhere(
              (item) => item?.effectiveRavenId.toLowerCase() == senderId.toLowerCase(),
              orElse: () => null,
            );
        if (contact == null) {
          contact = ContactData(
            id: _newId('contact'),
            name: senderName,
            handle: '@${senderName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
            ravenId: senderId,
            remoteDisplayName: senderName,
            initials: _initialsFromName(senderName),
            colorValue: _colorFromName(senderName).value,
            note: 'Added automatically from a backend message.',
          );
          contacts = [contact, ...contacts];
        }

        var conversations = updatedVault.conversations;
        var conversation = conversations.cast<ConversationData?>().firstWhere(
              (item) => !((item?.isGroup ?? false)) && item?.contactId == contact!.id,
              orElse: () => null,
            );
        if (conversation == null) {
          conversation = ConversationData(
            id: _newId('conversation'),
            contactId: contact.id,
            name: contact.name,
            initials: contact.initials,
            colorValue: contact.colorValue,
            unread: true,
            messages: const [],
          );
          conversations = [conversation, ...conversations];
        }

        final importedMessage = ChatMessageData(
          id: apiMessage.id,
          conversationId: conversation.id,
          senderId: senderId,
          receiverId: currentVault.ravenId,
          encryptedPayload: apiMessage.encryptedPayload,
          text: apiMessage.encryptedPayload,
          mine: false,
          createdAt: apiMessage.createdAt,
          deliveryStatus: MessageDeliveryStatus.delivered,
        );

        conversations = conversations.map((item) {
          if (item.id != conversation!.id) return item;
          return item.copyWith(
            unread: true,
            messages: [...item.messages, importedMessage],
          );
        }).toList();

        updatedVault = updatedVault.copyWith(contacts: contacts, conversations: conversations);
        imported += 1;
      }

      try {
        await _apiClient.markDelivered(sessionToken: token, messageId: apiMessage.id);
      } catch (_) {
        // Keep the imported local copy even if delivery acknowledgement fails.
      }
    }

    await _replaceVault(mode, updatedVault);
    notifyListeners();
    return imported;
  }

  Future<String?> sendPasswordResetCode({required String email}) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!RavenValidation.isValidEmail(cleanEmail)) return 'Enter a valid email address.';
    try {
      await _apiClient.forgotPassword(email: cleanEmail);
      return null;
    } catch (error) {
      return _apiErrorMessage(error);
    }
  }

  Future<String?> recoverAccountPassword({required String email, required String code, required String newPassword}) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!RavenValidation.isValidEmail(cleanEmail)) return 'Enter a valid email address.';
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) return 'Enter the 6-digit verification code.';
    if (newPassword.length < 8) return 'Use at least 8 characters for the account password.';
    if (newPassword.length > 128) return 'Account password must be at most 128 characters.';

    try {
      await _apiClient.resetPassword(email: cleanEmail, code: code.trim(), newPassword: newPassword);
    } catch (error) {
      return _apiErrorMessage(error);
    }

    final account = _account;
    if (account != null && account.created && account.email.toLowerCase() == cleanEmail) {
      _account = account.copyWith(passwordVerifier: await PinVerifier.create(newPassword, _deriveKeyBytes));
      await _saveAccount();
      notifyListeners();
    }
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

    final cleanName = groupName.trim();
    final localGroupId = _newId('group');

    if (sessionToken.isNotEmpty && currentVault.ravenId.isNotEmpty) {
      try {
        final apiGroup = await _apiClient.createGroup(
          sessionToken: sessionToken,
          clientGroupId: localGroupId,
          name: cleanName,
          ownerRavenId: currentVault.ravenId,
          memberRavenIds: uniqueMembers,
        );
        final updatedVault = _upsertGroupConversationFromApi(
          currentVault,
          apiGroup,
          systemMessage: apiGroup.invitedRavenIds.isEmpty
              ? 'Group created through the Raven backend.'
              : 'Group created. Some users received invitations based on their privacy settings.',
        );
        await _replaceVault(mode, updatedVault);
        notifyListeners();
        return null;
      } catch (error) {
        return _apiErrorMessage(error);
      }
    }

    final newConversation = ConversationData(
      id: localGroupId,
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
          conversationId: localGroupId,
          senderId: currentVault.ravenId,
          receiverId: 'group:$localGroupId',
          text: uniqueMembers.isEmpty
              ? 'Group created locally with no members yet.'
              : 'Group created locally. Log in through the backend to sync members.',
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
    final conversation = conversationById(mode, conversationId);
    if (conversation == null || !conversation.isGroup) return 'Group not found.';

    if (conversation.memberRavenIds.any((id) => id.toLowerCase() == clean.toLowerCase())) {
      return 'This user is already in the group.';
    }

    if (sessionToken.isNotEmpty && currentVault.ravenId.isNotEmpty && !conversationId.startsWith('group_')) {
      try {
        final apiGroup = await _apiClient.addGroupMember(
          sessionToken: sessionToken,
          groupId: conversationId,
          memberRavenId: clean,
        );
        final updatedVault = _upsertGroupConversationFromApi(
          currentVault,
          apiGroup,
          systemMessage: apiGroup.invitedRavenIds.any((id) => id.toLowerCase() == clean.toLowerCase())
              ? '$clean was invited to the group.'
              : '$clean was added to the group.',
        );
        await _replaceVault(mode, updatedVault);
        notifyListeners();
        return null;
      } catch (err) {
        return _apiErrorMessage(err);
      }
    }

    final updatedConversations = currentVault.conversations.map((conversation) {
      if (conversation.id != conversationId) return conversation;
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

  Future<String?> leaveGroup(VaultMode mode, String conversationId) async {
    final currentVault = vaultFor(mode);
    final conversation = conversationById(mode, conversationId);
    if (conversation == null || !conversation.isGroup) return 'Group not found.';

    if (sessionToken.isEmpty || conversation.id.startsWith('group_')) {
      final updated = currentVault.conversations.map((item) {
        if (item.id != conversationId) return item;
        return item.copyWith(
          groupMembershipStatus: 'left',
          memberRavenIds: item.memberRavenIds.where((id) => id.toLowerCase() != currentVault.ravenId.toLowerCase()).toList(),
          messages: [
            ...item.messages,
            ChatMessageData(
              id: _newId('message'),
              conversationId: conversationId,
              senderId: currentVault.ravenId,
              receiverId: 'group:$conversationId',
              text: 'You left the group.',
              encryptedPayload: 'You left the group.',
              mine: false,
              createdAt: DateTime.now(),
              deliveryStatus: MessageDeliveryStatus.local,
              isSystem: true,
            ),
          ],
        );
      }).toList();
      await _replaceVault(mode, currentVault.copyWith(conversations: updated));
      notifyListeners();
      return null;
    }

    try {
      final apiGroup = await _apiClient.leaveGroup(sessionToken: sessionToken, groupId: conversation.id);
      final updatedVault = _upsertGroupConversationFromApi(
        currentVault,
        apiGroup,
        systemMessage: apiGroup.status == 'closed' ? 'The group was closed.' : 'You left the group.',
      );
      await _replaceVault(mode, updatedVault);
      notifyListeners();
      return null;
    } catch (error) {
      return _apiErrorMessage(error);
    }
  }

  Future<String?> closeGroupForEveryone(VaultMode mode, String conversationId) async {
    final currentVault = vaultFor(mode);
    final conversation = conversationById(mode, conversationId);
    if (conversation == null || !conversation.isGroup) return 'Group not found.';

    if (sessionToken.isEmpty || conversation.id.startsWith('group_')) {
      await deleteConversation(mode, conversationId, leaveBackendGroup: false);
      return null;
    }

    try {
      await _apiClient.closeGroup(sessionToken: sessionToken, groupId: conversation.id);
      await deleteConversation(mode, conversationId, leaveBackendGroup: false);
      return null;
    } catch (error) {
      return _apiErrorMessage(error);
    }
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

  Future<String?> deleteConversation(VaultMode mode, String conversationId, {bool leaveBackendGroup = true}) async {
    var currentVault = vaultFor(mode);
    final conversation = conversationById(mode, conversationId);

    if (leaveBackendGroup && conversation != null && conversation.isGroup && conversation.groupMembershipStatus == 'accepted') {
      if (conversation.owner && sessionToken.isNotEmpty && !conversation.id.startsWith('group_')) {
        final closeError = await closeGroupForEveryone(mode, conversationId);
        if (closeError != null) return closeError;
        currentVault = vaultFor(mode);
      } else {
        final leaveError = await leaveGroup(mode, conversationId);
        if (leaveError != null) return leaveError;
        currentVault = vaultFor(mode);
      }
    }

    final hiddenIds = <String>{...currentVault.hiddenGroupIds};
    if (conversation?.isGroup == true) hiddenIds.add(conversationId);
    await _replaceVault(
      mode,
      currentVault.copyWith(
        hiddenGroupIds: hiddenIds.toList(),
        conversations: currentVault.conversations.where((c) => c.id != conversationId).toList(),
      ),
    );
    notifyListeners();
    return null;
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
            receiverId: conversation.isGroup ? 'group:$conversationId' : (contact?.effectiveRavenId ?? 'rvn_unknown'),
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

  VaultData _upsertGroupConversationFromApi(
    VaultData vault,
    RavenApiGroup group, {
    String? systemMessage,
  }) {
    final groupId = group.id.isEmpty ? (group.clientGroupId ?? '') : group.id;
    if (groupId.isNotEmpty && vault.hiddenGroupIds.any((id) => id == groupId || id == group.clientGroupId)) {
      return vault;
    }

    final existing = vault.conversations.cast<ConversationData?>().firstWhere(
          (conversation) => conversation?.id == group.id || conversation?.id == group.clientGroupId,
          orElse: () => null,
        );
    final memberIds = <String>{
      ...group.memberRavenIds,
      ...group.invitedRavenIds,
    }.toList();
    final cleanName = group.name.trim().isEmpty ? 'Group' : group.name.trim();
    final conversationId = group.id.isEmpty ? (group.clientGroupId ?? _newId('group')) : group.id;
    final membership = group.myStatus ?? (group.memberRavenIds.any((id) => id.toLowerCase() == vault.ravenId.toLowerCase()) ? 'accepted' : 'left');
    final effectiveSystemMessage = systemMessage ?? ((existing != null && existing.groupStatus != group.status && group.status == 'closed') ? 'The group was closed.' : null);

    final message = effectiveSystemMessage == null || effectiveSystemMessage.trim().isEmpty
        ? null
        : ChatMessageData(
            id: 'system_${DateTime.now().microsecondsSinceEpoch}',
            conversationId: conversationId,
            senderId: group.ownerRavenId,
            receiverId: 'group:$conversationId',
            encryptedPayload: effectiveSystemMessage,
            text: effectiveSystemMessage,
            mine: false,
            createdAt: DateTime.now(),
            deliveryStatus: MessageDeliveryStatus.local,
            isSystem: true,
          );

    if (existing == null) {
      final conversation = ConversationData(
        id: conversationId,
        name: cleanName,
        initials: _initialsFromName(cleanName),
        colorValue: _colorFromName(cleanName).value,
        unread: false,
        isGroup: true,
        memberRavenIds: memberIds,
        owner: group.ownerRavenId.toLowerCase() == vault.ravenId.toLowerCase(),
        groupStatus: group.status,
        groupMembershipStatus: membership,
        messages: message == null ? const [] : [message],
      );
      return vault.copyWith(conversations: [conversation, ...vault.conversations]);
    }

    final updatedMessages = message == null || existing.messages.any((m) => m.isSystem && m.text == message.text)
        ? existing.messages
        : [...existing.messages, message];
    final updatedConversations = vault.conversations.map((conversation) {
      if (conversation.id != existing.id) return conversation;
      return conversation.copyWith(
        id: conversationId,
        name: cleanName,
        initials: _initialsFromName(cleanName),
        isGroup: true,
        memberRavenIds: memberIds,
        owner: group.ownerRavenId.toLowerCase() == vault.ravenId.toLowerCase(),
        groupStatus: group.status,
        groupMembershipStatus: membership,
        messages: updatedMessages,
      );
    }).toList();
    return vault.copyWith(conversations: updatedConversations);
  }

  Future<int> syncOutgoingDeliveryStatuses(VaultMode mode) async {
    final currentVault = vaultFor(mode);
    final token = sessionToken;
    if (token.isEmpty || currentVault.ravenId.isEmpty) {
      throw const RavenApiException('Log in before syncing message statuses.');
    }

    final statuses = await _apiClient.fetchOutgoingMessageStatus(sessionToken: token, ravenId: currentVault.ravenId);
    if (statuses.isEmpty) return 0;

    var updatedCount = 0;
    var updatedVault = currentVault;
    final updatedConversations = updatedVault.conversations.map((conversation) {
      var changed = false;
      final updatedMessages = conversation.messages.map((message) {
        if (!message.mine || message.deliveryStatus == MessageDeliveryStatus.delivered) return message;
        for (final status in statuses) {
          final matchesClientId = status.clientMessageId != null && status.clientMessageId == message.id;
          if (matchesClientId && status.deliveredAt != null) {
            changed = true;
            updatedCount += 1;
            return message.copyWith(deliveryStatus: MessageDeliveryStatus.delivered);
          }
        }
        return message;
      }).toList();
      return changed ? conversation.copyWith(messages: updatedMessages) : conversation;
    }).toList();

    if (updatedCount > 0) {
      updatedVault = updatedVault.copyWith(conversations: updatedConversations);
      await _replaceVault(mode, updatedVault);
      notifyListeners();
    }
    return updatedCount;
  }

  Future<int> syncGroupsFromBackend(VaultMode mode) async {
    final currentVault = vaultFor(mode);
    final token = sessionToken;
    if (token.isEmpty || currentVault.ravenId.isEmpty) {
      throw const RavenApiException('Log in before syncing groups.');
    }

    var updatedVault = currentVault;
    var count = 0;

    final groups = await _apiClient.fetchMyGroups(sessionToken: token, ravenId: currentVault.ravenId);
    for (final group in groups) {
      if (updatedVault.hiddenGroupIds.any((id) => id == group.id || id == group.clientGroupId)) continue;
      final before = jsonEncode(updatedVault.toJson());
      final existed = updatedVault.conversations.any((conversation) => conversation.id == group.id || conversation.id == group.clientGroupId);
      updatedVault = _upsertGroupConversationFromApi(updatedVault, group);
      if (!existed || jsonEncode(updatedVault.toJson()) != before) count += 1;
    }

    final invites = await _apiClient.fetchGroupInvites(sessionToken: token, ravenId: currentVault.ravenId);
    for (final invite in invites) {
      if (updatedVault.hiddenGroupIds.contains(invite.groupId)) continue;
      final exists = updatedVault.conversations.any((conversation) => conversation.id == invite.groupId);
      if (!exists) {
        final apiGroup = await _apiClient.respondGroupInvite(sessionToken: token, groupId: invite.groupId, accept: true);
        updatedVault = _upsertGroupConversationFromApi(
          updatedVault,
          apiGroup,
          systemMessage: '${invite.inviterRavenId} invited you to participate in “${invite.groupName}”.',
        );
        count += 1;
      }
    }

    if (jsonEncode(updatedVault.toJson()) != jsonEncode(currentVault.toJson())) {
      await _replaceVault(mode, updatedVault);
      notifyListeners();
    }
    return count;
  }

  Future<int> syncGroupMessagesFromBackend(VaultMode mode) async {
    final currentVault = vaultFor(mode);
    final token = sessionToken;
    if (token.isEmpty || currentVault.ravenId.isEmpty) {
      throw const RavenApiException('Log in before syncing group messages.');
    }

    final incoming = await _apiClient.fetchGroupInbox(sessionToken: token, ravenId: currentVault.ravenId);
    if (incoming.isEmpty) return 0;

    var updatedVault = currentVault;
    var imported = 0;

    for (final apiMessage in incoming) {
      var conversation = updatedVault.conversations.cast<ConversationData?>().firstWhere(
            (item) => item?.id == apiMessage.groupId,
            orElse: () => null,
          );

      if (conversation == null) {
        try {
          final group = await _apiClient.getGroup(sessionToken: token, groupId: apiMessage.groupId);
          updatedVault = _upsertGroupConversationFromApi(updatedVault, group);
          conversation = updatedVault.conversations.cast<ConversationData?>().firstWhere(
                (item) => item?.id == apiMessage.groupId,
                orElse: () => null,
              );
        } catch (_) {
          final fallbackGroup = RavenApiGroup(
            id: apiMessage.groupId,
            name: apiMessage.groupName,
            ownerRavenId: apiMessage.senderRavenId,
            memberRavenIds: [currentVault.ravenId, apiMessage.senderRavenId],
            invitedRavenIds: const [],
            createdAt: apiMessage.createdAt,
            status: 'active',
            myStatus: 'accepted',
          );
          updatedVault = _upsertGroupConversationFromApi(updatedVault, fallbackGroup);
          conversation = updatedVault.conversations.cast<ConversationData?>().firstWhere(
                (item) => item?.id == apiMessage.groupId,
                orElse: () => null,
              );
        }
      }

      if (conversation == null) continue;

      final alreadyImported = conversation.messages.any(
        (message) => message.id == apiMessage.id || (apiMessage.isSystemEvent && message.isSystem && message.text == apiMessage.encryptedPayload),
      );
      if (!alreadyImported) {
        final importedMessage = ChatMessageData(
          id: apiMessage.id,
          conversationId: conversation.id,
          senderId: apiMessage.senderRavenId,
          receiverId: 'group:${apiMessage.groupId}',
          encryptedPayload: apiMessage.encryptedPayload,
          text: apiMessage.encryptedPayload,
          mine: false,
          createdAt: apiMessage.createdAt,
          deliveryStatus: MessageDeliveryStatus.delivered,
          isSystem: apiMessage.isSystemEvent,
        );

        final updatedConversations = updatedVault.conversations.map((item) {
          if (item.id != conversation!.id) return item;
          return item.copyWith(unread: true, messages: [...item.messages, importedMessage]);
        }).toList();
        updatedVault = updatedVault.copyWith(conversations: updatedConversations);
        imported += 1;
      }

      try {
        await _apiClient.markGroupMessageDelivered(sessionToken: token, messageId: apiMessage.id);
      } catch (_) {
        // Keep the imported local copy even if group delivery acknowledgement fails.
      }
    }

    await _replaceVault(mode, updatedVault);
    notifyListeners();
    return imported;
  }

  VaultData _upsertContactProfile(VaultData vault, RavenApiUser user) {
    if (user.ravenId.isEmpty) return vault;
    final remoteName = user.displayName.trim().isEmpty ? user.ravenId : user.displayName.trim();
    var found = false;
    final updatedContacts = vault.contacts.map((contact) {
      if (contact.effectiveRavenId.toLowerCase() != user.ravenId.toLowerCase()) return contact;
      found = true;
      final oldRemote = contact.effectiveRemoteDisplayName;
      final shouldUpdateVisibleName = contact.name.trim().isEmpty ||
          contact.name == oldRemote ||
          contact.name == 'Raven User' ||
          contact.name == contact.ravenId;
      final visibleName = shouldUpdateVisibleName ? remoteName : contact.name;
      return contact.copyWith(
        name: visibleName,
        remoteDisplayName: remoteName,
        initials: shouldUpdateVisibleName ? _initialsFromName(remoteName) : contact.initials,
        handle: '@${remoteName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
      );
    }).toList();

    final contacts = found
        ? updatedContacts
        : [
            ContactData(
              id: _newId('contact'),
              name: remoteName,
              handle: '@${remoteName.toLowerCase().replaceAll(RegExp(r'\s+'), '')}',
              ravenId: user.ravenId,
              remoteDisplayName: remoteName,
              initials: _initialsFromName(remoteName),
              colorValue: _colorFromName(remoteName).value,
              note: 'Cached from backend profile sync.',
            ),
            ...updatedContacts,
          ];

    final updatedVault = vault.copyWith(contacts: contacts);
    final updatedConversations = updatedVault.conversations.map((conversation) {
      if (conversation.isGroup) return conversation;
      final contact = updatedVault.contactById(conversation.contactId);
      if (contact == null || contact.effectiveRavenId.toLowerCase() != user.ravenId.toLowerCase()) return conversation;
      return conversation.copyWith(name: contact.name, initials: contact.initials);
    }).toList();

    return updatedVault.copyWith(conversations: updatedConversations);
  }

  Future<int> syncKnownUserProfiles(VaultMode mode) async {
    final currentVault = vaultFor(mode);
    if (sessionToken.isEmpty || currentVault.ravenId.isEmpty) {
      throw const RavenApiException('Log in before syncing profiles.');
    }

    final ids = <String>{};
    for (final contact in currentVault.contacts) {
      final id = contact.effectiveRavenId;
      if (id.isNotEmpty && id.toLowerCase() != currentVault.ravenId.toLowerCase()) ids.add(id);
    }
    for (final conversation in currentVault.conversations.where((item) => item.isGroup)) {
      for (final id in conversation.memberRavenIds) {
        if (id.isNotEmpty && id.toLowerCase() != currentVault.ravenId.toLowerCase()) ids.add(id);
      }
    }

    var updatedVault = currentVault;
    var changed = 0;
    for (final id in ids) {
      try {
        final user = await _apiClient.getUser(id);
        final before = jsonEncode(updatedVault.toJson());
        updatedVault = _upsertContactProfile(updatedVault, user);
        if (jsonEncode(updatedVault.toJson()) != before) changed += 1;
      } catch (_) {
        // Ignore missing users during profile refresh; messages/groups still sync.
      }
    }

    if (changed > 0) {
      await _replaceVault(mode, updatedVault);
      notifyListeners();
    }
    return changed;
  }

  Future<String> syncBackend(VaultMode mode) async {
    final directImported = await syncInboxFromBackend(mode);
    final groupsImported = await syncGroupsFromBackend(mode);
    final groupMessagesImported = await syncGroupMessagesFromBackend(mode);
    final deliveredUpdated = await syncOutgoingDeliveryStatuses(mode);
    final profilesUpdated = await syncKnownUserProfiles(mode);

    final parts = <String>[];
    if (directImported > 0) parts.add('$directImported direct');
    if (groupsImported > 0) parts.add('$groupsImported group');
    if (groupMessagesImported > 0) parts.add('$groupMessagesImported group message');
    if (deliveredUpdated > 0) parts.add('$deliveredUpdated delivered');
    if (profilesUpdated > 0) parts.add('$profilesUpdated profile');
    if (parts.isEmpty) return 'Everything is already up to date.';
    return 'Synced ${parts.join(', ')}.';
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


