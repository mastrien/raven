part of raven_app;

class VaultData {
  const VaultData({
    required this.displayName,
    required this.email,
    required this.about,
    required this.contacts,
    required this.conversations,
    this.ravenId = 'rvn_local_user',
    this.avatarUrl = '',
    this.hiddenGroupIds = const [],
  });

  final String displayName;
  final String email;
  final String about;
  final List<ContactData> contacts;
  final List<ConversationData> conversations;
  final String ravenId;
  final String avatarUrl;
  final List<String> hiddenGroupIds;

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
    String? avatarUrl,
    List<String>? hiddenGroupIds,
  }) {
    return VaultData(
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      about: about ?? this.about,
      contacts: contacts ?? this.contacts,
      conversations: conversations ?? this.conversations,
      ravenId: ravenId ?? this.ravenId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hiddenGroupIds: hiddenGroupIds ?? this.hiddenGroupIds,
    );
  }

  Map<String, dynamic> toJson() => {
        'displayName': displayName,
        'email': email,
        'about': about,
        'ravenId': ravenId,
        'avatarUrl': avatarUrl,
        'hiddenGroupIds': hiddenGroupIds,
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
      avatarUrl: json['avatarUrl'] as String? ?? '',
      hiddenGroupIds: ((json['hiddenGroupIds'] as List<dynamic>?) ?? const []).whereType<String>().toList(),
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
    this.remoteDisplayName = '',
    this.avatarUrl = '',
    this.publicKeyPreview = 'public-key-pending',
  });

  final String id;
  final String name;
  final String handle;
  final String ravenId;
  final String remoteDisplayName;
  final String avatarUrl;
  final String initials;
  final int colorValue;
  final String note;
  final String publicKeyPreview;

  String get effectiveRavenId => ravenId.isEmpty ? RavenIdService.stableFromName(remoteDisplayName.isEmpty ? name : remoteDisplayName) : ravenId;
  String get effectiveRemoteDisplayName => remoteDisplayName.isEmpty ? name : remoteDisplayName;

  ContactData copyWith({
    String? id,
    String? name,
    String? handle,
    String? ravenId,
    String? remoteDisplayName,
    String? avatarUrl,
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
      remoteDisplayName: remoteDisplayName ?? this.remoteDisplayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
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
        'remoteDisplayName': effectiveRemoteDisplayName,
        'avatarUrl': avatarUrl,
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
      remoteDisplayName: json['remoteDisplayName'] as String? ?? name,
      avatarUrl: json['avatarUrl'] as String? ?? '',
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
    this.avatarUrl = '',
    this.groupStatus = 'active',
    this.groupMembershipStatus = 'accepted',
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
  final String avatarUrl;
  final String groupStatus;
  final String groupMembershipStatus;

  bool get isClosedGroup => isGroup && groupStatus != 'active';
  bool get isLeftGroup => isGroup && groupMembershipStatus != 'accepted';
  bool get canSendMessages => !blocked && (!isGroup || (groupStatus == 'active' && groupMembershipStatus == 'accepted'));

  String get subtitle {
    if (blocked) return 'Blocked user';
    if (isClosedGroup) return 'Group closed';
    if (isLeftGroup) return 'You left this group';
    if (messages.isEmpty) return 'No messages yet';
    return messages.last.text;
  }
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
    String? avatarUrl,
    String? groupStatus,
    String? groupMembershipStatus,
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
      avatarUrl: avatarUrl ?? this.avatarUrl,
      groupStatus: groupStatus ?? this.groupStatus,
      groupMembershipStatus: groupMembershipStatus ?? this.groupMembershipStatus,
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
        'avatarUrl': avatarUrl,
        'groupStatus': groupStatus,
        'groupMembershipStatus': groupMembershipStatus,
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
      avatarUrl: json['avatarUrl'] as String? ?? '',
      groupStatus: json['groupStatus'] as String? ?? 'active',
      groupMembershipStatus: json['groupMembershipStatus'] as String? ?? 'accepted',
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
    this.isSystem = false,
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
  final bool isSystem;

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
    bool? isSystem,
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
      isSystem: isSystem ?? this.isSystem,
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
        'isSystem': isSystem,
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
      isSystem: json['isSystem'] as bool? ?? false,
    );
  }
}


