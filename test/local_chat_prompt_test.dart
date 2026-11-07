import 'package:flutter_test/flutter_test.dart';
import 'package:toxo/data/local_model_assistant.dart';

void main() {
  group('LocalChatPrompt', () {
    test('casual prompt asks for short conversation without citations', () {
      final prompt = LocalChatPrompt.system(
        style: 'detallado',
        casual: true,
        memory: '',
      );

      expect(prompt, contains('charlando en privado'));
      expect(prompt, contains('una o dos frases cortas'));
      expect(prompt, contains('sin listas, definiciones'));
      expect(
        prompt,
        isNot(contains('Preferencias que la persona eligió guardar')),
      );
      expect(LocalChatPrompt.tokenLimit(casual: true), lessThan(100));

      final personalized = LocalChatPrompt.system(
        style: 'breve',
        casual: true,
        memory: '- Prefiere respuestas con humor',
      );
      expect(personalized, contains('Prefiere respuestas con humor'));
    });

    test(
      'research prompt receives only the explicitly retrieved source text',
      () {
        final prompt = LocalChatPrompt.researchQuestion(
          '¿Qué es una estrella?',
          '[Estrellas] Una estrella emite luz propia.',
        );

        expect(prompt, contains('¿Qué es una estrella?'));
        expect(prompt, contains('[Estrellas] Una estrella emite luz propia.'));
        expect(LocalChatPrompt.tokenLimit(casual: false), 256);
      },
    );

    test('history keeps only recent non-empty turns and truncates long text', () {
      final history = LocalChatPrompt.recentHistory([
        for (var index = 0; index < 10; index++)
          LocalChatTurn(
            isAssistant: index.isOdd,
            text: index == 9 ? List.filled(800, 'x').join() : 'turno $index',
          ),
        const LocalChatTurn(isAssistant: true, text: '   '),
      ]);

      expect(history, hasLength(8));
      expect(history.first.text, 'turno 2');
      expect(history.last.text, hasLength(698));
      expect(history.last.text.endsWith('…'), isTrue);
    });
  });
}
