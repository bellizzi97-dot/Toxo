import 'dart:async';

import 'package:flutter/material.dart';

import '../data/local_conversation.dart';
import '../data/knowledge_database.dart';
import '../data/knowledge_package.dart';
import '../data/local_model_assistant.dart';
import '../data/offline_pack_manager.dart';
import 'settings_screen.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.database,
    required this.packManager,
    super.key,
  });

  final KnowledgeDatabase database;
  final OfflinePackManager packManager;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  PackProgress? _packProgress;
  bool _packInstalled = false;
  bool _packBusy = false;
  DateTime? _lastProgressPaint;
  PackInstallStage? _lastPaintedStage;
  LocalModelAssistant? _assistant;
  StreamSubscription<String>? _generation;
  Completer<void>? _generationCompletion;
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          '¡Hola! Soy Toxo. Puedo buscar en mi biblioteca y, cuando descargues el pack, conversar con un modelo pequeño que funciona en tu teléfono.',
      isAssistant: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _refreshPackStatus();
  }

  @override
  void dispose() {
    _generation?.cancel();
    widget.packManager.close();
    unawaited(_assistant?.dispose());
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPackStatus() async {
    final installed = await widget.packManager.isInstalled;
    if (mounted) setState(() => _packInstalled = installed);
  }

  Future<void> _send([String? suggestion]) async {
    if (_generation != null) return;
    final question = (suggestion ?? _input.text).trim();
    if (question.isEmpty) return;
    final style = widget.database.style;
    final socialReply = LocalConversation.replyTo(question);
    final List<KnowledgeResult> results = socialReply == null
        ? widget.database.search(question)
        : const <KnowledgeResult>[];
    final installed = socialReply == null && await widget.packManager.isInstalled;
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: question, isAssistant: false));
      if (socialReply != null) {
        _messages.add(
          _ChatMessage(text: socialReply, isAssistant: true),
        );
      } else if (installed) {
        _messages.add(
          _ChatMessage(
            text: 'Preparando el modelo local…',
            isAssistant: true,
            citations: results,
          ),
        );
      } else if (results.isEmpty) {
        _messages.add(
          const _ChatMessage(
            text:
                'Todavía no encuentro eso en tu biblioteca local. Descarga el pack para habilitar respuestas generadas por el modelo local; no voy a inventar una respuesta.',
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
    if (installed) {
      final messageIndex = _messages.length - 1;
      final completer = Completer<void>();
      _generationCompletion = completer;
      _assistant ??= LocalModelAssistant(
        modelPath: widget.packManager.modelFile.path,
        database: widget.database,
      );
      _generation = _assistant!
          .generate(question: question, sources: results)
          .listen(
            (token) {
              if (!mounted) return;
              final current = _messages[messageIndex];
              setState(() {
                _messages[messageIndex] = _ChatMessage(
                  text: current.text == 'Preparando el modelo local…'
                      ? token
                      : current.text + token,
                  isAssistant: true,
                  citations: results,
                );
              });
              _scrollToBottom();
            },
            onError: (Object error, StackTrace stackTrace) {
              if (mounted) {
                final current = _messages[messageIndex];
                setState(() {
                  _messages[messageIndex] = _ChatMessage(
                    text: current.text == 'Preparando el modelo local…'
                        ? 'No pude iniciar el modelo local: $error'
                        : '${current.text}\n\nLa generación se detuvo: $error',
                    isAssistant: true,
                    citations: results,
                  );
                });
              }
              _finishGeneration(completer);
            },
            onDone: () {
              if (mounted) {
                final current = _messages[messageIndex];
                if (current.text == 'Preparando el modelo local…') {
                  setState(() {
                    _messages[messageIndex] = _ChatMessage(
                      text: 'El modelo no generó texto. Inténtalo de nuevo.',
                      isAssistant: true,
                      citations: results,
                    );
                  });
                }
              }
              _finishGeneration(completer);
            },
            cancelOnError: true,
          );
      await completer.future;
    }
    _scrollToBottom();
  }

  void _finishGeneration(Completer<void> completer) {
    if (identical(_generationCompletion, completer)) {
      _generation = null;
      _generationCompletion = null;
    }
    if (mounted) setState(() {});
    if (!completer.isCompleted) completer.complete();
  }

  Future<void> _cancelGeneration() async {
    final generation = _generation;
    if (generation == null) return;
    _generation = null;
    final completion = _generationCompletion;
    _generationCompletion = null;
    await generation.cancel();
    if (completion != null && !completion.isCompleted) completion.complete();
    if (mounted) setState(() {});
  }

  void _scrollToBottom() {
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

  Future<void> _downloadPack() async {
    if (_packBusy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descargar el pack offline'),
        content: Text(
          'Se descargarán el modelo y la biblioteca abierta '
          '(aprox. ${(widget.packManager.manifest.totalBytes / (1024 * 1024)).ceil()} MiB). '
          'Necesitas conexión y al menos 1 GB libre para la instalación y la memoria temporal. '
          'El contenido se guarda de forma privada en este dispositivo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descargar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _packBusy = true;
      _packProgress = PackProgress(
        stage: PackInstallStage.downloadingKnowledge,
        message: 'Preparando la descarga…',
        downloadedBytes: 0,
        totalBytes: widget.packManager.manifest.totalBytes,
      );
    });
    try {
      await widget.packManager.downloadAndInstall(
        onProgress: (progress) {
          if (!mounted) return;
          final now = DateTime.now();
          final stageChanged = progress.stage != _lastPaintedStage;
          final finished =
              progress.stage == PackInstallStage.ready ||
              progress.stage == PackInstallStage.failed;
          if (stageChanged ||
              finished ||
              _lastProgressPaint == null ||
              now.difference(_lastProgressPaint!) >=
                  const Duration(milliseconds: 150)) {
            _lastPaintedStage = progress.stage;
            _lastProgressPaint = now;
            setState(() => _packProgress = progress);
          }
        },
      );
      await _assistant?.dispose();
      _assistant = null;
      if (mounted && _packProgress?.stage != PackInstallStage.failed) {
        setState(() => _packInstalled = true);
      }
    } on PackDownloadCancelled {
      // The manager already reports the cancellation in the progress panel.
    } on Object catch (error) {
      _showError('No se pudo completar la descarga: $error');
    } finally {
      if (mounted) setState(() => _packBusy = false);
    }
  }

  void _cancelPackDownload() {
    widget.packManager.cancelDownload();
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
          _LibraryStatus(
            articleCount: count,
            onImport: _importPackage,
          ),
          _PackStatus(
            installed: _packInstalled,
            busy: _packBusy,
            progress: _packProgress,
            packBytes: widget.packManager.manifest.totalBytes,
            onDownload: _downloadPack,
            onCancel: _cancelPackDownload,
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
                    'El pack se descarga una vez; después, el chat y la biblioteca funcionan localmente. El modelo puede equivocarse.',
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
                      enabled: _generation == null,
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
                    tooltip: _generation == null ? 'Enviar' : 'Detener respuesta',
                    onPressed: _generation == null ? _send : _cancelGeneration,
                    style: IconButton.styleFrom(
                      backgroundColor: _generation == null
                          ? const Color(0xFFFFB74D)
                          : const Color(0xFF075C55),
                      foregroundColor: _generation == null
                          ? const Color(0xFF49300D)
                          : Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    icon: Icon(
                      _generation == null
                          ? Icons.arrow_upward_rounded
                          : Icons.stop_rounded,
                    ),
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

class _PackStatus extends StatelessWidget {
  const _PackStatus({
    required this.installed,
    required this.busy,
    required this.progress,
    required this.packBytes,
    required this.onDownload,
    required this.onCancel,
  });

  final bool installed;
  final bool busy;
  final PackProgress? progress;
  final int packBytes;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final current = progress;
    final downloading = current?.stage == PackInstallStage.downloadingKnowledge ||
        current?.stage == PackInstallStage.downloadingModel;
    final ready = installed || current?.stage == PackInstallStage.ready;
    final failed = current?.stage == PackInstallStage.failed;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F8F0), Color(0xFFF9F2DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD4EBDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.verified_rounded : Icons.auto_awesome_rounded,
                color: const Color(0xFF087F70),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ready ? 'Pack offline listo' : 'Activa el chat con IA local',
                  style: const TextStyle(
                    color: Color(0xFF075C55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!ready && !busy)
                TextButton.icon(
                  onPressed: onDownload,
                  icon: Icon(
                    failed ? Icons.refresh_rounded : Icons.download_rounded,
                    size: 18,
                  ),
                  label: Text(
                    failed
                        ? 'Reintentar'
                        : 'Descargar · ${(packBytes / (1024 * 1024)).ceil()} MiB',
                  ),
                ),
            ],
          ),
          if (ready)
            const Text(
              'Modelo y biblioteca en almacenamiento privado; el chat puede responder sin conexión.',
              style: TextStyle(fontSize: 12, color: Color(0xFF365D50)),
            )
          else if (current != null) ...[
            const SizedBox(height: 7),
            Text(
              current.message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF365D50)),
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: failed
                  ? 0
                  : downloading
                  ? current.fraction
                  : null,
              minHeight: 6,
              borderRadius: BorderRadius.circular(5),
              color: const Color(0xFF0A9B79),
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${(current.fraction * 100).round()}% · '
                    '${_formatBytes(current.downloadedBytes)} / '
                    '${_formatBytes(current.totalBytes)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
                if (busy && downloading)
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Cancelar'),
                  ),
              ],
            ),
          ] else
            Text(
              'Una descarga de aprox. ${(packBytes / (1024 * 1024)).ceil()} MiB requiere internet. Después, no se necesita red.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF365D50)),
            ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KiB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
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
