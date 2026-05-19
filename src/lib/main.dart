import 'package:flutter/material.dart';
import '../../splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const RavenApp());
}

class RavenApp extends StatelessWidget {
  const RavenApp({super.key});

  static const Color ravenBlue = Color(0xFF3D438F);
  static const Color ravenDark = Color(0xFF121426);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Raven',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ravenBlue,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7FB),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF7F7FB),
          foregroundColor: ravenDark,
          centerTitle: false,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: ravenDark,
            fontSize: 21,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/lock': (context) => const LockScreen(),
      },
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';

  void _tap(String value) {
    if (_pin.length >= 4) return;

    setState(() => _pin += value);

    if (_pin.length == 4) {
      Future.delayed(const Duration(milliseconds: 180), _validatePin);
    }
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  void _validatePin() {
    if (!mounted) return;

    if (_pin == '2580') {
      _openApp(decoyMode: false);
      return;
    }

    if (_pin == '0000') {
      _openApp(decoyMode: true);
      return;
    }

    if (_pin == '9999') {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Modo de emergência ativado'),
          content: const Text(
            'Protótipo: a conta real seria bloqueada e o ambiente discreto seria aberto.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openApp(decoyMode: true);
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Senha inválida para este protótipo.')),
    );
    setState(() => _pin = '');
  }

  void _openApp({required bool decoyMode}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RavenShell(decoyMode: decoyMode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                'Digite sua senha de acesso',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.68),
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  4,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 7),
                    height: 13,
                    width: 13,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length
                          ? Colors.white
                          : Colors.white.withOpacity(0.18),
                    ),
                  ),
                ),
              ),
              const Spacer(),
              _Keypad(onTap: _tap, onBackspace: _backspace),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  'Demo: 2580 abre conta real • 0000 abre conta falsa • 9999 emergência',
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
                  child: const Icon(Icons.backspace_outlined, color: Colors.white70),
                  onPressed: onBackspace,
                );
              }
              return _KeyButton(
                child: Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onPressed: () => onTap(value),
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

class RavenShell extends StatefulWidget {
  const RavenShell({super.key, required this.decoyMode});

  final bool decoyMode;

  @override
  State<RavenShell> createState() => _RavenShellState();
}

class _RavenShellState extends State<RavenShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ChatListScreen(decoyMode: widget.decoyMode),
      SecurityScreen(decoyMode: widget.decoyMode),
      ProfileScreen(decoyMode: widget.decoyMode),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        height: 68,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline_rounded),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Chats',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield_rounded),
            label: 'Segurança',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}

class Conversation {
  const Conversation({
    required this.name,
    required this.subtitle,
    required this.time,
    required this.initials,
    required this.color,
    this.unread = false,
  });

  final String name;
  final String subtitle;
  final String time;
  final String initials;
  final Color color;
  final bool unread;
}

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key, required this.decoyMode});

  final bool decoyMode;

  List<Conversation> get _realConversations => const [
        Conversation(
          name: 'João Perigoso',
          subtitle: 'Online há 11min',
          time: '9:41',
          initials: 'JP',
          color: Color(0xFF6B5B95),
          unread: true,
        ),
        Conversation(
          name: 'starryskies23',
          subtitle: 'Beleza combinado',
          time: '1d',
          initials: 'S',
          color: Color(0xFF2E8B80),
        ),
        Conversation(
          name: 'nebulanomad',
          subtitle: 'Curti seu post',
          time: '1d',
          initials: 'N',
          color: Color(0xFF333A73),
        ),
        Conversation(
          name: 'emberecho',
          subtitle: 'Feliz aniversário!!! 🎉🎉',
          time: '2d',
          initials: 'E',
          color: Color(0xFFC76D7E),
        ),
        Conversation(
          name: 'lunavoyager',
          subtitle: 'Ok!',
          time: '3d',
          initials: 'L',
          color: Color(0xFF7A7F8F),
        ),
        Conversation(
          name: 'shadowlynx',
          subtitle: 'Vou em setembro. E você?',
          time: '4d',
          initials: 'Sx',
          color: Color(0xFF009688),
          unread: true,
        ),
      ];

  List<Conversation> get _decoyConversations => const [
        Conversation(
          name: 'Grupo da Faculdade',
          subtitle: 'A apresentação ficou para amanhã?',
          time: '8:12',
          initials: 'GF',
          color: Color(0xFF5967D6),
          unread: true,
        ),
        Conversation(
          name: 'Mãe',
          subtitle: 'Chega cedo hoje',
          time: 'Ontem',
          initials: 'M',
          color: Color(0xFFE08D3C),
        ),
        Conversation(
          name: 'Trabalho',
          subtitle: 'Enviei o arquivo atualizado',
          time: '2d',
          initials: 'TR',
          color: Color(0xFF4A6572),
        ),
        Conversation(
          name: 'Mercado Bom Preço',
          subtitle: 'Seu cupom semanal chegou',
          time: '4d',
          initials: 'MB',
          color: Color(0xFF59A96A),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final conversations = decoyMode ? _decoyConversations : _realConversations;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Raven'),
            const SizedBox(width: 10),
            _ModeChip(decoyMode: decoyMode),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            onPressed: () => _showComingSoon(context, 'Busca privada'),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Bloquear',
            onPressed: () => Navigator.of(context).pushReplacementNamed('/lock'),
            icon: const Icon(Icons.lock_outline_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
        children: [
          _StatusBanner(decoyMode: decoyMode),
          const SizedBox(height: 12),
          ...conversations.map(
            (conversation) => _ConversationTile(
              conversation: conversation,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      conversation: conversation,
                      decoyMode: decoyMode,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature: planejado para a próxima versão.')),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({required this.decoyMode});

  final bool decoyMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: decoyMode
            ? Colors.orange.withOpacity(0.12)
            : RavenApp.ravenBlue.withOpacity(0.10),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        decoyMode ? 'ambiente discreto' : 'cofre real',
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
  const _StatusBanner({required this.decoyMode});

  final bool decoyMode;

  @override
  Widget build(BuildContext context) {
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
                    decoyMode ? 'Conta falsa ativa' : 'Cofre principal desbloqueado',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    decoyMode
                        ? 'A interface mostra conversas neutras para cenários de coerção.'
                        : 'Protótipo demonstrando chat privado com negação plausível.',
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

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.conversation, required this.onTap});

  final Conversation conversation;
  final VoidCallback onTap;

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
                    color: conversation.color,
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
                    Text(
                      conversation.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                conversation.time,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
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
  });

  final String initials;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: size * 0.32,
        ),
      ),
    );
  }
}

class ChatMessage {
  const ChatMessage({required this.text, required this.mine});

  final String text;
  final bool mine;
}

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.conversation,
    required this.decoyMode,
  });

  final Conversation conversation;
  final bool decoyMode;

  List<ChatMessage> get _messages {
    if (decoyMode) {
      return const [
        ChatMessage(text: 'Oi, viu o horário de amanhã?', mine: false),
        ChatMessage(text: 'Vi sim. Acho que ficou para 9h.', mine: true),
        ChatMessage(text: 'Beleza, obrigado!', mine: false),
        ChatMessage(text: 'Qualquer coisa eu aviso.', mine: true),
      ];
    }

    return const [
      ChatMessage(text: 'Ah?', mine: false),
      ChatMessage(text: 'Legal', mine: false),
      ChatMessage(text: 'Como funciona?', mine: false),
      ChatMessage(
        text: 'Basta editar qualquer texto para inserir a conversa que gostaria de exibir e excluir os balões que não pretende usar.',
        mine: true,
      ),
      ChatMessage(text: 'Bum!', mine: true),
      ChatMessage(text: 'Hmmm', mine: false),
      ChatMessage(text: 'Acho que entendi', mine: false),
      ChatMessage(
        text: 'https://coolors.co/3d3d3d-eeeeee-f5f5f5-4d5382-3a4ed0',
        mine: false,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _InitialsAvatar(
              initials: conversation.initials,
              color: conversation.color,
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
                    decoyMode ? 'Ativo recentemente' : 'Online há 11min',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(onPressed: () {}, icon: const Icon(Icons.call_outlined)),
          IconButton(onPressed: () {}, icon: const Icon(Icons.videocam_outlined)),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: RavenApp.ravenBlue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded, size: 16, color: RavenApp.ravenBlue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      decoyMode
                          ? 'Ambiente discreto: conversa neutra exibida.'
                          : 'Protótipo: mensagens criptografadas e conta protegida por senha.',
                      style: const TextStyle(
                        color: RavenApp.ravenBlue,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              children: [
                Center(
                  child: Text(
                    '30 de novembro de 2023, 9h41',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
                ..._messages.map((message) => _MessageBubble(message: message)),
              ],
            ),
          ),
          const _MessageComposer(),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
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
          child: Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.18,
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8E9F2)),
                ),
                child: Row(
                  children: [
                    Text('Mensagem...', style: TextStyle(color: Colors.grey.shade500)),
                    const Spacer(),
                    Icon(Icons.mic_none_rounded, color: Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Icon(Icons.emoji_emotions_outlined, color: Colors.grey.shade500),
                    const SizedBox(width: 10),
                    Icon(Icons.image_outlined, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            Container(
              height: 48,
              width: 48,
              decoration: const BoxDecoration(
                color: RavenApp.ravenBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({super.key, required this.decoyMode});

  final bool decoyMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Segurança')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        children: [
          _HeroSecurityCard(decoyMode: decoyMode),
          const SizedBox(height: 12),
          _SecurityTile(
            icon: Icons.password_rounded,
            title: 'Senha principal',
            subtitle: 'Abre o cofre real do usuário.',
            status: 'Configurada',
            onTap: () => _featureDialog(context, 'Senha principal'),
          ),
          _SecurityTile(
            icon: Icons.theater_comedy_rounded,
            title: 'Senha secundária',
            subtitle: 'Abre uma conta falsa com conversas neutras.',
            status: 'Demo ativa',
            onTap: () => _featureDialog(context, 'Senha secundária'),
          ),
          _SecurityTile(
            icon: Icons.warning_amber_rounded,
            title: 'Modo emergência',
            subtitle: 'Bloqueia a conta real e exibe o ambiente discreto.',
            status: 'Protótipo',
            onTap: () => _featureDialog(context, 'Modo emergência'),
          ),
          _SecurityTile(
            icon: Icons.app_shortcut_rounded,
            title: 'Ícone camuflado',
            subtitle: 'Permite trocar a aparência externa do app.',
            status: 'Planejado',
            onTap: () => _featureDialog(context, 'Ícone camuflado'),
          ),
          _SecurityTile(
            icon: Icons.timeline_rounded,
            title: 'Minimização de metadados',
            subtitle: 'Objetivo: reduzir logs, rastros e informações expostas.',
            status: 'Pesquisa',
            onTap: () => _featureDialog(context, 'Minimização de metadados'),
          ),
        ],
      ),
    );
  }

  void _featureDialog(BuildContext context, String title) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text(
          'Esta tela demonstra o fluxo de usabilidade. A implementação final deve usar criptografia auditada, armazenamento seguro de chaves e validação cuidadosa do modelo de ameaça.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }
}

class _HeroSecurityCard extends StatelessWidget {
  const _HeroSecurityCard({required this.decoyMode});

  final bool decoyMode;

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
            decoyMode ? 'Ambiente discreto em execução' : 'Proteção contra coerção física',
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
                ? 'O app parece comum, mas não revela o cofre real.'
                : 'Raven combina senha principal, senha falsa e modo de emergência para reduzir exposição em abordagens forçadas.',
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

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.decoyMode});

  final bool decoyMode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InitialsAvatar(
                    initials: decoyMode ? 'FV' : 'RV',
                    color: decoyMode ? const Color(0xFF667085) : RavenApp.ravenBlue,
                    size: 78,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    decoyMode ? 'Usuário comum' : 'Conta Raven',
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    decoyMode ? 'contato.demo@email.com' : 'raven.user@email.com',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ProfileMetric(
                          label: 'Cadastro',
                          value: 'Email',
                          icon: Icons.alternate_email_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ProfileMetric(
                          label: 'Logs',
                          value: 'Mínimos',
                          icon: Icons.storage_rounded,
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
            icon: Icons.logout_rounded,
            title: 'Bloquear app',
            onTap: () => Navigator.of(context).pushReplacementNamed('/lock'),
          ),
          _ProfileAction(
            icon: Icons.delete_sweep_rounded,
            title: 'Limpar sessão local',
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Protótipo: sessão local limpa.')),
            ),
          ),
        ],
      ),
    );
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
  const _ProfileAction({required this.icon, required this.title, required this.onTap});

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: RavenApp.ravenBlue),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
