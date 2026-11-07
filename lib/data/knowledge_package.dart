import 'dart:convert';

class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.text,
  });

  final String id;
  final String title;
  final String text;

  factory KnowledgeArticle.fromJson(Map<String, Object?> json) {
    return KnowledgeArticle(
      id: _requiredString(json, 'id'),
      title: _requiredString(json, 'title'),
      text: _requiredString(json, 'text'),
    );
  }
}

class KnowledgePackage {
  const KnowledgePackage({
    required this.packageId,
    required this.sourceTitle,
    required this.license,
    required this.attribution,
    required this.sourceUrl,
    required this.articles,
  });

  final String packageId;
  final String sourceTitle;
  final String license;
  final String attribution;
  final String sourceUrl;
  final List<KnowledgeArticle> articles;

  factory KnowledgePackage.decode(String contents) {
    if (contents.length > 10 * 1024 * 1024) {
      throw const FormatException('El paquete supera el límite de 10 MB.');
    }

    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('El paquete debe ser un objeto JSON.');
    }
    if (decoded['schemaVersion'] != 1) {
      throw const FormatException('Versión de paquete no compatible.');
    }

    final source = decoded['source'];
    final rawArticles = decoded['articles'];
    if (source is! Map<String, Object?> || rawArticles is! List<Object?>) {
      throw const FormatException('Faltan la fuente o los artículos.');
    }

    final sourceUrl = _requiredString(source, 'url');
    final parsedUrl = Uri.tryParse(sourceUrl);
    if (parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        parsedUrl.host.isEmpty) {
      throw const FormatException('La URL de la fuente debe usar HTTPS.');
    }
    if (rawArticles.isEmpty || rawArticles.length > 10000) {
      throw const FormatException(
        'El paquete debe incluir entre 1 y 10000 artículos.',
      );
    }

    final articles = rawArticles.map((article) {
      if (article is! Map<String, Object?>) {
        throw const FormatException('Artículo con formato no válido.');
      }
      return KnowledgeArticle.fromJson(article);
    }).toList(growable: false);
    final ids = articles.map((article) => article.id).toSet();
    if (ids.length != articles.length) {
      throw const FormatException('El paquete contiene identificadores repetidos.');
    }

    return KnowledgePackage(
      packageId: _requiredString(decoded, 'packageId'),
      sourceTitle: _requiredString(source, 'title'),
      license: _requiredString(source, 'license'),
      attribution: _requiredString(source, 'attribution'),
      sourceUrl: sourceUrl,
      articles: articles,
    );
  }
}

String _requiredString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('El campo "$key" es obligatorio.');
  }
  return value.trim();
}
