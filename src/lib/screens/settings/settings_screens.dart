part of raven_app;

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
            subtitle: 'Optional. Enable it inside the local lock setup.',
            status: store.emergencyPinEnabled ? (store.emergencyLocked ? 'Active' : 'On') : 'Off',
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
    final realController = TextEditingController(text: store.appLockEnabled ? '' : '258000');
    final decoyController = TextEditingController(text: store.appLockEnabled ? '' : '135790');
    final emergencyController = TextEditingController(text: store.appLockEnabled ? '' : '864209');
    var enabled = store.appLockEnabled;
    var emergencyEnabled = store.emergencyPinEnabled;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Require PIN on app open'),
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
                        error = null;
                      }),
                      title: const Text('Require PIN on app open'),
                      subtitle: const Text('Disabled by default. Enable when you want local coercion protection.'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'When local lock is enabled, Raven does not immediately reveal one fixed account. The Main PIN opens the normal profile, while the Cover PIN opens a separate cover profile. Weak PIN patterns and repeated failed attempts are blocked automatically.',
                      style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                    ),
                    if (enabled) ...[
                      const SizedBox(height: 14),
                      _PinField(controller: realController, label: 'Main PIN'),
                      const SizedBox(height: 10),
                      _PinField(controller: decoyController, label: 'Cover PIN'),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: emergencyEnabled,
                        onChanged: (value) => setState(() {
                          emergencyEnabled = value;
                          error = null;
                        }),
                        title: const Text('Enable Emergency PIN'),
                        subtitle: const Text('Optional. Opens the cover profile and locks the main profile in this MVP.'),
                      ),
                      if (emergencyEnabled) ...[
                        const SizedBox(height: 10),
                        _PinField(controller: emergencyController, label: 'Emergency PIN'),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        'Use the eye icon to check each PIN before saving. The PINs must be different and not obvious.',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.25),
                      ),
                    ] else ...[
                      const SizedBox(height: 10),
                      Text(
                        'Local lock is off. Raven will open after account login without asking for a vault PIN.',
                        style: TextStyle(color: Colors.grey.shade600, height: 1.25),
                      ),
                    ],
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
                    if (!enabled) {
                      final result = await store.configureAppLock(
                        enabled: false,
                        realPin: '',
                        decoyPin: '',
                        emergencyPin: '',
                        emergencyPinEnabled: false,
                      );
                      if (result != null) {
                        setState(() => error = result);
                        return;
                      }
                      if (context.mounted) Navigator.pop(context);
                      return;
                    }

                    final result = await store.configureAppLock(
                      enabled: true,
                      realPin: realController.text.trim(),
                      decoyPin: decoyController.text.trim(),
                      emergencyPin: emergencyController.text.trim(),
                      emergencyPinEnabled: emergencyEnabled,
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

    realController.dispose();
    decoyController.dispose();
    emergencyController.dispose();
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
          !store.emergencyPinEnabled
              ? 'Emergency PIN is currently disabled. Turn it on inside Require PIN on app open.'
              : store.emergencyLocked
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

class _PinField extends StatefulWidget {
  const _PinField({required this.controller, required this.label});

  final TextEditingController controller;
  final String label;

  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField> {
  bool _show = false;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      keyboardType: TextInputType.number,
      maxLength: 6,
      obscureText: !_show,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: widget.label,
        counterText: '',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          tooltip: _show ? 'Hide PIN' : 'Show PIN',
          onPressed: () => setState(() => _show = !_show),
          icon: Icon(_show ? Icons.visibility_off_rounded : Icons.visibility_rounded),
        ),
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

