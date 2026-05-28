part of raven_app;

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
                    imageUrl: vault.avatarUrl,
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
    final avatarController = TextEditingController(text: vault.avatarUrl);
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
                      maxLength: 160,
                      decoration: const InputDecoration(labelText: 'Local description', counterText: ''),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: avatarController,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Profile photo URL',
                        hintText: 'https://example.com/photo.png',
                        counterText: '',
                      ),
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
                      avatarUrl: avatarController.text,
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
    avatarController.dispose();
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
