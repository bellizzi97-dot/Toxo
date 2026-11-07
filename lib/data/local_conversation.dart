enum ChatIntent { casual, research }

class LocalConversation {
  const LocalConversation._();

  static String? replyTo(String input, {DateTime? now}) {
    final message = _normalize(input);
    if (message.isEmpty) return null;

    if (_asksForToday(message)) {
      final date = now ?? DateTime.now();
      return 'Hoy es ${_weekdays[date.weekday - 1]}, ${date.day} de '
          '${_months[date.month - 1]} de ${date.year}.';
    }

    if (_asksForTime(message)) {
      final date = now ?? DateTime.now();
      final hour = date.hour.toString().padLeft(2, '0');
      final minute = date.minute.toString().padLeft(2, '0');
      return 'En tu dispositivo son las $hour:$minute.';
    }

    if (RegExp(
      r'^(hola|holi|hey|buenas|buenos dias|buenas tardes|buenas noches)( toxo)?$',
    ).hasMatch(message)) {
      return '¡Hola! 😊 Qué bueno verte. ¿Cómo va tu día? Si quieres, charlamos; mientras no esté instalado el modelo, mis respuestas serán sencillas.';
    }

    if (RegExp(r'^(que tal|como estas|como te va|como vas)( hoy)?$')
        .hasMatch(message)) {
      return '¡Gracias por preguntar! 😊 Estoy aquí contigo. ¿Y tú, cómo vas?';
    }

    if (RegExp(r'^(gracias|muchas gracias|te lo agradezco|mil gracias)$')
        .hasMatch(message)) {
      return '¡De nada! 💚 Qué bueno que te sirvió.';
    }

    if (RegExp(r'^(adios|hasta luego|nos vemos|chao|bye)$')
        .hasMatch(message)) {
      return '¡Hasta luego! 👋 Me gustó charlar contigo.';
    }

    if (RegExp(r'^(quien eres|que eres|que puedes hacer|para que sirves)$')
        .hasMatch(message)) {
      return 'Soy Toxo, tu compa local. Por ahora busco en los textos guardados en este dispositivo y te muestro sus fuentes. Todavía no tengo un modelo generativo, así que si algo no está en la biblioteca, te lo diré con honestidad.';
    }

    if (_asksForJoke(message)) {
      return '¿Qué le dijo un techo a otro? Techo de menos. 😄';
    }

    if (_asksForSomething(message)) {
      return 'Una mini historia: un caracol llegó tarde a una carrera y dijo: '
          '«¡Es que venía a toda baba!». 🐌😄';
    }

    return null;
  }

  static ChatIntent intentFor(
    String input, {
    bool previousTurnWasCasual = false,
  }) {
    final message = _normalize(input);
    if (_asksForToday(message) ||
        _asksForTime(message) ||
        _asksForJoke(message) ||
        _asksForSomething(message)) {
      return ChatIntent.casual;
    }
    if (_isExplicitInformationRequest(message)) return ChatIntent.research;
    if (replyTo(input) != null || _isClearlyConversational(message)) {
      return ChatIntent.casual;
    }
    if (_isInformationQuestion(message)) return ChatIntent.research;
    if (previousTurnWasCasual) return ChatIntent.casual;

    // Ambiguous messages are conversation by default; factual questions and
    // explicit learning requests are routed to local retrieval.
    return ChatIntent.casual;
  }

  static bool isCasualChat(
    String input, {
    bool previousTurnWasCasual = false,
  }) =>
      intentFor(input, previousTurnWasCasual: previousTurnWasCasual) ==
      ChatIntent.casual;

  static String casualFallback(String input) {
    final message = _normalize(input);
    if (RegExp(r'^(hoy )?(estoy|me siento) (cansado|cansada|agotado|agotada)$')
        .hasMatch(message)) {
      return 'Uy, lo siento. Suena a que ha sido un día largo. ¿Quieres contarme qué pasó?';
    }
    if (RegExp(r'^(me gusta|me encanta) ').hasMatch(message)) {
      return '¡Qué bueno! 😊 ¿Qué es lo que más te gusta de eso?';
    }
    if (RegExp(r'^(y tu|y a ti)$').hasMatch(message)) {
      return 'Aquí, acompañándote 😊 Todavía no tengo el modelo local descargado, así que por ahora mis respuestas son sencillas.';
    }
    if (RegExp(r'^(cuentame|dime) algo$').hasMatch(message)) {
      return 'Va, un chistecito: ¿qué hace una abeja en el gimnasio? ¡Zum-ba! 😄 ¿Te cuento otro?';
    }
    return 'Claro, podemos charlar 😊 Aún no tengo el modelo local descargado, así que por ahora mis respuestas son sencillas. ¿Qué tienes en mente?';
  }

  static bool _isExplicitInformationRequest(String message) {
    return _matches(message, const [
      r'\b(que es|que son|quien fue|quienes fueron|quien era|quienes eran)\b',
      r'\b(como funciona|como funcionan|como se forma|como se produce|como se hace|como ocurre|como sucedio)\b',
      r'\b(por que|para que sirve|cual es|cuales son|cuanto mide|cuantos|cuantas|cuando ocurrio|donde esta|donde se encuentra|que significa)\b',
      r'\b(explica|explicame|podrias explicarme|define|investiga|busca|consulta|averigua|dime informacion|dame informacion|informacion sobre|que sabes de|hablame de|hablame sobre|cuentame sobre|quiero saber|quiero conocer|me puedes decir|puedes decirme|podrias decirme)\b',
      r'\b(busca en la biblioteca|usa tus fuentes|quiero investigar|necesito saber|dame detalles)\b',
    ]);
  }

  static bool _isClearlyConversational(String message) {
    return _matches(message, const [
      r'^(hoy )?(estoy|me siento)\b',
      r'^(hoy )?me fue\b',
      r'^(me gusta|me encanta|no me gusta|prefiero)\b',
      r'^(quiero|quisiera|tengo ganas de) (hablar|charlar|conversar|platicar)\b',
      r'^(dime )?(que opinas|que piensas)\b',
      r'^(que haces|que opinas|que piensas|que te parece|que tal|que onda|que pasa|que quieres hacer|como estas|como te va|como vas|como te sientes|como estuvo tu dia|como va tu dia)\b',
      r'^(cuentame|dime|puedes contarme|podrias contarme|me puedes contar) (algo|un chiste|una historia|algo divertido)\b',
      r'^(hablemos|charlemos|platiquemos|conversemos)\b',
      r'^(y tu|y a ti|a mi tambien|jaja|jajaja|entiendo|claro|si|no)$',
    ]);
  }

  static bool _isInformationQuestion(String message) {
    final startsWithQuestionWord = RegExp(
      r'^(que|quien|quienes|cuando|donde|como|por que|para que|cual|cuales|cuanto|cuanta|cuantos|cuantas)\b',
    ).hasMatch(message);
    final asksAboutFact = RegExp(
      r'\b(es|son|fue|eran|esta|estan|tiene|tienen|necesita|necesitan|puede|pueden|causa|causan|produce|producen|contiene|contienen|provoca|provocan|afecta|afectan|significa|sirve)\b',
    ).hasMatch(message);
    return startsWithQuestionWord || asksAboutFact;
  }

  static bool _asksForToday(String message) => RegExp(
    r'^(sabes )?(que dia es hoy|que fecha es hoy|que dia es|que fecha es|cual es la fecha de hoy)$',
  ).hasMatch(message);

  static bool _asksForTime(String message) =>
      RegExp(r'^(sabes )?(que hora es|me dices la hora)$').hasMatch(message);

  static bool _asksForJoke(String message) => RegExp(
    r'^(puedes |podrias |me puedes )?(contarme |contar |decirme |decir |cuentame |dime )?(un )?chiste$',
  ).hasMatch(message);

  static bool _asksForSomething(String message) => RegExp(
    r'^(cuentame|dime|puedes contarme|podrias contarme|me puedes contar) algo$',
  ).hasMatch(message);

  static const _weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  static const _months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static bool _matches(String message, List<String> patterns) {
    return patterns.any((pattern) => RegExp(pattern).hasMatch(message));
  }

  static String _normalize(String input) {
    return input
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàä]'), 'a')
        .replaceAll(RegExp(r'[éèë]'), 'e')
        .replaceAll(RegExp(r'[íìï]'), 'i')
        .replaceAll(RegExp(r'[óòö]'), 'o')
        .replaceAll(RegExp(r'[úùü]'), 'u')
        .replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
