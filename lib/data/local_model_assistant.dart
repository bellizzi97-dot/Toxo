import 'dart:io';

import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'knowledge_database.dart';

class LocalChatTurn {
  const LocalChatTurn({required this.isAssistant, required this.text});

  final bool isAssistant;
  final String text;
}

class LocalChatPrompt {
  const LocalChatPrompt._();

  static String system({
    required String style,
    required bool casual,
    required String memory,
  }) {
    final persona = casual
        ? 'Estás charlando en privado con la persona, no dando una clase. '
            'Responde de forma natural, cálida y espontánea al último mensaje. '
            'Por defecto usa una o dos frases cortas, sin listas, definiciones, '
            'datos enciclopédicos ni fuentes. Reacciona a lo que la persona '
            'dijo, conserva el hilo de los turnos anteriores y haz como máximo '
            'una pregunta sencilla si viene al caso. Solo amplía si te lo piden.'
        : 'La persona pidió información. Responde en español, de forma clara y '
            '${style == 'breve' ? 'breve' : 'cercana'}. Usa únicamente los '
            'pasajes proporcionados como citas; si no alcanzan, dilo y no '
            'inventes fuentes. Puedes explicar conocimiento general, pero aclara '
            'la incertidumbre y recuerda que puedes equivocarte.';
    return 'Eres Toxo, un compañero local, amable y espontáneo. $persona'
        '${memory.isEmpty ? '' : '\nPreferencias que la persona eligió guardar:\n$memory'}';
  }

  static String researchQuestion(String question, String sourceText) =>
      'La persona solicita información sobre: $question\n\n'
      'Pasajes locales para fundamentar la respuesta:\n'
      '${sourceText.isEmpty ? '(No se encontraron pasajes pertinentes.)' : sourceText}';

  static int tokenLimit({required bool casual}) => casual ? 88 : 256;

  static List<LocalChatTurn> recentHistory(Iterable<LocalChatTurn> turns) {
    final nonEmpty = turns
        .where((turn) => turn.text.trim().isNotEmpty)
        .map(
          (turn) => LocalChatTurn(
            isAssistant: turn.isAssistant,
            text: turn.text.length <= 700
                ? turn.text
                : '${turn.text.substring(0, 697)}…',
          ),
        )
        .toList();
    return nonEmpty.length <= 8
        ? nonEmpty
        : nonEmpty.sublist(nonEmpty.length - 8);
  }
}

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
    required bool casual,
    List<LocalChatTurn> history = const [],
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

    chat.addSystem(LocalChatPrompt.system(
      style: style,
      casual: casual,
      memory: memory,
    ));
    for (final turn in history) {
      if (turn.isAssistant) {
        chat.addAssistant(turn.text);
      } else {
        chat.addUser(turn.text);
      }
    }
    chat.addUser(
      casual ? question : LocalChatPrompt.researchQuestion(question, sourceText),
    );

    try {
      await for (final event in chat.generate(
        sampler: const SamplerParams(temperature: 0.7, topP: 0.9),
        maxTokens: LocalChatPrompt.tokenLimit(casual: casual),
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
