class LocalConversation {
  const LocalConversation._();

  static String? replyTo(String input) {
    final message = _normalize(input);
    if (message.isEmpty) return null;

    if (_matches(message, const [
      r'^(hola|holi|hey|buenas|buenos dias|buenas tardes|buenas noches)( toxo)?$',
      r'^(que tal|como estas|como te va|como vas)( hoy)?$',
    ])) {
      return '¡Hola! 😊 Qué gusto leerte. Estoy aquí para buscar contigo en mi biblioteca local. ¿Qué te gustaría explorar?';
    }

    if (_matches(message, const [
      r'^(gracias|muchas gracias|te lo agradezco|mil gracias)$',
    ])) {
      return '¡De nada! 💚 Me alegra echarte una mano. ¿Buscamos algo más?';
    }

    if (_matches(message, const [
      r'^(adios|hasta luego|nos vemos|chao|bye)$',
    ])) {
      return '¡Hasta luego! 👋 Aquí estaré cuando quieras seguir explorando.';
    }

    if (_matches(message, const [
      r'^(quien eres|que eres|que puedes hacer|para que sirves)$',
    ])) {
      return 'Soy Toxo, tu compa local. Por ahora busco en los textos guardados en este dispositivo y te muestro sus fuentes. Todavía no tengo un modelo generativo, así que si algo no está en la biblioteca, te lo diré con honestidad.';
    }

    return null;
  }

  static bool isCasualChat(String input) {
    final message = _normalize(input);
    if (replyTo(input) != null) return true;
    return _matches(message, const [
      r'\b(quiero|quisiera|me gustaria|tengo ganas de) (hablar|charlar|conversar|platicar)\b',
      r'\b(que haces|que opinas|como te sientes|como estuvo tu dia)\b',
      r'\b(estoy|me siento) (aburrido|sola|solo|cansada|cansado)\b',
      r'^(cuentame|dime) (algo|un chiste|una historia|algo divertido)$',
      r'\b(hablemos|charlemos|platiquemos|conversemos)\b',
    ]);
  }

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
