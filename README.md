# Toxo · asistente offline

Base inicial en Flutter para Windows y Android. La interfaz, preferencias y biblioteca están pensadas para funcionar localmente; no se necesita una cuenta ni se envían consultas a un servidor.

## Estado actual

- Chat local de búsqueda con citas y una base SQLite FTS5.
- Al abrirse por primera vez, carga tres artículos breves de demostración con licencia CC0 para probar preguntas sin importar archivos.
- Importación de paquetes JSON con fuente, licencia, atribución y URL HTTPS obligatorias.
- Memoria de preferencias explícitas, desactivada inicialmente; al apagarla, borra las preferencias guardadas.
- Estilo de conversación cercano o breve.
- Interfaz móvil renovada con tonos menta/teal, acentos cálidos y sugerencias de preguntas para probar.
- Los archivos nativos del proyecto (`android/` y `windows/`) todavía deben generarse con Flutter; no están disponibles los SDKs para hacerlo en este entorno.
- **Todavía no genera texto con un modelo de IA.** Devuelve pasajes encontrados y declara cuando la biblioteca no tiene respuesta. La integración nativa con `llama.cpp`/GGUF, la selección de un modelo con licencia compatible y las pruebas de rendimiento en dispositivos son trabajo pendiente.
- No incluye artículos de Wikipedia ni Encarta. Importa únicamente paquetes cuyo contenido y licencia tengas derecho a usar; respeta atribución y demás condiciones de la fuente.

## Paquetes de conocimiento

Pega el JSON del paquete desde **Importar**. El esquema mínimo es:

```json
{
  "schemaVersion": 1,
  "packageId": "identificador-unico",
  "source": {
    "title": "Nombre de la fuente",
    "license": "Licencia exacta",
    "attribution": "Atribución exigida por la fuente",
    "url": "https://example.org/source"
  },
  "articles": [
    {
      "id": "identificador-unico-del-articulo",
      "title": "Título",
      "text": "Texto del artículo"
    }
  ]
}
```

Los paquetes de esta primera versión se limitan a 10 MB y 10 000 artículos. La búsqueda y las citas funcionan sin conexión después de importar el paquete. Aún no hay catálogo ni descarga integrada de corpus.

## Desarrollo y comprobaciones pendientes

Con Flutter instalado:

```text
flutter create --platforms=windows,android .
flutter pub get
flutter test
flutter run -d windows
flutter run -d <id-del-dispositivo-android>
```

Este entorno de desarrollo no incluye Flutter/Dart, Android SDK/ADB, NDK ni Visual Studio C++ Build Tools, por lo que todavía no se han podido ejecutar esas comprobaciones. Antes de distribuir, validar builds Windows/Android, disponibilidad de SQLite FTS5 en ambos targets y operación en modo avión. La app y los paquetes de conocimiento son datos locales; el modelo GGUF deberá ser un componente opcional independiente, con licencia y requisitos de memoria publicados, una vez se integre el runtime.

## APK de prueba en GitHub Actions

El workflow **Android test APK** genera un APK de depuración y ejecuta las pruebas cuando se envía la rama `bellizzi97-dot-ia-offline-multiplataforma`, al abrir un pull request hacia `main`, o al iniciarlo manualmente desde la pestaña **Actions**. No requiere instalar Flutter en tu PC, pero sí que estos cambios estén en GitHub y que Actions esté habilitado.

Cuando termine correctamente, descarga el artefacto `toxo-android-debug-apk` en los detalles de la ejecución y extrae `app-debug.apk`. Transfiérelo al teléfono, permite instalar esa app de prueba cuando Android lo solicite y ábrela. Es una APK de depuración, no una publicación de Play Store. Arranca con tres textos de demostración y funciona sin red para esas búsquedas; todavía no conversa con un modelo generativo local. Puedes enviarme capturas de la interfaz y contar qué te gustó o qué falló para ajustar la siguiente versión.
