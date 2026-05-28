part of raven_app;

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
          imageUrl: contact.avatarUrl,
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
                  _InitialsAvatar(initials: conversation.initials, color: Color(conversation.colorValue), imageUrl: contact?.avatarUrl ?? conversation.avatarUrl, size: 74),
                  const SizedBox(height: 14),
                  Text(conversation.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  if (contact != null && contact.effectiveRemoteDisplayName != conversation.name) ...[
                    const SizedBox(height: 4),
                    Text('Profile name: ${contact.effectiveRemoteDisplayName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600)),
                  ],
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
          if (contact != null)
            _ProfileAction(
              icon: Icons.badge_rounded,
              title: 'Edit local contact name',
              subtitle: 'Change how this contact appears on your device only.',
              onTap: () => _showEditContactAliasDialog(context, store, mode, contact),
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
            subtitle: 'Search existing groups by group name and select one.',
            onTap: () => _showAddToGroupDialog(context, store, conversationId, modeOverride: mode),
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


  Future<void> _showEditContactAliasDialog(BuildContext context, RavenStore store, VaultMode mode, ContactData contact) async {
    final controller = TextEditingController(text: contact.name);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit local contact name'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Profile name: ${contact.effectiveRemoteDisplayName}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 10),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Saved as', counterText: ''),
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
                final result = await store.updateContactAlias(mode, contact.id, controller.text);
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
    final vault = store.vaultFor(mode);

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
                  _InitialsAvatar(initials: conversation.initials, color: Color(conversation.colorValue), imageUrl: conversation.avatarUrl, size: 74),
                  const SizedBox(height: 14),
                  Text(conversation.name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text('${conversation.memberRavenIds.length} member${conversation.memberRavenIds.length == 1 ? '' : 's'}${conversation.isClosedGroup ? ' · closed' : conversation.isLeftGroup ? ' · left' : ''}', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 6),
                  Text(conversation.owner ? 'You are the owner/admin.' : conversation.isLeftGroup ? 'Inactive member' : 'Member', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (conversation.canSendMessages)
            _ProfileAction(
              icon: Icons.edit_rounded,
              title: 'Edit group',
              subtitle: 'Change the group name or photo URL.',
              onTap: () => _showRenameGroupDialog(context, store, conversation),
            ),
          if (conversation.canSendMessages)
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
              (id) {
                final contact = vault.contacts.cast<ContactData?>().firstWhere(
                      (item) => item?.effectiveRavenId.toLowerCase() == id.toLowerCase(),
                      orElse: () => null,
                    );
                final displayName = contact?.name ?? id;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: _InitialsAvatar(initials: contact?.initials ?? 'R', color: RavenApp.ravenBlue, imageUrl: contact?.avatarUrl ?? '', size: 42),
                    title: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(id),
                    trailing: IconButton(
                      tooltip: 'Copy Raven ID',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: id));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raven ID copied.')));
                      },
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          _ProfileAction(
            icon: Icons.logout_rounded,
            title: 'Leave group',
            subtitle: conversation.canSendMessages
                ? 'Stop receiving messages while keeping this inactive chat in your list.'
                : 'You are no longer an active member of this group.',
            onTap: () async {
              if (!conversation.canSendMessages) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are no longer an active member of this group.')));
                return;
              }
              final confirmed = await _confirm(context, 'Leave group?', 'You will stop receiving messages from this group, but the inactive chat will remain in your list.');
              if (confirmed) {
                final error = await store.leaveGroup(mode, conversationId);
                if (error != null && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                }
              }
            },
          ),
          if (conversation.owner)
            _ProfileAction(
              icon: Icons.delete_forever_rounded,
              title: 'Delete group',
              subtitle: 'Close this group for everyone and remove it from your list.',
              onTap: () async {
                final confirmed = await _confirm(context, 'Delete group?', 'This will close the group for everyone and remove it from your chat list. This cannot be undone.');
                if (confirmed) {
                  final error = await store.deleteConversation(mode, conversationId);
                  if (error != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                    return;
                  }
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
    final avatarController = TextEditingController(text: conversation.avatarUrl);
    String? error;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Edit group'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 40,
                decoration: const InputDecoration(labelText: 'Group name', counterText: ''),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: avatarController,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Group photo URL',
                  hintText: 'https://example.com/group.png',
                  counterText: '',
                ),
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
                final result = await store.updateGroupVisuals(mode, conversation.id, name: controller.text, avatarUrl: avatarController.text);
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
    avatarController.dispose();
  }
}

