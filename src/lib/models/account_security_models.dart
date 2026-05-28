part of raven_app;

class RavenAccountState {
  const RavenAccountState({
    required this.created,
    required this.email,
    required this.displayName,
    required this.passwordVerifier,
    this.emailVerified = true,
    this.ravenId = '',
    this.sessionToken = '',
  });

  final bool created;
  final String email;
  final String displayName;
  final PinVerifier passwordVerifier;
  final bool emailVerified;
  final String ravenId;
  final String sessionToken;

  RavenAccountState copyWith({
    bool? created,
    String? email,
    String? displayName,
    PinVerifier? passwordVerifier,
    bool? emailVerified,
    String? ravenId,
    String? sessionToken,
  }) {
    return RavenAccountState(
      created: created ?? this.created,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      passwordVerifier: passwordVerifier ?? this.passwordVerifier,
      emailVerified: emailVerified ?? this.emailVerified,
      ravenId: ravenId ?? this.ravenId,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }

  Map<String, dynamic> toJson() => {
        'created': created,
        'email': email,
        'displayName': displayName,
        'passwordVerifier': passwordVerifier.toJson(),
        'emailVerified': emailVerified,
        'ravenId': ravenId,
        'sessionToken': sessionToken,
      };

  factory RavenAccountState.fromJson(Map<String, dynamic> json) {
    return RavenAccountState(
      created: json['created'] as bool? ?? false,
      email: json['email'] as String? ?? '',
      displayName: json['displayName'] as String? ?? 'Raven User',
      passwordVerifier: PinVerifier.fromJson(json['passwordVerifier'] as Map<String, dynamic>? ?? {}),
      emailVerified: json['emailVerified'] as bool? ?? true,
      ravenId: json['ravenId'] as String? ?? '',
      sessionToken: json['sessionToken'] as String? ?? '',
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
    this.emergencyPinEnabled = false,
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
  final bool emergencyPinEnabled;
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
    bool? emergencyPinEnabled,
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
      emergencyPinEnabled: emergencyPinEnabled ?? this.emergencyPinEnabled,
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
        'emergencyPinEnabled': emergencyPinEnabled,
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
      emergencyPinEnabled: json['emergencyPinEnabled'] as bool? ?? false,
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

