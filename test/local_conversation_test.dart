import 'package:flutter_test/flutter_test.dart';
import 'package:toxo/data/local_conversation.dart';

void main() {
  group('LocalConversation', () {
    test('answers greetings warmly without searching the knowledge base', () {
      expect(LocalConversation.replyTo('hola'), contains('Qué gusto leerte'));
      expect(
        LocalConversation.replyTo('¡Buenos días, Toxo!'),
        contains('¿Qué te gustaría explorar?'),
      );
      expect(LocalConversation.replyTo('¿Qué tal?'), contains('¡Hola!'));
      expect(LocalConversation.isCasualChat('hola'), isTrue);
    });

    test('handles thanks and farewells', () {
      expect(LocalConversation.replyTo('Muchas gracias'), contains('De nada'));
      expect(LocalConversation.replyTo('¡Adiós!'), contains('Hasta luego'));
    });

    test('explains current capabilities honestly', () {
      final response = LocalConversation.replyTo('¿Quién eres?');

      expect(response, contains('Todavía no tengo un modelo generativo'));
      expect(response, contains('busco en los textos guardados'));
    });

    test('leaves knowledge questions to local retrieval', () {
      expect(LocalConversation.replyTo('¿Cómo funciona la fotosíntesis?'), isNull);
      expect(LocalConversation.isCasualChat('¿Cómo funciona la fotosíntesis?'), isFalse);
    });

    test('routes explicit casual conversation away from knowledge retrieval', () {
      expect(
        LocalConversation.isCasualChat(
          'No tengo nada que investigar y solo quisiera charlar un poco',
        ),
        isTrue,
      );
      expect(LocalConversation.isCasualChat('Cuéntame un chiste'), isTrue);
    });
  });
}
