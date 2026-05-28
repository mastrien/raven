part of raven_app;

void navigateAfterTap(BuildContext context, VoidCallback navigation) {
  Future<void>.delayed(Duration.zero, () {
    if (!context.mounted) return;
    navigation();
  });
}

class RavenApp extends StatefulWidget {
  const RavenApp({super.key});

  static const Color ravenBlue = Color(0xFF3D438F);
  static const Color ravenDark = Color(0xFF121426);
  static const Color pageBg = Color(0xFFF7F7FB);

  @override
  State<RavenApp> createState() => _RavenAppState();
}

class _RavenAppState extends State<RavenApp> {
  final RavenStore _store = RavenStore();

  @override
  void initState() {
    super.initState();
    _store.load();
  }

  @override
  Widget build(BuildContext context) {
    return RavenScope(
      store: _store,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Raven',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: RavenApp.ravenBlue,
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: RavenApp.pageBg,
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            margin: EdgeInsets.zero,
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: RavenApp.pageBg,
            foregroundColor: RavenApp.ravenDark,
            centerTitle: false,
            elevation: 0,
            titleTextStyle: TextStyle(
              color: RavenApp.ravenDark,
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        home: const SplashScreen(),
        routes: {
          '/gate': (context) => const AuthGateScreen(),
          '/login': (context) => const LoginScreen(),
          '/lock': (context) => const LockScreen(),
        },
      ),
    );
  }
}

class RavenScope extends InheritedNotifier<RavenStore> {
  const RavenScope({
    super.key,
    required this.store,
    required super.child,
  }) : super(notifier: store);

  final RavenStore store;

  static RavenStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<RavenScope>();
    assert(scope != null, 'RavenScope was not found in the widget tree.');
    return scope!.store;
  }
}

