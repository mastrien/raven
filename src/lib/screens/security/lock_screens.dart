part of raven_app;

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

