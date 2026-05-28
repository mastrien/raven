part of raven_app;

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
              PopupMenuItem(value: 'sync', child: Text('Sync backend')),
              PopupMenuDivider(),
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
    } else if (value == 'sync') {
      try {
        final message = await store.syncBackend(mode);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(store._apiErrorMessage(error))));
        }
      }
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
    } else if (value == 'add_to_group') {
      await _showAddToGroupDialog(context, store, conversation.id, modeOverride: mode);
    } else if (value == 'add_members') {
      await _showAddMemberDialog(context, store, conversation.id, modeOverride: mode);
    } else if (value == 'pin') {
      await store.togglePinnedConversation(mode, conversation.id);
    } else if (value == 'clear') {
      final confirmed = await _confirm(context, 'Clear chat?', 'This will remove all messages from this conversation on this device. This cannot be undone.');
      if (confirmed) await store.clearConversation(mode, conversation.id);
    } else if (value == 'delete') {
      final message = conversation.isGroup && conversation.owner
          ? 'This will close the group for everyone and remove it from your chat list. This cannot be undone.'
          : 'This will remove it from your chat list on this device. If this is an active group, you will leave it first.';
      final confirmed = await _confirm(context, conversation.isGroup ? 'Delete group?' : 'Delete chat?', message);
      if (confirmed) {
        final error = await store.deleteConversation(mode, conversation.id);
        if (error != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    } else if (value == 'block') {
      final confirmed = await _confirm(context, 'Block user?', 'You will no longer receive messages or invites from this user in the final app.');
      if (confirmed) await store.blockConversation(mode, conversation.id);
    } else if (value == 'leave') {
      final confirmed = await _confirm(context, 'Leave group?', 'You will stop receiving messages from this group, but the inactive chat will remain in your list.');
      if (confirmed) {
        final error = await store.leaveGroup(mode, conversation.id);
        if (error != null && context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  Future<void> _showNewChatDialog(BuildContext context, RavenStore store) async {
    final controller = TextEditingController();
    String query = '';
    String? error;
    bool loading = false;
    List<RavenApiUser> results = const [];

    Future<void> runSearch(StateSetter setState) async {
      final clean = controller.text.trim();
      if (clean.isEmpty) {
        setState(() => error = 'Enter a Raven ID or display name.');
        return;
      }
      setState(() {
        loading = true;
        error = null;
      });
      try {
        final users = await store.searchBackendUsers(clean);
        setState(() {
          results = users;
          query = clean;
          error = users.isEmpty ? 'No users found.' : null;
        });
      } catch (err) {
        setState(() => error = store._apiErrorMessage(err));
      } finally {
        setState(() => loading = false);
      }
    }

    Future<void> selectUser(BuildContext dialogContext, StateSetter setState, RavenApiUser user) async {
      final result = await store.addConversationWithBackendUser(mode, user);
      if (result != null) {
        setState(() => error = result);
        return;
      }
      if (dialogContext.mounted) Navigator.pop(dialogContext);
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setState) {
            return AlertDialog(
              title: const Text('New chat'),
              content: SizedBox(
                width: 430,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      autofocus: true,
                      maxLength: 64,
                      decoration: const InputDecoration(
                        labelText: 'Search user',
                        hintText: 'Raven ID or display name',
                        counterText: '',
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      textInputAction: TextInputAction.search,
                      onChanged: (value) => setState(() {
                        query = value;
                        results = const [];
                        error = null;
                      }),
                      onSubmitted: (_) => runSearch(setState),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Search uses the Rust backend directory.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: loading ? null : () => runSearch(setState),
                          icon: loading
                              ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.search_rounded),
                          label: const Text('Search'),
                        ),
                      ],
                    ),
                    if (results.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Results', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 230),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final user = results[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: _InitialsAvatar(
                                initials: RavenStore._initialsFromName(user.displayName),
                                color: RavenStore._colorFromName(user.displayName),
                                size: 34,
                              ),
                              title: Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                              subtitle: Text(user.ravenId, maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: const Icon(Icons.arrow_forward_rounded),
                              onTap: () => selectUser(dialogContext, setState, user),
                            );
                          },
                        ),
                      ),
                    ] else if (query.trim().isNotEmpty && error == null && !loading) ...[
                      const SizedBox(height: 10),
                      Text('Press Search to find a user.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
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
    final searchController = TextEditingController();
    final selectedIds = <String>[];
    final selectedLabels = <String, String>{};
    String query = '';
    String? error;
    bool loadingUsers = false;
    List<RavenApiUser> backendResults = const [];

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final vault = store.vaultFor(mode);
            final cleanQuery = query.trim().toLowerCase();
            final contactResults = cleanQuery.isEmpty
                ? vault.contacts.take(8).toList()
                : vault.contacts.where((contact) {
                    return contact.name.toLowerCase().contains(cleanQuery) ||
                        contact.effectiveRemoteDisplayName.toLowerCase().contains(cleanQuery) ||
                        contact.effectiveRavenId.toLowerCase().contains(cleanQuery);
                  }).take(8).toList();
            final typedRavenId = searchController.text.trim();
            final canUseTypedId = RavenValidation.ravenIdError(typedRavenId, ownRavenId: vault.ravenId) == null &&
                !contactResults.any((contact) => contact.effectiveRavenId.toLowerCase() == typedRavenId.toLowerCase()) &&
                !selectedIds.any((id) => id.toLowerCase() == typedRavenId.toLowerCase());

            void selectMember(String ravenId, String label) {
              if (selectedIds.any((id) => id.toLowerCase() == ravenId.toLowerCase())) {
                setState(() => error = 'This member is already in the group.');
                return;
              }
              setState(() {
                selectedIds.add(ravenId);
                selectedLabels[ravenId] = label;
                searchController.clear();
                query = '';
                backendResults = const [];
                error = null;
              });
            }

            Future<void> searchBackendUsers() async {
              final clean = searchController.text.trim();
              if (clean.isEmpty) {
                setState(() => error = 'Enter a Raven ID or display name.');
                return;
              }
              setState(() {
                loadingUsers = true;
                error = null;
              });
              try {
                final users = await store.searchBackendUsers(clean);
                setState(() {
                  backendResults = users;
                  error = users.isEmpty ? 'No users found.' : null;
                });
              } catch (err) {
                setState(() => error = store._apiErrorMessage(err));
              } finally {
                setState(() => loadingUsers = false);
              }
            }

            return AlertDialog(
              title: const Text('New group'),
              content: SizedBox(
                width: 430,
                child: SingleChildScrollView(
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
                      TextField(
                        controller: searchController,
                        maxLength: 64,
                        decoration: const InputDecoration(
                          labelText: 'Search users',
                          hintText: 'Raven ID or display name',
                          counterText: '',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => searchBackendUsers(),
                        onChanged: (value) => setState(() {
                          query = value;
                          backendResults = const [];
                          error = null;
                        }),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Text('Search local contacts or the backend directory.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ),
                          TextButton.icon(
                            onPressed: loadingUsers ? null : searchBackendUsers,
                            icon: loadingUsers
                                ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.search_rounded),
                            label: const Text('Search backend'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (selectedIds.isEmpty)
                        Text('No members selected. You can create the group now and add people later.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                      else
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: selectedIds.map((id) {
                            return InputChip(
                              label: Text(selectedLabels[id] ?? id, overflow: TextOverflow.ellipsis),
                              onDeleted: () => setState(() {
                                selectedIds.remove(id);
                                selectedLabels.remove(id);
                              }),
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 10),
                      if (backendResults.isNotEmpty) ...[
                        const Text('Backend results', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        ...backendResults.map((user) {
                          final alreadySelected = selectedIds.any((id) => id.toLowerCase() == user.ravenId.toLowerCase());
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: _InitialsAvatar(
                              initials: RavenStore._initialsFromName(user.displayName),
                              color: RavenStore._colorFromName(user.displayName),
                              size: 34,
                            ),
                            title: Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(user.ravenId, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: alreadySelected ? const Icon(Icons.check_rounded) : const Icon(Icons.add_rounded),
                            onTap: alreadySelected ? null : () => selectMember(user.ravenId, user.displayName),
                          );
                        }),
                        const SizedBox(height: 10),
                      ],
                      if (contactResults.isEmpty && backendResults.isEmpty && !canUseTypedId && cleanQuery.isNotEmpty)
                        Text('No local users found. Use Search backend to query registered users.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                      else if (cleanQuery.isNotEmpty || contactResults.isNotEmpty) ...[
                        const Text('Local contacts', style: TextStyle(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 6),
                        ...contactResults.map((contact) {
                          final alreadySelected = selectedIds.any((id) => id.toLowerCase() == contact.effectiveRavenId.toLowerCase());
                          return ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: _InitialsAvatar(
                              initials: contact.initials,
                              color: Color(contact.colorValue),
                              imageUrl: contact.avatarUrl,
                              size: 34,
                            ),
                            title: Text(contact.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(contact.effectiveRavenId, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: alreadySelected ? const Icon(Icons.check_rounded) : const Icon(Icons.add_rounded),
                            onTap: alreadySelected ? null : () => selectMember(contact.effectiveRavenId, contact.name),
                          );
                        }),
                        if (canUseTypedId)
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.alternate_email_rounded),
                            title: Text('Use $typedRavenId', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: const Text('Backend will verify this Raven ID later.'),
                            trailing: const Icon(Icons.add_rounded),
                            onTap: () => selectMember(typedRavenId, typedRavenId),
                          ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: 10),
                        Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                FilledButton(
                  onPressed: () async {
                    final result = await store.addGroupConversation(mode, groupNameController.text, selectedIds);
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
    searchController.dispose();
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
  final searchController = TextEditingController();
  String query = '';
  String? error;
  bool loadingUsers = false;
  List<RavenApiUser> backendResults = const [];

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final vault = store.vaultFor(mode);
        final conversation = store.conversationById(mode, conversationId);
        final existing = conversation?.memberRavenIds ?? const <String>[];
        final cleanQuery = query.trim().toLowerCase();
        final contactResults = cleanQuery.isEmpty
            ? vault.contacts.take(8).toList()
            : vault.contacts.where((contact) {
                return contact.name.toLowerCase().contains(cleanQuery) ||
                    contact.effectiveRemoteDisplayName.toLowerCase().contains(cleanQuery) ||
                    contact.effectiveRavenId.toLowerCase().contains(cleanQuery);
              }).take(8).toList();
        final typedRavenId = searchController.text.trim();
        final canUseTypedId = RavenValidation.ravenIdError(typedRavenId, ownRavenId: vault.ravenId) == null &&
            !contactResults.any((contact) => contact.effectiveRavenId.toLowerCase() == typedRavenId.toLowerCase()) &&
            !existing.any((id) => id.toLowerCase() == typedRavenId.toLowerCase());

        Future<void> add(String ravenId) async {
          final result = await store.addGroupMember(mode, conversationId, ravenId);
          if (result != null) {
            setState(() => error = result);
            return;
          }
          if (context.mounted) Navigator.pop(context);
        }

        Future<void> searchBackendUsers() async {
          final clean = searchController.text.trim();
          if (clean.isEmpty) {
            setState(() => error = 'Enter a Raven ID or display name.');
            return;
          }
          setState(() {
            loadingUsers = true;
            error = null;
          });
          try {
            final users = await store.searchBackendUsers(clean);
            setState(() {
              backendResults = users;
              error = users.isEmpty ? 'No users found.' : null;
            });
          } catch (err) {
            setState(() => error = store._apiErrorMessage(err));
          } finally {
            setState(() => loadingUsers = false);
          }
        }

        return AlertDialog(
          title: const Text('Add members'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: searchController,
                  autofocus: true,
                  maxLength: 64,
                  decoration: const InputDecoration(
                    labelText: 'Search users',
                    hintText: 'Raven ID or display name',
                    counterText: '',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => searchBackendUsers(),
                  onChanged: (value) => setState(() {
                    query = value;
                    backendResults = const [];
                    error = null;
                  }),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text('If a user blocks automatic group adds, the backend will send an invitation instead.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: loadingUsers ? null : searchBackendUsers,
                      icon: loadingUsers
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
                      label: const Text('Search backend'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (backendResults.isNotEmpty) ...[
                  const Text('Backend results', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  ...backendResults.map((user) {
                    final alreadyInGroup = existing.any((id) => id.toLowerCase() == user.ravenId.toLowerCase());
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: _InitialsAvatar(
                        initials: RavenStore._initialsFromName(user.displayName),
                        color: RavenStore._colorFromName(user.displayName),
                        size: 34,
                      ),
                      title: Text(user.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(user.ravenId, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: alreadyInGroup ? const Icon(Icons.check_rounded) : const Icon(Icons.add_rounded),
                      onTap: alreadyInGroup ? null : () => add(user.ravenId),
                    );
                  }),
                  const SizedBox(height: 10),
                ],
                if (contactResults.isEmpty && backendResults.isEmpty && !canUseTypedId && cleanQuery.isNotEmpty)
                  Text('No local users found. Use Search backend to query registered users.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))
                else ...[
                  ...contactResults.map((contact) {
                    final alreadyInGroup = existing.any((id) => id.toLowerCase() == contact.effectiveRavenId.toLowerCase());
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: _InitialsAvatar(
                        initials: contact.initials,
                        color: Color(contact.colorValue),
                        imageUrl: contact.avatarUrl,
                        size: 34,
                      ),
                      title: Text(contact.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(contact.effectiveRavenId, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: alreadyInGroup ? const Icon(Icons.check_rounded) : const Icon(Icons.add_rounded),
                      onTap: alreadyInGroup ? null : () => add(contact.effectiveRavenId),
                    );
                  }),
                  if (canUseTypedId)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.alternate_email_rounded),
                      title: Text('Use $typedRavenId', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: const Text('Backend will verify this Raven ID later.'),
                      trailing: const Icon(Icons.add_rounded),
                      onTap: () => add(typedRavenId),
                    ),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
        );
      },
    ),
  );
  searchController.dispose();
}

Future<void> _showAddToGroupDialog(BuildContext context, RavenStore store, String directConversationId, {VaultMode? modeOverride}) async {
  final mode = modeOverride ?? VaultMode.real;
  final searchController = TextEditingController();
  String query = '';
  String? error;
  bool loadingGroups = false;
  List<RavenApiGroup> backendResults = const [];

  await showDialog<void>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final groups = store.vaultFor(mode).conversations.where((conversation) => conversation.isGroup).toList();
        final cleanQuery = query.trim().toLowerCase();
        final results = cleanQuery.isEmpty
            ? groups
            : groups.where((group) => group.name.toLowerCase().contains(cleanQuery)).toList();

        Future<void> selectLocalGroup(ConversationData group) async {
          final result = await store.addContactToGroup(
            mode,
            directConversationId: directConversationId,
            groupConversationId: group.id,
          );
          if (result != null) {
            setState(() => error = result);
            return;
          }
          if (context.mounted) Navigator.pop(context);
        }

        Future<void> selectBackendGroup(RavenApiGroup group) async {
          final result = await store.addContactToBackendGroup(
            mode,
            directConversationId: directConversationId,
            group: group,
          );
          if (result != null) {
            setState(() => error = result);
            return;
          }
          if (context.mounted) Navigator.pop(context);
        }

        Future<void> searchBackendGroups() async {
          final clean = searchController.text.trim();
          if (clean.isEmpty) {
            setState(() => error = 'Enter a group name.');
            return;
          }
          setState(() {
            loadingGroups = true;
            error = null;
          });
          try {
            final found = await store.searchBackendGroups(mode, clean);
            setState(() {
              backendResults = found;
              error = found.isEmpty ? 'No backend groups found.' : null;
            });
          } catch (err) {
            setState(() => error = store._apiErrorMessage(err));
          } finally {
            setState(() => loadingGroups = false);
          }
        }

        return AlertDialog(
          title: const Text('Add to group'),
          content: SizedBox(
            width: 430,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: searchController,
                  autofocus: true,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Search groups',
                    hintText: 'Group name',
                    counterText: '',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => searchBackendGroups(),
                  onChanged: (value) => setState(() {
                    query = value;
                    backendResults = const [];
                    error = null;
                  }),
                ),
                Row(
                  children: [
                    Expanded(child: Text('Search local groups or the backend groups you belong to.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))),
                    TextButton.icon(
                      onPressed: loadingGroups ? null : searchBackendGroups,
                      icon: loadingGroups
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search_rounded),
                      label: const Text('Search backend'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (backendResults.isNotEmpty) ...[
                  const Text('Backend groups', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  ...backendResults.map((group) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: _InitialsAvatar(
                          initials: RavenStore._initialsFromName(group.name),
                          color: RavenStore._colorFromName(group.name),
                          size: 34,
                        ),
                        title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${group.memberRavenIds.length} member${group.memberRavenIds.length == 1 ? '' : 's'}'),
                        trailing: const Icon(Icons.add_rounded),
                        onTap: () => selectBackendGroup(group),
                      )),
                  const SizedBox(height: 10),
                ],
                if (groups.isEmpty && backendResults.isEmpty)
                  const Text('No local groups exist yet. Create a group first or search the backend.')
                else if (results.isEmpty && backendResults.isEmpty)
                  Text('No groups found.', style: TextStyle(color: Colors.grey.shade600))
                else ...[
                  if (results.isNotEmpty) const Text('Local groups', style: TextStyle(fontWeight: FontWeight.w900)),
                  ...results.map((group) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: _InitialsAvatar(
                          initials: group.initials,
                          color: Color(group.colorValue),
                          imageUrl: group.avatarUrl,
                          size: 34,
                        ),
                        title: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${group.memberRavenIds.length} member${group.memberRavenIds.length == 1 ? '' : 's'}'),
                        trailing: const Icon(Icons.add_rounded),
                        onTap: () => selectLocalGroup(group),
                      )),
                ],
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
                ],
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
        );
      },
    ),
  );
  searchController.dispose();
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
                    imageUrl: conversation.avatarUrl,
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
    this.imageUrl = '',
  });

  final String initials;
  final Color color;
  final double size;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imageUrl.trim();
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        image: cleanUrl.isEmpty
            ? null
            : DecorationImage(
                image: NetworkImage(cleanUrl),
                fit: BoxFit.cover,
                onError: (_, __) {},
              ),
      ),
      child: cleanUrl.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: size * 0.32,
              ),
            )
          : null,
    );
  }
}

