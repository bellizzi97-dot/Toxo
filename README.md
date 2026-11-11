# Toxo · asistente offline con IA opcional

Aplicación Flutter enfocada por ahora en Android. La biblioteca local no requiere cuenta ni conexión; las funciones opcionales de IA y feedback se comunican con un backend cuando la persona decide usarlas.

## Estado actual

- Chat local de búsqueda con citas y una base SQLite FTS5.
- Al abrirse por primera vez, carga tres artículos breves de demostración con licencia CC0 para probar preguntas sin importar archivos.
- Importación de paquetes JSON con fuente, licencia, atribución y URL HTTPS obligatorias.
- Memoria de preferencias explícitas, desactivada inicialmente; al apagarla, borra las preferencias guardadas.
- Estilo de conversación cercano o breve.
- Interfaz móvil renovada con tonos menta/teal, acentos cálidos y sugerencias de preguntas para probar.
- Saludos, agradecimientos y despedidas comunes reciben una respuesta local amigable y transparente en lugar del mensaje de “no lo encuentro”.
- La búsqueda y las citas de la biblioteca siguen siendo locales. La opción de IA en línea es voluntaria y solo envía una pregunta cuando se pulsa **Preguntar a IA**; no envía el historial, preferencias ni la biblioteca. Sin conexión, el chat local sigue funcionando.
- El backend mínimo en `backend/` usa Gemini desde Cloud Run y guarda feedback explícito en Firestore. La clave de Gemini se configura como secreto en Google Cloud, nunca en Flutter, en la APK ni en GitHub. La integración nativa con `llama.cpp`/GGUF sigue pendiente.
- No incluye artículos de Wikipedia ni Encarta. Importa únicamente paquetes cuyo contenido y licencia tengas derecho a usar; respeta atribución y demás condiciones de la fuente.

## Alcance de plataformas

El objetivo inmediato es que la aplicación sea cómoda y estable en Android: pruebas, APK de depuración y CI priorizan ese target. El port a Windows queda en espera; se conserva Flutter y la lógica portable para facilitarlo más adelante, pero no es parte de los criterios de aceptación actuales.

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

Con Flutter y Android SDK instalados:

```text
flutter create --platforms=android .
flutter pub get
flutter test
flutter run -d <id-del-dispositivo-android>
```

Para configurar la URL pública del backend en una compilación:

```text
flutter build apk --debug --dart-define=TOXO_API_BASE_URL=https://TU-SERVICIO.run.app
```

Para que GitHub Actions incluya la URL en la APK, crea la variable de repositorio `TOXO_API_BASE_URL` en **Settings → Secrets and variables → Actions → Variables** y vuelve a ejecutar el workflow. La URL no es un secreto; la clave de Gemini sí lo es y permanece en Secret Manager.

### Backend de prueba en Google Cloud

Requiere un proyecto de Google Cloud con facturación habilitada. Restringe la clave de AI Studio a la API de Gemini y configura cuotas; en Google Cloud Console, crea un secreto de Secret Manager llamado `gemini-api-key` con esa clave y una base de datos Firestore en modo nativo. No guardes la clave en el repositorio ni en archivos de configuración de Flutter.

Desde PowerShell, habilita los servicios necesarios y da permisos a la cuenta de ejecución de Cloud Run:

```text
gcloud services enable run.googleapis.com secretmanager.googleapis.com firestore.googleapis.com
gcloud secrets add-iam-policy-binding gemini-api-key --member="serviceAccount:CUENTA_DE_SERVICIO" --role="roles/secretmanager.secretAccessor"
gcloud projects add-iam-policy-binding ID_DEL_PROYECTO --member="serviceAccount:CUENTA_DE_SERVICIO" --role="roles/datastore.user"
```

Despliega desde la raíz del repositorio:

```text
gcloud run deploy toxo-api --source backend --region us-central1 --allow-unauthenticated --max 2 --set-secrets=GOOGLE_API_KEY=gemini-api-key:latest
```

El endpoint es público para que la app móvil pueda llamarlo. Limitar instancias no sustituye la protección contra abuso: antes de distribuir ampliamente, añade verificación de Firebase App Check/Play Integrity y límites de solicitudes/cuotas. Revisa también los costos de Gemini, Cloud Run y Firestore. El feedback se guarda en la colección `feedback`; no incluye identificadores del usuario.

La compilación Android y las pruebas se verifican en GitHub Actions. Antes de distribuir, validar la instalación y operación en modo avión en dispositivos físicos. El modelo GGUF deberá ser un componente opcional independiente, con licencia y requisitos de memoria publicados, una vez se integre el runtime.

## APK de prueba en GitHub Actions

El workflow **Android test APK** genera un APK de depuración y ejecuta las pruebas al enviar `main` o `bellizzi97-dot-gemini-chat-feedback`, al abrir un pull request hacia `main`, o al iniciarlo manualmente desde **Actions**. También ejecuta las pruebas del backend. No requiere instalar Flutter en tu PC, pero sí que estos cambios estén en GitHub y que Actions esté habilitado.

Cuando termine correctamente, descarga el artefacto `toxo-android-debug-apk` en los detalles de la ejecución y extrae `app-debug.apk`. Transfiérelo al teléfono, permite instalar esa app de prueba cuando Android lo solicite y ábrela. Es una APK de depuración, no una publicación de Play Store. Arranca con tres textos de demostración y mantiene la búsqueda local disponible sin red. Para activar IA, compílala con la URL del backend ya desplegado.
