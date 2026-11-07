import 'dart:async';

import 'package:flutter/material.dart';

import '../data/app_update_checker.dart';
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
    this.appUpdateChecker,
    this.onAppearanceChanged,
    super.key,
  });

  final KnowledgeDatabase database;
  final OfflinePackManager packManager;
  final AppUpdateChecker? appUpdateChecker;
  final VoidCallback? onAppearanceChanged;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scrollController = ScrollController();
  PackProgress? _packProgress;
  bool _packInstalled = false;
  bool _hasInstalledPack = false;
  bool _packUpdateAvailable = false;
  int? _packDownloadBytes;
  bool _packBusy = false;
  DateTime? _lastProgressPaint;
  PackInstallStage? _lastPaintedStage;
  LocalModelAssistant? _assistant;
  StreamSubscription<String>? _generation;
  Completer<void>? _generationCompletion;
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text:
          '¡Hola! Soy Toxo. Puedo buscar en mi biblioteca y conversar con un modelo local pequeño. A veces puedo equivocarme; si uso la biblioteca, te mostraré las fuentes.',
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
    widget.appUpdateChecker?.close();
    unawaited(_assistant?.dispose());
    _input.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _refreshPackStatus() async {
    final status = await Future.wait<Object>([
      widget.packManager.isInstalled,
      widget.packManager.hasInstalledPack,
      widget.packManager.hasUpdate,
      widget.packManager.bytesToDownload,
    ]);
    if (!mounted) return;
    setState(() {
      _packInstalled = status[0] as bool;
      _hasInstalledPack = status[1] as bool;
      _packUpdateAvailable = status[2] as bool;
      _packDownloadBytes = status[3] as int;
    });
  }

  Future<void> _send([String? suggestion]) async {
    if (_generation != null) return;
    final question = (suggestion ?? _input.text).trim();
    if (question.isEmpty) return;
    final style = widget.database.style;
    final socialReply = LocalConversation.replyTo(question);
    final casualChat = LocalConversation.isCasualChat(question);
    final List<KnowledgeResult> results =
        socialReply == null && !casualChat
        ? widget.database.search(question)
        : const <KnowledgeResult>[];
    final installed = await widget.packManager.hasInstalledPack;
    if (!mounted) return;
    setState(() {
      _messages.add(_ChatMessage(text: question, isAssistant: false));
      if (installed) {
        _messages.add(
          _ChatMessage(
            text: 'Preparando el modelo local…',
            isAssistant: true,
            citations: results,
          ),
        );
      } else if (socialReply != null) {
        _messages.add(
          _ChatMessage(text: socialReply, isAssistant: true),
        );
      } else if (results.isEmpty) {
        _messages.add(
          _ChatMessage(
            text: casualChat
                ? 'Claro, podemos charlar 😊 Ahora puedo responder con frases sencillas; descarga el modelo local para una conversación más flexible. ¿Qué tienes en mente?'
                : 'Todavía no encuentro eso en tu biblioteca local. Descarga el pack para habilitar respuestas generadas por el modelo local; no voy a inventar una respuesta.',
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
    final downloadBytes = await widget.packManager.bytesToDownload;
    if (!mounted) return;
    setState(() => _packDownloadBytes = downloadBytes);
    final downloadDescription = downloadBytes < widget.packManager.manifest.totalBytes
        ? 'Se descargará la biblioteca actualizada '
        '(aprox. ${_formatBytes(downloadBytes)}). '
              'El modelo ya está instalado y no se volverá a descargar.'
        : 'Se descargarán el modelo y la biblioteca abierta '
        '(aprox. ${_formatBytes(downloadBytes)}).';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descargar el pack offline'),
        content: Text(
          '$downloadDescription '
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
        setState(() {
          _packInstalled = true;
          _hasInstalledPack = true;
          _packUpdateAvailable = false;
          _packProgress = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pack offline listo en este dispositivo.')),
        );
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
    final neuralTheme = widget.database.appearance == 'neural';
    return Scaffold(
      backgroundColor:
          neuralTheme ? const Color(0xFF071622) : const Color(0xFFF3FAF5),
      appBar: AppBar(
        toolbarHeight: 72,
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: neuralTheme
                  ? const [Color(0xFF0A2735), Color(0xFF0D3C4B)]
                  : const [Color(0xFF075C55), Color(0xFF0A9B79)],
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
                  builder: (_) => SettingsScreen(
                    database: widget.database,
                    appUpdateChecker: widget.appUpdateChecker,
                    packManager: widget.packManager,
                    onAppearanceChanged: widget.onAppearanceChanged,
                  ),
                ),
              );
              if (mounted) setState(() {});
            },
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Stack(
        children: [
          if (neuralTheme && widget.database.visualEffects != 'off')
            Positioned.fill(
              child: IgnorePointer(
                child: _NeuralBackdrop(
                  intensity: widget.database.visualEffects,
                  key: const ValueKey('neural-network-backdrop'),
                ),
              ),
            ),
          Column(
            children: [
          if (!_packInstalled || _packUpdateAvailable || _packProgress != null)
            _PackStatus(
              installed: _packInstalled,
              hasInstalledPack: _hasInstalledPack,
              updateAvailable: _packUpdateAvailable,
              busy: _packBusy,
              progress: _packProgress,
              packBytes:
                  _packDownloadBytes ?? widget.packManager.manifest.totalBytes,
              onDownload: _downloadPack,
              onCancel: _cancelPackDownload,
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
                        fillColor: neuralTheme
                            ? const Color(0xE8172B3F)
                            : Colors.white,
                        hintStyle: TextStyle(
                          color: neuralTheme
                              ? const Color(0xFF9AB6C0)
                              : null,
                        ),
                        style: TextStyle(
                          color: neuralTheme
                              ? const Color(0xFFF0FAFC)
                              : null,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: neuralTheme
                                ? const Color(0xFF315565)
                                : const Color(0xFFD8E9E0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: neuralTheme
                                ? const Color(0xFF315565)
                                : const Color(0xFFD8E9E0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: neuralTheme
                                ? const Color(0xFF46D9BD)
                                : const Color(0xFF087F70),
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
                          ? neuralTheme
                              ? const Color(0xFF54E2C2)
                              : const Color(0xFFFFB74D)
                          : const Color(0xFF075C55),
                      foregroundColor: _generation == null
                          ? neuralTheme
                              ? const Color(0xFF06232C)
                              : const Color(0xFF49300D)
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
        ],
      ),
    );
  }
}

class _NeuralBackdrop extends StatefulWidget {
  const _NeuralBackdrop({required this.intensity, super.key});

  final String intensity;

  @override
  State<_NeuralBackdrop> createState() => _NeuralBackdropState();
}

class _NeuralBackdropState extends State<_NeuralBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant _NeuralBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldAnimate = widget.intensity == 'dynamic' &&
        !MediaQuery.of(context).disableAnimations;
    if (shouldAnimate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!shouldAnimate && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.intensity == 'subtle' ? 0.22 : 0.55;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: _NeuralNetworkPainter(
          progress: _controller.value,
          opacity: opacity,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _NeuralNetworkPainter extends CustomPainter {
  const _NeuralNetworkPainter({
    required this.progress,
    required this.opacity,
  });

  final double progress;
  final double opacity;

  static const _nodes = <Offset>[
    Offset(.08, .08), Offset(.27, .16), Offset(.48, .09), Offset(.72, .18),
    Offset(.94, .08), Offset(.16, .34), Offset(.38, .30), Offset(.61, .38),
    Offset(.84, .32), Offset(.04, .56), Offset(.26, .53), Offset(.49, .62),
    Offset(.73, .55), Offset(.96, .65), Offset(.13, .82), Offset(.36, .86),
    Offset(.58, .79), Offset(.82, .88), Offset(.98, .93),
  ];

  static const _links = <(int, int)>[
    (0, 1), (0, 5), (1, 2), (1, 5), (1, 6), (2, 3), (2, 6), (3, 4),
    (3, 7), (3, 8), (4, 8), (5, 6), (5, 9), (5, 10), (6, 7), (6, 10),
    (6, 11), (7, 8), (7, 11), (7, 12), (8, 12), (8, 13), (9, 10),
    (9, 14), (10, 11), (10, 14), (10, 15), (11, 12), (11, 15), (11, 16),
    (12, 13), (12, 16), (12, 17), (13, 17), (13, 18), (14, 15), (15, 16),
    (16, 17), (17, 18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final points = _nodes
        .map((node) => Offset(node.dx * size.width, node.dy * size.height))
        .toList(growable: false);
    final line = Paint()
      ..color = const Color(0xFF35D4C1).withOpacity(opacity * .36)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final glow = Paint()
      ..color = const Color(0xFF20C6AF).withOpacity(opacity * .65)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final nodePaint = Paint()
      ..color = const Color(0xFF68EAD4).withOpacity(opacity);

    for (var index = 0; index < _links.length; index++) {
      final (from, to) = _links[index];
      final start = points[from];
      final end = points[to];
      canvas.drawLine(start, end, line);
      final pulsePosition = (progress * 1.8 + index / _links.length) % 1;
      final pulse = Offset.lerp(start, end, pulsePosition)!;
      canvas.drawCircle(pulse, 5, glow);
      canvas.drawCircle(pulse, 1.7, nodePaint);
    }
    for (final point in points) {
      canvas.drawCircle(point, 2.2, nodePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _NeuralNetworkPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}

class _PackStatus extends StatelessWidget {
  const _PackStatus({
    required this.installed,
    required this.hasInstalledPack,
    required this.updateAvailable,
    required this.busy,
    required this.progress,
    required this.packBytes,
    required this.onDownload,
    required this.onCancel,
  });

  final bool installed;
  final bool hasInstalledPack;
  final bool updateAvailable;
  final bool busy;
  final PackProgress? progress;
  final int packBytes;
  final VoidCallback onDownload;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = progress;
    final downloading = current?.stage == PackInstallStage.downloadingKnowledge ||
        current?.stage == PackInstallStage.downloadingModel;
    final ready = installed || current?.stage == PackInstallStage.ready;
    final failed = current?.stage == PackInstallStage.failed;
    final isUpdate = hasInstalledPack && updateAvailable;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: dark
              ? const [Color(0xFF112D3A), Color(0xFF1A3540)]
              : const [Color(0xFFE7F8F0), Color(0xFFF9F2DF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: dark ? const Color(0xFF315565) : const Color(0xFFD4EBDD),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isUpdate
                    ? Icons.system_update_alt_rounded
                    : ready
                    ? Icons.verified_rounded
                    : Icons.auto_awesome_rounded,
                color: isUpdate
                    ? const Color(0xFFB36B00)
                    : dark
                    ? const Color(0xFF64E9CD)
                    : const Color(0xFF087F70),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isUpdate
                      ? 'Actualización del pack disponible'
                      : ready
                      ? 'Pack offline listo'
                      : 'Activa el chat con IA local',
                  style: TextStyle(
                    color: dark
                        ? const Color(0xFFB6F5E9)
                        : const Color(0xFF075C55),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if ((!ready || updateAvailable) && !busy)
                TextButton.icon(
                  onPressed: onDownload,
                  icon: Icon(
                    failed
                        ? Icons.refresh_rounded
                        : isUpdate
                        ? Icons.system_update_alt_rounded
                        : Icons.download_rounded,
                    size: 18,
                  ),
                  label: Text(
                    failed
                        ? 'Reintentar'
                        : isUpdate
                        ? 'Actualizar · ${_formatBytes(packBytes)}'
                        : 'Descargar · ${_formatBytes(packBytes)}',
                  ),
                ),
            ],
          ),
          if (ready && !isUpdate)
            Text(
              'Modelo y biblioteca en almacenamiento privado; el chat puede responder sin conexión.',
              style: TextStyle(
                fontSize: 12,
                color: dark
                    ? const Color(0xFFB1C9D0)
                    : const Color(0xFF365D50),
              ),
            )
          else if (current != null) ...[
            const SizedBox(height: 7),
            Text(
              current.message,
              style: TextStyle(
                fontSize: 12,
                color: dark
                    ? const Color(0xFFB1C9D0)
                    : const Color(0xFF365D50),
              ),
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
              backgroundColor:
                  dark ? const Color(0xFF284652) : Colors.white,
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
          ] else if (isUpdate)
            Text(
              'Hay una versión nueva de la biblioteca o el modelo. Puedes seguir usando el pack actual sin conexión y actualizar cuando quieras.',
              style: TextStyle(
                fontSize: 12,
                color: dark
                    ? const Color(0xFFB1C9D0)
                    : const Color(0xFF365D50),
              ),
            )
          else
            Text(
              'Una descarga de ${_formatBytes(packBytes)} requiere internet. Después, no se necesita red.',
              style: TextStyle(
                fontSize: 12,
                color: dark
                    ? const Color(0xFFB1C9D0)
                    : const Color(0xFF365D50),
              ),
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
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: reduceMotion ? 1 : 0.84, end: 1),
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 520),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(
        scale: scale,
        child: child,
      ),
      child: Container(
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
      ),
    );
  }
}

class _PromptSuggestions extends StatelessWidget {
  const _PromptSuggestions({required this.onSelect});

  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
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
              color: dark
                  ? const Color(0xFF9AB6C0)
                  : const Color(0xFF52756A),
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
                  avatar: Icon(
                    icon,
                    size: 17,
                    color: dark
                        ? const Color(0xFF64E9CD)
                        : const Color(0xFF087F70),
                  ),
                  label: Text(label),
                  backgroundColor: dark
                      ? const Color(0xFF264451)
                      : Colors.white,
                  side: BorderSide(
                    color: dark
                        ? const Color(0xFF315565)
                        : const Color(0xFFD8E9E0),
                  ),
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
    final dark = Theme.of(context).brightness == Brightness.dark;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Align(
      alignment:
          message.isAssistant ? Alignment.centerLeft : Alignment.centerRight,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, (1 - progress) * 10),
            child: child,
          ),
        ),
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
                      ? dark
                          ? const Color(0xE8172B3F)
                          : Colors.white
                      : null,
                  gradient: message.isAssistant
                      ? null
                      : LinearGradient(
                          colors: dark
                              ? const [Color(0xFF167D83), Color(0xFF176B91)]
                              : const [Color(0xFFFFE39A), Color(0xFFFFC56D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(19),
                      topRight: const Radius.circular(19),
                      bottomLeft: Radius.circular(message.isAssistant ? 6 : 19),
                      bottomRight: Radius.circular(message.isAssistant ? 19 : 6),
                    ),
                    border: message.isAssistant
                        ? Border.all(
                            color: dark
                                ? const Color(0xFF315565)
                                : const Color(0xFFE2EFE8),
                          )
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
                        style: TextStyle(
                          height: 1.4,
                          color: dark
                              ? const Color(0xFFE8F5F7)
                              : null,
                        ),
                      ),
                      for (final citation in message.citations) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xFF203E4D)
                                : const Color(0xFFEBF7F0),
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
                                    color: dark
                                        ? const Color(0xFF64E9CD)
                                        : const Color(0xFF087F70),
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    child: Text(
                                      citation.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: dark
                                            ? const Color(0xFFB6F5E9)
                                            : const Color(0xFF075C55),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 7),
                              SelectableText(
                                citation.text,
                                style: TextStyle(
                                  height: 1.4,
                                  color: dark
                                      ? const Color(0xFFE8F5F7)
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Text(
                                '${citation.attribution} · ${citation.license}',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: dark
                                          ? const Color(0xFF9AB6C0)
                                          : const Color(0xFF52756A),
                                    ),
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
