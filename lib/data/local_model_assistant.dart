import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'knowledge_database.dart';

class LocalModelAssistant {
  LocalModelAssistant({
    required this.modelPath,
    required this.database,
  });

  final String modelPath;
  final KnowledgeDatabase database;
  LlamaEngine? _engine;

  Stream<String> generate({
    required String question,
    required List<KnowledgeResult> sources,
  }) async* {
    final engine = await _loadEngine();
    final chat = await engine.createChat();
    final style = database.style;
    final memory = database.memoryEnabled
        ? database.memories.map((item) => '- ${item.note}').join('\n')
        : '';
    final sourceText = sources
        .map((source) => '[${source.title}]\n${source.text}')
        .join('\n\n');

    chat.addSystem(
      'Eres Toxo, un compañero local, amable y espontáneo que responde en '
      'español. Sé ${style == 'breve' ? 'breve' : 'cercano'} y claro. '
      'Usa los fragmentos locales como fuentes cuando sean pertinentes, '
      'pero no inventes citas ni digas que un dato está en la biblioteca si '
      'no aparece ahí. Puedes contestar con conocimiento general; aclara '
      'cuando no estés seguro y recuerda que puedes equivocarte.'
      '${memory.isEmpty ? '' : '\nPreferencias que la persona eligió guardar:\n$memory'}',
    );
    chat.addUser(
      'Fragmentos de la biblioteca local:\n'
      '${sourceText.isEmpty ? '(No se encontraron fragmentos pertinentes.)' : sourceText}'
      '\n\nPregunta: $question',
    );

    try {
      await for (final event in chat.generate(
        sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
        maxTokens: 256,
      )) {
        switch (event) {
          case TokenEvent():
            if (event.text.isNotEmpty) yield event.text;
          case DoneEvent():
            if (event.trailingText.isNotEmpty) yield event.trailingText;
          case ShiftEvent():
            break;
        }
      }
    } finally {
      await chat.dispose();
    }
  }

  Future<LlamaEngine> _loadEngine() async {
    final current = _engine;
    if (current != null) return current;
    final threads = Platform.numberOfProcessors.clamp(1, 4).toInt();
    final engine = await LlamaEngine.spawn(
      modelParams: ModelParams(path: modelPath, gpuLayers: 0),
      contextParams: ContextParams(
        nCtx: 2048,
        nBatch: 256,
        nUbatch: 128,
        nThreads: threads,
        nThreadsBatch: threads,
      ),
    );
    _engine = engine;
    return engine;
  }

  Future<void> dispose() async {
    final engine = _engine;
    _engine = null;
    if (engine != null) await engine.dispose();
  }
}
