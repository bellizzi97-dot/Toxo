import 'package:flutter/material.dart';

import '../data/local_conversation.dart';
import '../data/knowledge_database.dart';
import '../data/knowledge_package.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({required this.database, super.key});

  final KnowledgeDatabase database;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          '¡Hola! Soy Toxo. En este prototipo puedo buscar en los paquetes de conocimiento que importes. Mis respuestas son locales y muestran sus fuentes.',
      isAssistant: true,
    ),
  ];

  @override
  void dispose() {
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send([String? suggestion]) {
    final question = (suggestion ?? _input.text).trim();
    if (question.isEmpty) return;
    final style = widget.database.style;
    final socialReply = LocalConversation.replyTo(question);
    final results = socialReply == null ? widget.database.search(question) : [];
    setState(() {
      _messages.add(_ChatMessage(text: question, isAssistant: false));
      if (socialReply != null) {
        _messages.add(
          _ChatMessage(text: socialReply, isAssistant: true),
        );
      } else if (results.isEmpty) {
        _messages.add(
          const _ChatMessage(
            text:
                'Todavía no encuentro eso en tu biblioteca local. Importa un paquete de conocimiento abierto para que pueda buscarlo. No voy a inventar una respuesta.',
            isAssistant: true,
          ),
        );
      } else {
        final intro = style == 'breve'
            ? 'Encontré esto:'
            : '¡Encontré algo útil en tu biblioteca! Aquí tienes los pasajes más cercanos:';
        _messages.add(
          _ChatMessage(
            text: intro,
            isAssistant: true,
            citations: results,
          ),
        );
      }
      _input.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _importPackage() async {
    final controller = TextEditingController();
    final contents = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Importar paquete'),
        content: SizedBox(
          width: 520,
          child: TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            decoration: const InputDecoration(
              hintText: 'Pega aquí el contenido JSON del paquete',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Importar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (contents == null || !mounted) return;

    try {
      final package = KnowledgePackage.decode(contents);
      widget.database.importPackage(package);
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Paquete "${package.sourceTitle}" importado. '
            '${package.articles.length} artículos.',
          ),
        ),
      );
    } on FormatException catch (error) {
      _showError(error.message);
    } on Object catch (error) {
      _showError('No se pudo importar el paquete: $error');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.database.articleCount;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF075C55), Color(0xFF0A9B79)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        titleSpacing: 18,
        title: Row(
          children: [
            const _ToxoMark(),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Toxo',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19),
                ),
                Text(
                  'TU COMPA LOCAL',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Importar conocimiento',
            onPressed: _importPackage,
            icon: const Icon(Icons.library_add_outlined),
          ),
          IconButton(
            tooltip: 'Preferencias',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SettingsScreen(database: widget.database),
                ),
              );
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            child: _LibraryStatus(
              key: ValueKey(count),
              articleCount: count,
              onImport: _importPackage,
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1D6),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lightbulb_rounded, color: Color(0xFFB36B00)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Modo de prueba: busco en textos guardados y te enseño las fuentes. El modelo generativo local aún está en desarrollo.',
                    style: TextStyle(
                      color: Color(0xFF654315),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              itemCount: _messages.length + (_messages.length == 1 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < _messages.length) {
                  return _MessageBubble(message: _messages[index]);
                }
                return _PromptSuggestions(onSelect: _send);
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Pregúntame algo…',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFFD8E9E0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFFD8E9E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(
                            color: Color(0xFF087F70),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  IconButton.filled(
                    tooltip: 'Enviar',
                    onPressed: _send,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB74D),
                      foregroundColor: const Color(0xFF49300D),
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryStatus extends StatelessWidget {
  const _LibraryStatus({
    super.key,
    required this.articleCount,
    required this.onImport,
  });

  final int articleCount;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFDFF4E9),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.offline_bolt_rounded,
            size: 19,
            color: Color(0xFF087F70),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              articleCount == 0
                  ? 'Sin conexión · Biblioteca vacía'
                  : 'Sin conexión · $articleCount artículos disponibles',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TextButton(
            onPressed: onImport,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF075C55),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }
}

class _ToxoMark extends StatelessWidget {
  const _ToxoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD166),
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33002118),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: const Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: Color(0xFF075C55),
        size: 25,
      ),
    );
  }
}

class _PromptSuggestions extends StatelessWidget {
  const _PromptSuggestions({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    const prompts = [
      ('¿Cómo funciona la fotosíntesis?', Icons.eco_rounded),
      ('¿Qué es un volcán?', Icons.landscape_rounded),
      ('Cuéntame del sistema solar', Icons.public_rounded),
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 48, top: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PRUEBA PREGUNTANDO',
            style: TextStyle(
              color: Color(0xFF52756A),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, icon) in prompts)
                ActionChip(
                  avatar: Icon(icon, size: 17, color: const Color(0xFF087F70)),
                  label: Text(label),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD8E9E0)),
                  onPressed: () => onSelect(label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isAssistant,
    this.citations = const [],
  });

  final String text;
  final bool isAssistant;
  final List<KnowledgeResult> citations;
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment:
          message.isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.isAssistant) ...[
                const _AssistantAvatar(),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: message.isAssistant
                        ? Colors.white
                        : const Color(0xFFFFE6B8),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(19),
                      topRight: const Radius.circular(19),
                      bottomLeft: Radius.circular(message.isAssistant ? 6 : 19),
                      bottomRight: Radius.circular(message.isAssistant ? 19 : 6),
                    ),
                    border: message.isAssistant
                        ? Border.all(color: const Color(0xFFE2EFE8))
                        : null,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0C173C30),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        message.text,
                        style: const TextStyle(height: 1.4),
                      ),
                      for (final citation in message.citations) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF7F0),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.auto_stories_rounded,
                                    size: 18,
                                    color: Color(0xFF087F70),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      citation.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF075C55),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              SelectableText(
                                citation.text,
                                style: const TextStyle(height: 1.4),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                '${citation.attribution} · ${citation.license}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: const Color(0xFF52756A)),
                              ),
                              const SizedBox(height: 3),
                              SelectableText(
                                '${citation.sourceTitle} · ${citation.sourceUrl}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: colors.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!message.isAssistant) ...[
                const SizedBox(width: 8),
                const CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFF087F70),
                  child: Icon(
                    Icons.person_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AssistantAvatar extends StatelessWidget {
  const _AssistantAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF29B987), Color(0xFF087F70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.sentiment_satisfied_alt_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
