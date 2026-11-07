# Toxo · asistente offline para Android

Toxo combina una biblioteca de consulta local con generación de texto en el propio dispositivo. No necesita cuenta ni envía preguntas a un servidor. La descarga inicial del pack sí requiere internet; después de instalarlo, la consulta y la generación están diseñadas para funcionar sin red.

La interfaz móvil tiene ahora un tema oscuro futurista con una red de nodos y conexiones dibujada en Flutter y pulsos animados detrás del chat. Es únicamente decorativa, no representa cálculos reales. En **Preferencias y privacidad → Apariencia** puedes elegir entre **Red neuronal** y **Menta**, y ajustar el fondo a Dinámica, Suave o Sin red. El fondo se detiene si Android solicita reducir el movimiento. La pantalla de chat no mantiene una banda offline; el estado de biblioteca/modelo está en Ajustes.

Toxo también diferencia charla casual de consultas de conocimiento: las peticiones explícitas de conversar no muestran artículos ni citas irrelevantes y, si el modelo está instalado, se envían a la generación local. Sin el modelo, responde con una invitación breve y transparente. Las consultas factuales siguen buscando en la biblioteca y muestran sus fuentes.

## Pack adicional

El botón **Descargar** obtiene el modelo y la biblioteca mediante HTTPS. La aplicación muestra el avance y las etapas de descarga, verificación SHA-256 e instalación/indexado. Los archivos se guardan en el almacenamiento privado de la app; el modelo no está incluido en el APK. Una descarga fallida se puede volver a intentar desde el principio y no conserva archivos parciales como si fueran válidos.

El manifiesto versionado `assets/packs/android_starter_manifest.json` declara URL, tamaño, SHA-256, licencia y atribución de cada recurso. La edición 3 del pack contiene:

- **Qwen2.5-0.5B-Instruct, GGUF Q4_K_M**, aprox. 380 MiB: licencia Apache-2.0; fuente de la cuantización y checksum fijados en el manifiesto.
- **40 artículos en español**: 15 textos originales de Toxo bajo CC0-1.0 y 25 extractos introductorios de Wikipedia en español bajo CC BY-SA 4.0. Cada artículo guarda su licencia, atribución y enlace a la revisión fuente; el archivo `assets/packs/toxo-conocimientos-es-v3.json` mide unos 48 KiB. No es un dump completo de Wikipedia ni una enciclopedia exhaustiva.
- Runtime `llama_cpp_dart` con `llama.cpp`; la integración Android usa un AAR de la versión prerelease `v0.9.0-dev.12`, fijada al commit `04743fdd3755973b7c80741e6180daa4b704e587` y verificada por SHA-256 en CI. Consulta los términos del [runtime](https://github.com/netdur/llama_cpp_dart/blob/v0.9.0-dev.12/LICENSE) y de [Qwen](https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/blob/main/LICENSE).

La app busca primero pasajes locales y los entrega como contexto al modelo; muestra la licencia y fuente correspondiente a cada pasaje. Si no encuentra pasajes, el modelo puede responder con conocimiento general, pero no se inventan citas. El modelo es pequeño, puede equivocarse y su calidad es inferior a la de modelos grandes en la nube. Las preferencias explícitas siguen siendo locales y opcionales.

## Requisitos y límites conocidos

- Solo se produce APK **Android arm64 (64 bits)**. Android de 32 bits no está cubierto. El port a Windows queda explícitamente aplazado.
- La descarga es de unos **380 MiB**. Se recomienda tener al menos **1 GB de espacio libre** antes de empezar; el motor y el contexto de inferencia también usan RAM. Se recomienda un teléfono con **4 GB de RAM o más**, sin garantía de rendimiento en todos los modelos.
- La app necesita red al descargar o actualizar el pack. Los hashes, tamaños y esquema se validan antes de importar el contenido. Al actualizar, Toxo conserva y verifica el modelo si su checksum no cambió; no vuelve a descargar los ~380 MiB del modelo en ese caso.
- Después de instalar la edición 3, el recordatorio de descarga desaparece. La tarjeta del pack solo vuelve a aparecer si falta el pack o si la app incluye un manifiesto con una versión de pack más nueva. Las actualizaciones del pack se empaquetan actualmente con una nueva versión de la app; todavía no existe un canal separado de manifiestos remotos.
- El corpus es una selección inicial, no “todo el conocimiento”. No se incluye contenido propietario de Encarta ni un dump completo de Wikipedia. Se podrán añadir fuentes abiertas en paquetes posteriores, respetando licencia, atribución, espacio y capacidad de indexado.
- En **Preferencias y privacidad → Buscar actualización de Toxo**, la app consulta, solo cuando se toca esa opción, el endpoint oficial de GitHub Releases. Si hay una publicación más nueva, muestra una sugerencia y abre la página oficial. Android requiere aprobación explícita para instalar una APK compatible, firmada con la misma clave. El repositorio todavía no tiene una release APK firmada: por ahora no hay una actualización de app que la app pueda anunciar; los artefactos debug de Actions son para prueba y no son un canal de actualización.
- La tarjeta que invita a descargar el pack desaparece cuando la versión actual está lista. Si un APK posterior incorpora una versión de pack nueva, la tarjeta vuelve a aparecer; cuando solo cambia la biblioteca, se conserva y verifica el modelo existente en vez de volver a descargarlo.
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

## Firma y publicación de versiones Android

Un **release** es una publicación versionada de GitHub (normalmente asociada a un tag como `v1.2.3`) que puede incluir archivos descargables y notas de versión. Un artefacto de Actions es temporal y sirve para pruebas; no es una publicación oficial. Hasta que se publique una release con una APK compatible, el comprobador de versiones no tendrá una actualización instalable que anunciar.

El workflow **Android signed release** construye una APK arm64 firmada y la adjunta a un GitHub Release al subir un tag `vX.Y.Z`; también puede ejecutarse manualmente seleccionando ese tag. Requiere que el propietario del repositorio configure estos cuatro secretos en **Settings → Secrets and variables → Actions**:

- `ANDROID_KEYSTORE_BASE64`: contenido del keystore JKS codificado en Base64.
- `ANDROID_KEYSTORE_PASSWORD`: contraseña del keystore.
- `ANDROID_KEY_ALIAS`: alias de la clave de firma.
- `ANDROID_KEY_PASSWORD`: contraseña de la clave.

Genera tu propio keystore localmente con un JDK instalado. El comando pide los datos y contraseñas de forma interactiva; guarda el archivo en un lugar privado y con respaldo:

```powershell
keytool -genkeypair -v -keystore toxo-upload-key.jks -storetype JKS -alias toxo-upload -keyalg RSA -keysize 2048 -validity 10000
```

En Windows, obtén el valor Base64 para cargarlo directamente como el secreto `ANDROID_KEYSTORE_BASE64`:

```powershell
$keystorePath = Join-Path $PWD "toxo-upload-key.jks"
[Convert]::ToBase64String([IO.File]::ReadAllBytes($keystorePath))
```

Crea los otros tres secretos usando exactamente las contraseñas y el alias elegidos al generar la clave. Nunca subas el keystore al repositorio, no lo adjuntes a issues o chats y no guardes sus contraseñas en archivos versionados. El workflow falla antes de construir o publicar si falta cualquier secreto, valida la firma con `apksigner` y verifica que el ID de paquete siga siendo `app.toxo.toxo`.

La firma es la identidad criptográfica de la app: la APK se firma con una clave privada RSA guardada en ese keystore, y Android comprueba la firma/certificado al instalarla. No se debe cambiar ni perder el keystore para futuras versiones: Android rechazará como actualización una APK firmada con otra clave. En ese caso, el usuario tendría que desinstalar la app anterior antes de instalar la nueva y podría perder los datos locales. Configura y respalda el keystore antes de crear la primera release.

Después de guardar los cuatro secretos, crea y sube un tag de versión `vX.Y.Z` para iniciar la publicación. No se genera una clave ni se publica una versión automáticamente al integrar cambios en `main`.

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
