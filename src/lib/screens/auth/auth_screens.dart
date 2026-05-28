part of raven_app;

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _routeWhenReady();
  }

  Future<void> _routeWhenReady() async {
    final store = RavenScope.of(context);
    while (mounted && !store.loaded) {
      await Future.delayed(const Duration(milliseconds: 80));
    }
    if (!mounted) return;

    if (!store.hasAccount) {
      navigateAfterTap(context, () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RegisterScreen()),
        );
      });
      return;
    }

    if (!store.isLoggedIn) {
      navigateAfterTap(context, () {
        Navigator.of(context).pushReplacementNamed('/login');
      });
      return;
    }

    if (store.appLockEnabled) {
      navigateAfterTap(context, () {
        Navigator.of(context).pushReplacementNamed('/lock');
      });
      return;
    }

    await store.openDefaultSession();
    if (!mounted) return;
    navigateAfterTap(context, () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const RavenShell(mode: VaultMode.real)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: RavenApp.ravenDark,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final store = RavenScope.of(context);

    final result = await store.beginAccountRegistration(
      email: email,
      password: password,
      displayName: 'Raven User',
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }

    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo code: 123456')));
    navigateAfterTap(context, () {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerifyEmailScreen(
            email: email,
            password: password,
            displayName: 'Raven User',
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Create account',
      subtitle: 'Enter your email and password to sign up for Raven. Your display name starts as Raven User and can be changed later in Profile.',
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: 254,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            maxLength: 128,
            decoration: InputDecoration(
              labelText: 'Account password',
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              ),
            ),
            onSubmitted: (_) => _continue(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _continue,
              child: Text(_busy ? 'Please wait...' : 'Continue'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              navigateAfterTap(context, () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              });
            },
            child: const Text('Already have an account? Log in'),
          ),
        ],
      ),
    );
  }
}

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.password,
    required this.displayName,
  });

  final String email;
  final String password;
  final String displayName;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController(text: '123456');
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final code = _codeController.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });

    final store = RavenScope.of(context);
    final result = await store.registerAccount(
      email: widget.email,
      password: widget.password,
      displayName: widget.displayName,
      code: code,
    );

    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }

    navigateAfterTap(context, () {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RavenShell(mode: VaultMode.real)),
        (_) => false,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Verify your email',
      subtitle: 'We sent a 6-digit code to ${widget.email}. For the local backend demo, use 123456.',
      child: Column(
        children: [
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Verification code',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            onSubmitted: (_) => _create(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _create,
              child: Text(_busy ? 'Verifying...' : 'Verify'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Demo code: 123456')),
            ),
            child: const Text('Resend code'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Change email'),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _showPassword = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = RavenScope.of(context);
    if (_emailController.text.isEmpty) _emailController.text = store.accountEmail;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final store = RavenScope.of(context);
    final result = await store.loginAccount(
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }

    if (store.appLockEnabled) {
      navigateAfterTap(context, () {
        Navigator.of(context).pushReplacementNamed('/lock');
      });
    } else {
      navigateAfterTap(context, () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const RavenShell(mode: VaultMode.real)),
          (_) => false,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = RavenScope.of(context);
    return _AuthScaffold(
      title: 'Log in',
      subtitle: 'Use your Raven account email and password. The local app will sync this session with the backend.',
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: 254,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: !_showPassword,
            maxLength: 128,
            decoration: InputDecoration(
              labelText: 'Account password',
              border: const OutlineInputBorder(),
              counterText: '',
              suffixIcon: IconButton(
                tooltip: _showPassword ? 'Hide password' : 'Show password',
                onPressed: () => setState(() => _showPassword = !_showPassword),
                icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
              ),
            ),
            onSubmitted: (_) => _login(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _login,
              child: Text(_busy ? 'Please wait...' : 'Log in'),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              navigateAfterTap(context, () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => PasswordRecoveryScreen(initialEmail: _emailController.text)),
                );
              });
            },
            child: const Text('Forgot your password?'),
          ),
          TextButton(
            onPressed: () {
              navigateAfterTap(context, () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                );
              });
            },
            child: const Text('Don\'t have an account? Create account'),
          ),
        ],
      ),
    );
  }
}

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<PasswordRecoveryScreen> createState() => _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  late final TextEditingController _emailController = TextEditingController(text: widget.initialEmail.trim());
  final _codeController = TextEditingController(text: '123456');
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _error;
  bool _busy = false;
  bool _codeSent = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _backToLogin() {
    FocusScope.of(context).unfocus();
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    navigateAfterTap(context, () {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    });
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim().toLowerCase();
    final store = RavenScope.of(context);

    setState(() {
      _busy = true;
      _error = null;
    });

    final result = await store.sendPasswordResetCode(email: email);
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }

    setState(() {
      _busy = false;
      _error = null;
      _codeSent = true;
      _codeController.text = '123456';
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo code: 123456')));
  }

  Future<void> _reset() async {
    FocusScope.of(context).unfocus();
    final email = _emailController.text.trim().toLowerCase();
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (!RavenValidation.isValidEmail(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Enter the 6-digit verification code.');
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = 'New account password is required.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Use at least 8 characters for the account password.');
      return;
    }
    if (password.length > 128) {
      setState(() => _error = 'Account password must be at most 128 characters.');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await RavenScope.of(context).recoverAccountPassword(
      email: email,
      code: code,
      newPassword: password,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _busy = false;
        _error = result;
      });
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated. You can log in now.')));
    _backToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Reset password',
      subtitle: _codeSent
          ? 'Enter the verification code and choose a new account password.'
          : 'Enter your account email and Raven will send a verification code. For the local MVP, use the demo code 123456.',
      child: Column(
        children: [
          TextField(
            controller: _emailController,
            enabled: !_codeSent && !_busy,
            keyboardType: TextInputType.emailAddress,
            maxLength: 254,
            decoration: const InputDecoration(labelText: 'Account email', border: OutlineInputBorder(), counterText: ''),
            textInputAction: TextInputAction.next,
            onSubmitted: (_) {
              if (!_codeSent) _sendCode();
            },
          ),
          if (_codeSent) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Verification code', border: OutlineInputBorder(), counterText: ''),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              maxLength: 128,
              decoration: InputDecoration(
                labelText: 'New account password',
                border: const OutlineInputBorder(),
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                ),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              maxLength: 128,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                border: const OutlineInputBorder(),
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: _showConfirmPassword ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                  icon: Icon(_showConfirmPassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                ),
              ),
              onSubmitted: (_) => _reset(),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : (_codeSent ? _reset : _sendCode),
              child: Text(_busy ? 'Please wait...' : (_codeSent ? 'Reset password' : 'Send code')),
            ),
          ),
          const SizedBox(height: 8),
          if (_codeSent)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => setState(() {
                        _error = null;
                        _codeSent = false;
                        _passwordController.clear();
                        _confirmPasswordController.clear();
                      }),
              child: const Text('Change email'),
            ),
          if (_codeSent)
            TextButton(
              onPressed: _busy
                  ? null
                  : () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo code: 123456'))),
              child: const Text('Resend code'),
            ),
          TextButton(
            onPressed: _busy ? null : _backToLogin,
            child: const Text('Back to login'),
          ),
        ],
      ),
    );
  }
}

class _AuthScaffold extends StatelessWidget {
  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RavenApp.pageBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, color: RavenApp.ravenBlue, size: 54),
                      const SizedBox(height: 14),
                      const Text(
                        'Raven',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 22),
                      Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, height: 1.25)),
                      const SizedBox(height: 22),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

