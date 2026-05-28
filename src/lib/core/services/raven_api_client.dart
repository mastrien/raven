part of raven_app;

class RavenApiException implements Exception {
  const RavenApiException(this.message, {this.code, this.statusCode});

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class RavenApiUser {
  const RavenApiUser({
    required this.ravenId,
    required this.displayName,
    required this.emailVerified,
  });

  final String ravenId;
  final String displayName;
  final bool emailVerified;

  factory RavenApiUser.fromJson(Map<String, dynamic> json) {
    return RavenApiUser(
      ravenId: json['raven_id'] as String? ?? '',
      displayName: json['display_name'] as String? ?? 'Raven User',
      emailVerified: json['email_verified'] as bool? ?? false,
    );
  }
}

class RavenAuthApiResponse {
  const RavenAuthApiResponse({
    required this.user,
    this.sessionToken,
    this.demoCode,
  });

  final RavenApiUser user;
  final String? sessionToken;
  final String? demoCode;

  factory RavenAuthApiResponse.fromJson(Map<String, dynamic> json) {
    return RavenAuthApiResponse(
      user: RavenApiUser.fromJson(json['user'] as Map<String, dynamic>? ?? const {}),
      sessionToken: json['session_token'] as String?,
      demoCode: json['demo_code'] as String?,
    );
  }
}

class RavenBasicApiResponse {
  const RavenBasicApiResponse({required this.ok, required this.message, this.demoCode});

  final bool ok;
  final String message;
  final String? demoCode;

  factory RavenBasicApiResponse.fromJson(Map<String, dynamic> json) {
    return RavenBasicApiResponse(
      ok: json['ok'] as bool? ?? false,
      message: json['message'] as String? ?? '',
      demoCode: json['demo_code'] as String?,
    );
  }
}

class RavenApiMessage {
  const RavenApiMessage({
    required this.id,
    this.clientMessageId,
    required this.senderRavenId,
    required this.recipientRavenId,
    required this.encryptedPayload,
    required this.createdAt,
    this.deliveredAt,
  });

  final String id;
  final String? clientMessageId;
  final String senderRavenId;
  final String recipientRavenId;
  final String encryptedPayload;
  final DateTime createdAt;
  final DateTime? deliveredAt;

  factory RavenApiMessage.fromJson(Map<String, dynamic> json) {
    return RavenApiMessage(
      id: json['id'] as String? ?? '',
      clientMessageId: json['client_message_id'] as String?,
      senderRavenId: json['sender_raven_id'] as String? ?? '',
      recipientRavenId: json['recipient_raven_id'] as String? ?? '',
      encryptedPayload: json['encrypted_payload'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
    );
  }
}

class RavenApiMessageStatus {
  const RavenApiMessageStatus({
    required this.id,
    this.clientMessageId,
    required this.recipientRavenId,
    this.deliveredAt,
  });

  final String id;
  final String? clientMessageId;
  final String recipientRavenId;
  final DateTime? deliveredAt;

  factory RavenApiMessageStatus.fromJson(Map<String, dynamic> json) {
    return RavenApiMessageStatus(
      id: json['id'] as String? ?? '',
      clientMessageId: json['client_message_id'] as String?,
      recipientRavenId: json['recipient_raven_id'] as String? ?? '',
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
    );
  }
}

class RavenApiGroup {
  const RavenApiGroup({
    required this.id,
    this.clientGroupId,
    required this.name,
    required this.ownerRavenId,
    required this.memberRavenIds,
    required this.invitedRavenIds,
    required this.createdAt,
    this.status = 'active',
    this.myStatus,
  });

  final String id;
  final String? clientGroupId;
  final String name;
  final String ownerRavenId;
  final List<String> memberRavenIds;
  final List<String> invitedRavenIds;
  final DateTime createdAt;
  final String status;
  final String? myStatus;

  factory RavenApiGroup.fromJson(Map<String, dynamic> json) {
    return RavenApiGroup(
      id: json['id'] as String? ?? '',
      clientGroupId: json['client_group_id'] as String?,
      name: json['name'] as String? ?? 'Group',
      ownerRavenId: json['owner_raven_id'] as String? ?? '',
      memberRavenIds: ((json['member_raven_ids'] as List<dynamic>?) ?? const []).whereType<String>().toList(),
      invitedRavenIds: ((json['invited_raven_ids'] as List<dynamic>?) ?? const []).whereType<String>().toList(),
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'active',
      myStatus: json['my_status'] as String?,
    );
  }
}

class RavenApiGroupInvite {
  const RavenApiGroupInvite({
    required this.groupId,
    required this.groupName,
    required this.inviterRavenId,
    required this.createdAt,
  });

  final String groupId;
  final String groupName;
  final String inviterRavenId;
  final DateTime createdAt;

  factory RavenApiGroupInvite.fromJson(Map<String, dynamic> json) {
    return RavenApiGroupInvite(
      groupId: json['group_id'] as String? ?? '',
      groupName: json['group_name'] as String? ?? 'Group',
      inviterRavenId: json['inviter_raven_id'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class RavenApiGroupMessage {
  const RavenApiGroupMessage({
    required this.id,
    this.clientMessageId,
    required this.groupId,
    required this.groupName,
    required this.senderRavenId,
    required this.encryptedPayload,
    required this.createdAt,
    this.deliveredAt,
    this.messageKind = 'user_message',
  });

  final String id;
  final String? clientMessageId;
  final String groupId;
  final String groupName;
  final String senderRavenId;
  final String encryptedPayload;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final String messageKind;

  bool get isSystemEvent => messageKind == 'system_event';

  factory RavenApiGroupMessage.fromJson(Map<String, dynamic> json) {
    return RavenApiGroupMessage(
      id: json['id'] as String? ?? '',
      clientMessageId: json['client_message_id'] as String?,
      groupId: json['group_id'] as String? ?? '',
      groupName: json['group_name'] as String? ?? 'Group',
      senderRavenId: json['sender_raven_id'] as String? ?? '',
      encryptedPayload: json['encrypted_payload'] as String? ?? '',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
      deliveredAt: DateTime.tryParse(json['delivered_at'] as String? ?? ''),
      messageKind: json['message_kind'] as String? ?? 'user_message',
    );
  }
}

class RavenApiClient {
  RavenApiClient({
    this.baseUrl = const String.fromEnvironment('RAVEN_API_BASE_URL', defaultValue: 'http://127.0.0.1:8080'),
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Uri _uri(String path, [Map<String, String>? queryParameters]) {
    final normalizedBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$normalizedBase$path').replace(queryParameters: queryParameters);
  }

  Future<Map<String, dynamic>> _postJson(String path, Map<String, dynamic> body, {String? sessionToken}) async {
    return _sendJson('POST', path, body, sessionToken: sessionToken);
  }

  Future<Map<String, dynamic>> _patchJson(String path, Map<String, dynamic> body, {String? sessionToken}) async {
    return _sendJson('PATCH', path, body, sessionToken: sessionToken);
  }

  Future<Map<String, dynamic>> _sendJson(String method, String path, Map<String, dynamic> body, {String? sessionToken}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (sessionToken != null && sessionToken.isNotEmpty) 'Authorization': 'Bearer $sessionToken',
    };
    http.Response response;
    try {
      final uri = _uri(path);
      if (method == 'PATCH') {
        response = await _httpClient.patch(uri, headers: headers, body: jsonEncode(body));
      } else {
        response = await _httpClient.post(uri, headers: headers, body: jsonEncode(body));
      }
    } catch (_) {
      throw const RavenApiException('Could not connect to the Raven backend. Make sure raven_backend is running with cargo run.');
    }
    final decoded = _decodeResponse(response);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const RavenApiException('Unexpected backend response.');
  }

  Future<dynamic> _getDecoded(String path, {Map<String, String>? queryParameters, String? sessionToken}) async {
    final headers = <String, String>{
      if (sessionToken != null && sessionToken.isNotEmpty) 'Authorization': 'Bearer $sessionToken',
    };
    http.Response response;
    try {
      response = await _httpClient.get(_uri(path, queryParameters), headers: headers);
    } catch (_) {
      throw const RavenApiException('Could not connect to the Raven backend. Make sure raven_backend is running with cargo run.');
    }
    return _decodeResponse(response);
  }

  Future<Map<String, dynamic>> _getJson(String path, {Map<String, String>? queryParameters, String? sessionToken}) async {
    final decoded = await _getDecoded(path, queryParameters: queryParameters, sessionToken: sessionToken);
    if (decoded is Map<String, dynamic>) return decoded;
    throw const RavenApiException('Unexpected backend response.');
  }

  Future<List<dynamic>> _getList(String path, {Map<String, String>? queryParameters, String? sessionToken}) async {
    final decoded = await _getDecoded(path, queryParameters: queryParameters, sessionToken: sessionToken);
    if (decoded is List<dynamic>) return decoded;
    throw const RavenApiException('Unexpected backend response.');
  }

  dynamic _decodeResponse(http.Response response) {
    final raw = response.body.trim();
    final decoded = raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          throw RavenApiException(
            error['message'] as String? ?? 'Raven backend request failed.',
            code: error['code'] as String?,
            statusCode: response.statusCode,
          );
        }
      }
      throw RavenApiException('Raven backend request failed with status ${response.statusCode}.', statusCode: response.statusCode);
    }
    return decoded;
  }

  Future<RavenAuthApiResponse> register({required String email, required String password, required String displayName}) async {
    final json = await _postJson('/auth/register', {
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    return RavenAuthApiResponse.fromJson(json);
  }

  Future<RavenAuthApiResponse> verifyEmail({required String email, required String code}) async {
    final json = await _postJson('/auth/verify-email', {
      'email': email,
      'code': code,
    });
    return RavenAuthApiResponse.fromJson(json);
  }

  Future<RavenAuthApiResponse> login({required String email, required String password}) async {
    final json = await _postJson('/auth/login', {
      'email': email,
      'password': password,
    });
    return RavenAuthApiResponse.fromJson(json);
  }

  Future<RavenBasicApiResponse> forgotPassword({required String email}) async {
    final json = await _postJson('/auth/forgot-password', {'email': email});
    return RavenBasicApiResponse.fromJson(json);
  }

  Future<RavenBasicApiResponse> resetPassword({required String email, required String code, required String newPassword}) async {
    final json = await _postJson('/auth/reset-password', {
      'email': email,
      'code': code,
      'new_password': newPassword,
    });
    return RavenBasicApiResponse.fromJson(json);
  }

  Future<List<RavenApiUser>> searchUsers(String query) async {
    final list = await _getList('/users/search', queryParameters: {'q': query});
    return list.whereType<Map<String, dynamic>>().map(RavenApiUser.fromJson).toList();
  }

  Future<RavenApiUser> getUser(String ravenId) async {
    final json = await _getJson('/users/$ravenId');
    return RavenApiUser.fromJson(json);
  }

  Future<RavenApiUser> updateMyProfile({required String sessionToken, required String displayName}) async {
    final json = await _patchJson('/users/me/profile', {'display_name': displayName}, sessionToken: sessionToken);
    return RavenApiUser.fromJson(json);
  }

  Future<RavenApiMessage> sendMessage({
    required String sessionToken,
    required String clientMessageId,
    required String senderRavenId,
    required String recipientRavenId,
    required String encryptedPayload,
  }) async {
    final json = await _postJson(
      '/messages',
      {
        'client_message_id': clientMessageId,
        'sender_raven_id': senderRavenId,
        'recipient_raven_id': recipientRavenId,
        'encrypted_payload': encryptedPayload,
      },
      sessionToken: sessionToken,
    );
    return RavenApiMessage.fromJson(json);
  }

  Future<List<RavenApiMessage>> fetchInbox({required String sessionToken, required String ravenId}) async {
    final list = await _getList('/messages/inbox/$ravenId', sessionToken: sessionToken);
    return list.whereType<Map<String, dynamic>>().map(RavenApiMessage.fromJson).toList();
  }

  Future<RavenApiMessage> markDelivered({required String sessionToken, required String messageId}) async {
    final json = await _postJson('/messages/$messageId/delivered', <String, dynamic>{}, sessionToken: sessionToken);
    return RavenApiMessage.fromJson(json);
  }

  Future<List<RavenApiMessageStatus>> fetchOutgoingMessageStatus({required String sessionToken, required String ravenId}) async {
    final list = await _getList('/messages/outbox/$ravenId/status', sessionToken: sessionToken);
    return list.whereType<Map<String, dynamic>>().map(RavenApiMessageStatus.fromJson).toList();
  }

  Future<RavenApiGroup> createGroup({
    required String sessionToken,
    required String clientGroupId,
    required String name,
    required String ownerRavenId,
    required List<String> memberRavenIds,
  }) async {
    final json = await _postJson(
      '/groups',
      {
        'client_group_id': clientGroupId,
        'name': name,
        'owner_raven_id': ownerRavenId,
        'member_raven_ids': memberRavenIds,
      },
      sessionToken: sessionToken,
    );
    return RavenApiGroup.fromJson(json);
  }

  Future<RavenApiGroup> addGroupMember({required String sessionToken, required String groupId, required String memberRavenId}) async {
    final json = await _postJson('/groups/$groupId/members', {'member_raven_id': memberRavenId}, sessionToken: sessionToken);
    return RavenApiGroup.fromJson(json);
  }

  Future<List<RavenApiGroup>> searchGroups({required String sessionToken, required String query}) async {
    final list = await _getList('/groups/search', queryParameters: {'q': query}, sessionToken: sessionToken);
    return list.whereType<Map<String, dynamic>>().map(RavenApiGroup.fromJson).toList();
  }

  Future<List<RavenApiGroup>> fetchMyGroups({required String sessionToken, required String ravenId}) async {
    final list = await _getList('/groups/mine/$ravenId', sessionToken: sessionToken);
    return list.whereType<Map<String, dynamic>>().map(RavenApiGroup.fromJson).toList();
  }

  Future<RavenApiGroup> getGroup({required String sessionToken, required String groupId}) async {
    final json = await _getJson('/groups/by-id/$groupId', sessionToken: sessionToken);
    return RavenApiGroup.fromJson(json);
  }

  Future<RavenApiGroup> renameGroup({required String sessionToken, required String groupId, required String name}) async {
    final json = await _patchJson('/groups/$groupId/rename', {'name': name}, sessionToken: sessionToken);
    return RavenApiGroup.fromJson(json);
  }

  Future<RavenApiGroup> leaveGroup({required String sessionToken, required String groupId}) async {
    final json = await _postJson('/groups/$groupId/leave', <String, dynamic>{}, sessionToken: sessionToken);
    return RavenApiGroup.fromJson(json);
  }

  Future<RavenApiGroup> closeGroup({required String sessionToken, required String groupId}) async {
    final json = await _postJson('/groups/$groupId/close', <String, dynamic>{}, sessionToken: sessionToken);
    return RavenApiGroup.fromJson(json);
  }

  Future<RavenApiGroupMessage> sendGroupMessage({
    required String sessionToken,
    required String groupId,
    required String clientMessageId,
    required String senderRavenId,
    required String encryptedPayload,
  }) async {
    final json = await _postJson(
      '/groups/$groupId/messages',
      {
        'client_message_id': clientMessageId,
        'sender_raven_id': senderRavenId,
        'encrypted_payload': encryptedPayload,
      },
      sessionToken: sessionToken,
    );
    return RavenApiGroupMessage.fromJson(json);
  }

  Future<List<RavenApiGroupMessage>> fetchGroupInbox({required String sessionToken, required String ravenId}) async {
    final list = await _getList('/groups/inbox/$ravenId', sessionToken: sessionToken);
    return list.whereType<Map<String, dynamic>>().map(RavenApiGroupMessage.fromJson).toList();
  }

  Future<RavenApiGroupMessage> markGroupMessageDelivered({required String sessionToken, required String messageId}) async {
    final json = await _postJson('/groups/messages/$messageId/delivered', <String, dynamic>{}, sessionToken: sessionToken);
    return RavenApiGroupMessage.fromJson(json);
  }

  Future<List<RavenApiGroupInvite>> fetchGroupInvites({required String sessionToken, required String ravenId}) async {
    final list = await _getList('/groups/invites/$ravenId', sessionToken: sessionToken);
    return list.whereType<Map<String, dynamic>>().map(RavenApiGroupInvite.fromJson).toList();
  }

  Future<RavenApiGroup> respondGroupInvite({required String sessionToken, required String groupId, required bool accept}) async {
    final json = await _postJson('/groups/$groupId/invites/respond', {'response': accept ? 'accept' : 'decline'}, sessionToken: sessionToken);
    return RavenApiGroup.fromJson(json);
  }
}
