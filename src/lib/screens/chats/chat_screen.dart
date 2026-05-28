part of raven_app;

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
    final error = await store.sendDirectMessageViaBackend(widget.mode, widget.conversationId, text);
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
    } else if (value == 'add_to_group') {
      await _showAddToGroupDialog(context, store, conversation.id, modeOverride: widget.mode);
    } else if (value == 'add_members') {
      await _showAddMemberDialog(context, store, conversation.id, modeOverride: widget.mode);
    } else if (value == 'pin') {
      await store.togglePinnedConversation(widget.mode, conversation.id);
    } else if (value == 'clear') {
      final confirmed = await _confirm(context, 'Clear chat?', 'This will remove all messages from this conversation on this device. This cannot be undone.');
      if (confirmed) await store.clearConversation(widget.mode, conversation.id);
    } else if (value == 'delete') {
      final message = conversation.isGroup && conversation.owner
          ? 'This will close the group for everyone and remove it from your chat list. This cannot be undone.'
          : 'This will remove it from your chat list on this device. If this is an active group, you will leave it first.';
      final confirmed = await _confirm(context, conversation.isGroup ? 'Delete group?' : 'Delete chat?', message);
      if (confirmed) {
        final error = await store.deleteConversation(widget.mode, conversation.id);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          return;
        }
        if (context.mounted) Navigator.of(context).pop();
      }
    } else if (value == 'block') {
      final confirmed = await _confirm(context, 'Block user?', 'You will no longer receive messages or invites from this user in the final app.');
      if (confirmed) await store.blockConversation(widget.mode, conversation.id);
    } else if (value == 'leave') {
      final confirmed = await _confirm(context, 'Leave group?', 'You will stop receiving messages from this group, but the inactive chat will remain in your list.');
      if (confirmed) {
        final error = await store.leaveGroup(widget.mode, conversation.id);
        if (error != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        }
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
        title: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _handleMenu(store, conversation, conversation.isGroup ? 'group_info' : 'view_contact'),
          child: Row(
          children: [
            _InitialsAvatar(
              initials: conversation.initials,
              color: Color(conversation.colorValue),
              imageUrl: conversation.isGroup ? conversation.avatarUrl : (contact?.avatarUrl ?? conversation.avatarUrl),
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
                        ? '${conversation.memberRavenIds.length} member${conversation.memberRavenIds.length == 1 ? '' : 's'}${conversation.isClosedGroup ? ' · closed' : conversation.isLeftGroup ? ' · left' : ''}'
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
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Chat options',
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (value) => _handleMenu(store, conversation, value),
            itemBuilder: (context) => conversation.isGroup
                ? [
                    const PopupMenuItem(value: 'group_info', child: Text('Group info')),
                    if (conversation.canSendMessages) const PopupMenuItem(value: 'add_members', child: Text('Add members')),
                    PopupMenuItem(value: 'pin', child: Text(conversation.pinned ? 'Unpin chat' : 'Pin chat')),
                    const PopupMenuDivider(),
                    if (conversation.canSendMessages) const PopupMenuItem(value: 'leave', child: Text('Leave group')),
                    PopupMenuItem(value: 'delete', child: Text(conversation.owner ? 'Delete group' : 'Delete from list')),
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
          if (conversation.canSendMessages)
            _LocalComposer(
              controller: _controller,
              autoReply: _autoReply,
              onAutoReplyChanged: (value) => setState(() => _autoReply = value),
              onSend: () => _send(store),
            )
          else
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEDEEF7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  conversation.isClosedGroup ? 'This group was closed.' : 'You are no longer a member of this group.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: RavenApp.ravenDark),
                ),
              ),
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
    if (message.isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, top: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFEDEEF7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

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

