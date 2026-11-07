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
    });
  });
}
