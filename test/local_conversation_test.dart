import 'package:flutter_test/flutter_test.dart';
import 'package:toxo/data/local_conversation.dart';

void main() {
  group('LocalConversation', () {
    test('answers greetings warmly without searching the knowledge base', () {
      expect(LocalConversation.replyTo('hola'), contains('Qué bueno verte'));
      expect(
        LocalConversation.replyTo('¡Buenos días, Toxo!'),
        contains('¿Cómo va tu día?'),
      );
      expect(
        LocalConversation.replyTo('¿Qué tal?'),
        contains('Gracias por preguntar'),
      );
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
      expect(
        LocalConversation.intentFor('¿Qué son los átomos?'),
        ChatIntent.research,
      );
      expect(
        LocalConversation.intentFor('Explícame cómo se forma una estrella'),
        ChatIntent.research,
      );
      expect(
        LocalConversation.intentFor('Me gusta la música, háblame de fotosíntesis'),
        ChatIntent.research,
      );
      for (final request in [
        'Quiero saber sobre los planetas',
        '¿Podrías explicarme cómo funciona el corazón?',
        'Háblame sobre la historia de México',
        '¿La fotosíntesis necesita luz?',
      ]) {
        expect(
          LocalConversation.intentFor(request),
          ChatIntent.research,
          reason: request,
        );
      }
    });

    test('routes ordinary comments and small talk to conversation', () {
      for (final message in [
        '¿Qué tal?',
        'hoy estoy cansado',
        'me gusta la música',
        'cuéntame algo',
        'quisiera charlar un poco',
        'me fue pesado el día',
      ]) {
        expect(
          LocalConversation.intentFor(message),
          ChatIntent.casual,
          reason: message,
        );
      }
    });

    test('has a short non-encyclopedic fallback when no model is installed', () {
      expect(
        LocalConversation.casualFallback('hoy estoy cansado'),
        contains('día largo'),
      );
      expect(
        LocalConversation.casualFallback('me gusta la música'),
        contains('Qué bueno'),
      );
      expect(
        LocalConversation.casualFallback('cuéntame algo'),
        contains('chistecito'),
      );
      expect(
        LocalConversation.casualFallback('¿y tú?'),
        contains('modelo local descargado'),
      );
    });

    test('keeps follow-ups conversational unless they ask for information', () {
      expect(
        LocalConversation.intentFor(
          '¿Y tú?',
          previousTurnWasCasual: true,
        ),
        ChatIntent.casual,
      );
      expect(
        LocalConversation.intentFor(
          '¿Por qué ocurre eso?',
          previousTurnWasCasual: true,
        ),
        ChatIntent.research,
      );
      expect(
        LocalConversation.intentFor('¿Qué te parece?', previousTurnWasCasual: true),
        ChatIntent.casual,
      );
    });
  });
}
