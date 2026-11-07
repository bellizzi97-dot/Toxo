# Toxo · asistente offline para Android

Toxo combina una biblioteca de consulta local con generación de texto en el propio dispositivo. No necesita cuenta ni envía preguntas a un servidor. La descarga inicial del pack sí requiere internet; después de instalarlo, la consulta y la generación están diseñadas para funcionar sin red.

## Pack adicional

El botón **Descargar** obtiene el modelo y la biblioteca mediante HTTPS. La aplicación muestra el avance y las etapas de descarga, verificación SHA-256 e instalación/indexado. Los archivos se guardan en el almacenamiento privado de la app; el modelo no está incluido en el APK. Una descarga fallida se puede volver a intentar desde el principio y no conserva archivos parciales como si fueran válidos.

El manifiesto versionado `assets/packs/android_starter_manifest.json` declara URL, tamaño, SHA-256, licencia y atribución de cada recurso. El pack inicial contiene:

- **Qwen2.5-0.5B-Instruct, GGUF Q4_K_M**, aprox. 380 MiB: licencia Apache-2.0; fuente de la cuantización y checksum fijados en el manifiesto.
- **15 artículos educativos originales en español**, licencia CC0-1.0, en `assets/packs/toxo-conocimientos-es-v1.json`. No es un dump de Wikipedia ni una enciclopedia exhaustiva.
- Runtime `llama_cpp_dart` con `llama.cpp`; la integración Android usa un AAR de la versión prerelease `v0.9.0-dev.12`, fijada al commit `04743fdd3755973b7c80741e6180daa4b704e587` y verificada por SHA-256 en CI. Consulta los términos del [runtime](https://github.com/netdur/llama_cpp_dart/blob/v0.9.0-dev.12/LICENSE) y de [Qwen](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/blob/main/LICENSE).

La app busca primero pasajes locales y los entrega como contexto al modelo; muestra las fuentes encontradas junto a la respuesta. Si no encuentra pasajes, el modelo puede responder con conocimiento general, pero no se inventan citas. El modelo es pequeño, puede equivocarse y su calidad es inferior a la de modelos grandes en la nube. Las preferencias explícitas siguen siendo locales y opcionales.

## Requisitos y límites conocidos

- Solo se produce APK **Android arm64 (64 bits)**. Android de 32 bits no está cubierto. El port a Windows queda explícitamente aplazado.
- La descarga es de unos **380 MiB**. Se recomienda tener al menos **1 GB de espacio libre** antes de empezar; el motor y el contexto de inferencia también usan RAM. Se recomienda un teléfono con **4 GB de RAM o más**, sin garantía de rendimiento en todos los modelos.
- La app necesita red solo cuando la persona toca el botón para bajar el pack. Los hashes, tamaños y esquema se validan antes de importar el contenido. Tras ver **Pack offline listo**, el teléfono no necesita conectividad para buscar, generar o leer las citas.
- El corpus es una muestra inicial, no “todo el conocimiento”. No se incluye contenido propietario de Encarta. Se podrán agregar dumps de Wikipedia u otras obras abiertas en paquetes posteriores, respetando licencia, atribución, espacio y capacidad de indexado.
- El runtime Flutter/Dart es prerelease. La compilación de CI verifica integración de código y APK arm64, pero no sustituye la prueba de inferencia en un teléfono real; la ejecución nativa depende también de memoria, ABI y rendimiento del dispositivo.

## Validación física sin conexión

1. Instala `app-debug.apk` desde GitHub Actions y abre Toxo con Wi-Fi.
2. Toca **Descargar**, deja abierta la app y espera a **Pack offline listo**. La descarga puede consumir unos 380 MiB.
3. Activa el **modo avión** (y confirma que Wi-Fi esté apagado).
4. Prueba `hola`, `¿qué es la fotosíntesis?` y una pregunta que no esté en los artículos, por ejemplo `¿por qué cambia la Luna de fase?`. Confirma que el chat responde, la búsqueda/citas locales funciona y no aparece un error de red.
5. Si algo falla, toma una captura que incluya el mensaje/etapa y anota el modelo de teléfono y la versión de Android. No compartas información personal.

La prueba física de modo avión queda pendiente de realizarse en tu teléfono; desde este entorno no se puede accionar ni validar ese dispositivo.

## Pruebas y APK de GitHub Actions

El workflow **Android test APK** ejecuta las pruebas, prepara y verifica el AAR del runtime y compila el APK debug arm64 al abrir un pull request a `main`, al actualizar ramas configuradas o al lanzarlo manualmente desde **Actions**. No requiere instalar Flutter en tu PC.

Cuando una ejecución termine correctamente, descarga `toxo-android-debug-apk` desde los detalles del workflow y extrae `app-debug.apk`. Es una APK de prueba/debug, no una publicación de Play Store. Las búsquedas, conversaciones locales y preferencias no necesitan iniciar sesión.

## Paquetes de conocimiento importables

Además del pack inicial, se puede pegar JSON desde **Importar**. Cada paquete requiere esquema 1, fuente, licencia, atribución, URL HTTPS y entre 1 y 10 000 artículos (máximo 10 MB):

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
