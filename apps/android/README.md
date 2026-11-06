# Android app plan

The Android app will use a local-first architecture and communicate with the backend through a local API or embedded service.

## Current direction

- Kotlin + Jetpack Compose
- local data persistence with Room
- optional backend service or direct local inference path
- offline knowledge access from local files or a local database

## MVP goal

A lightweight mobile client that can:

- ask questions
- show assistant responses
- save memories locally
- keep the experience offline-first

## Future direction

- voice input
- UI personalization
- local model execution using a mobile inference stack
