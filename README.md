# Actividad 12 - Equipo 6

Aplicación Flutter y Dart para Android. El apartado actual integra el
calendario del dispositivo: consulta calendarios y eventos, solicita los
permisos de lectura y escritura, y permite crear y eliminar eventos.
El proyecto se llama `actividad12_equipo6` y usa
`mx.edu.equipo6.actividad12_equipo6` como identificador de aplicación.

## Requisitos

- Flutter y Dart instalados.
- Android SDK configurado y licencias aceptadas con `flutter doctor
  --android-licenses`.
- Dispositivo Android con depuración USB activada o emulador.
- Google Chrome para revisar la interfaz en web.

## Ejecutar

Desde la raíz del proyecto:

```shell
flutter pub get
flutter devices
flutter run
```

Para abrir una vista previa de la interfaz en Chrome:

```shell
flutter run -d chrome
```

La vista web sirve para revisar la interfaz; no accede a los calendarios del
dispositivo ni valida permisos o funcionalidades nativas de Android.

Para comprobar el proyecto sin ejecutarlo en Android:

```shell
flutter analyze
flutter test
flutter build apk --debug
```

El APK de depuración se genera en
`build/app/outputs/flutter-apk/app-debug.apk`.

## Apartado 1.1: Calendario

### Introducción y caso de uso

El apartado muestra una vista mensual y la agenda del día seleccionado. Con el
permiso del usuario, trabaja con los calendarios reales del dispositivo
Android. El usuario puede elegir un calendario, crear un calendario local si
no hay uno editable, agregar eventos y eliminarlos.

### Dependencias

- `device_calendar`: lectura, creación y eliminación de calendarios y eventos.
- `permission_handler`: consulta y solicitud del permiso de calendario en
  tiempo de ejecución, además de distinguir denegación permanente o
  restringida.
- `flutter_timezone` y `timezone`: conservar la zona horaria local al guardar
  eventos.
- `flutter_localizations` e `intl`: interfaz y fechas en español.

### Configuración Android

`android/app/src/main/AndroidManifest.xml` declara `READ_CALENDAR` y
`WRITE_CALENDAR`. La app solicita ambos permisos en ejecución al tocar
**Permitir acceso**. Si el usuario los bloquea permanentemente, puede ir a
Ajustes; si el sistema los restringe, la interfaz informa que no puede
cambiarlos desde la app.

### Procedimiento

1. Ejecuta `flutter pub get`.
2. Conecta un dispositivo Android (requisito de la actividad) y ejecuta
   `flutter run`.
3. Pulsa **Permitir acceso** y acepta el diálogo del sistema.
4. Selecciona un calendario, toca una fecha y usa **Evento** para guardar uno.
5. Toca el icono de eliminar para quitar un evento del calendario.

### Código fuente

- Interfaz mensual y agenda: [lib/calendar/calendar_page.dart](lib/calendar/calendar_page.dart)
- Abstracción/modelos: [lib/calendar/calendar_models.dart](lib/calendar/calendar_models.dart) y [lib/calendar/calendar_repository.dart](lib/calendar/calendar_repository.dart)
- Integración Android: [lib/calendar/calendar_repository_platform.dart](lib/calendar/calendar_repository_platform.dart)
- Vista previa web sin acceso nativo: [lib/calendar/calendar_repository_stub.dart](lib/calendar/calendar_repository_stub.dart)
- Permisos Android: [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
- Prueba de interfaz y flujo de permiso: [test/widget_test.dart](test/widget_test.dart)

### Capturas y resultado

La vista previa de Chrome muestra la interfaz mensual y explica que el acceso
a los eventos requiere Android. Las capturas del diálogo real de permisos y
de eventos del dispositivo se deben obtener al ejecutar la app en un Android
físico; no se presentan capturas simuladas como evidencia del permiso.
