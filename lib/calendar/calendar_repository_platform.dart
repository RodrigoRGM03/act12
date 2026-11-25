import 'package:device_calendar/device_calendar.dart' as device_calendar;
import 'package:flutter/services.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'calendar_models.dart';

CalendarRepositoryBackend createCalendarRepository() =>
    _DeviceCalendarRepository();

class _DeviceCalendarRepository implements CalendarRepositoryBackend {
  final deviceCalendar = device_calendar.DeviceCalendarPlugin();

  @override
  Future<CalendarAccessStatus> checkPermission() async {
    final permissionStatus = await _guard(
      () => permissions.Permission.calendarFullAccess.status,
    );
    final status = _mapPermissionStatus(permissionStatus);
    if (status != CalendarAccessStatus.granted) {
      return status;
    }

    final result = await _guard(deviceCalendar.hasPermissions);
    _throwForResult(result);
    return result.data == true
        ? CalendarAccessStatus.granted
        : CalendarAccessStatus.denied;
  }

  @override
  Future<CalendarAccessStatus> requestPermission() async {
    final permissionStatus = await _guard(
      () => permissions.Permission.calendarFullAccess.request(),
    );
    final status = _mapPermissionStatus(permissionStatus);
    if (status != CalendarAccessStatus.granted) {
      return status;
    }

    final result = await _guard(deviceCalendar.hasPermissions);
    _throwForResult(result);
    return result.data == true
        ? CalendarAccessStatus.granted
        : CalendarAccessStatus.denied;
  }

  @override
  Future<List<DeviceCalendarInfo>> retrieveCalendars() async {
    final result = await _guard(deviceCalendar.retrieveCalendars);
    _throwForResult(result);
    return (result.data ?? const <device_calendar.Calendar>[])
        .map((calendar) {
          final id = calendar.id;
          if (id == null || id.isEmpty) {
            throw const CalendarOperationException(
              'El dispositivo devolvió un calendario sin identificador.',
            );
          }
          return DeviceCalendarInfo(
            id: id,
            name: calendar.name?.trim().isNotEmpty == true
                ? calendar.name!.trim()
                : 'Calendario sin nombre',
            isReadOnly: calendar.isReadOnly ?? false,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<DeviceCalendarEvent>> retrieveEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async {
    final result = await _guard(
      () => deviceCalendar.retrieveEvents(
        calendarId,
        device_calendar.RetrieveEventsParams(startDate: start, endDate: end),
      ),
    );
    _throwForResult(result);
    return (result.data ?? const <device_calendar.Event>[])
        .map(
          (event) => DeviceCalendarEvent(
            id: event.eventId,
            calendarId: calendarId,
            title: event.title?.trim().isNotEmpty == true
                ? event.title!.trim()
                : 'Evento sin título',
            start: event.start?.toLocal(),
            end: event.end?.toLocal(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> createCalendar(String name) async {
    final result = await _guard(
      () => deviceCalendar.createCalendar(
        name,
        calendarColor: const Color(0xFF315EDC),
        localAccountName: 'Actividad 12 - Equipo 6',
      ),
    );
    _throwForResult(result);
  }

  @override
  Future<void> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {
    final location = await _getLocalTimezone();
    final result = await _guard(
      () => deviceCalendar.createOrUpdateEvent(
        device_calendar.Event(
          calendarId,
          title: title,
          start: timezone.TZDateTime.from(start, location),
          end: timezone.TZDateTime.from(end, location),
        ),
      ),
    );
    if (result == null) {
      throw const CalendarOperationException(
        'El calendario no devolvió el resultado al crear el evento.',
      );
    }
    _throwForResult(result);
  }

  @override
  Future<void> deleteEvent(String calendarId, String eventId) async {
    final result = await _guard(
      () => deviceCalendar.deleteEvent(calendarId, eventId),
    );
    _throwForResult(result);
    if (result.data != true) {
      throw const CalendarOperationException(
        'El evento no pudo eliminarse del calendario.',
      );
    }
  }

  Future<timezone.Location> _getLocalTimezone() async {
    timezone_data.initializeTimeZones();
    final timezoneInfo = await _guard(FlutterTimezone.getLocalTimezone);
    try {
      return timezone.getLocation(timezoneInfo.identifier);
    } on ArgumentError {
      throw CalendarOperationException(
        'La zona horaria del dispositivo no es válida: '
        '${timezoneInfo.identifier}.',
      );
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on PlatformException catch (error) {
      throw CalendarOperationException(
        error.message ??
            'Android no pudo completar la operación del calendario.',
      );
    } on MissingPluginException catch (error) {
      throw CalendarOperationException(
        'No se encontró el complemento del calendario: ${error.message}',
      );
    }
  }

  void _throwForResult<T>(device_calendar.Result<T> result) {
    if (result.isSuccess) {
      return;
    }
    final details = result.errors
        .map((error) => error.errorMessage)
        .where((message) => message.isNotEmpty)
        .join('\n');
    throw CalendarOperationException(
      details.isNotEmpty
          ? details
          : 'El complemento no pudo completar la operación del calendario.',
    );
  }

  CalendarAccessStatus _mapPermissionStatus(
    permissions.PermissionStatus status,
  ) {
    if (status.isGranted) {
      return CalendarAccessStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return CalendarAccessStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return CalendarAccessStatus.restricted;
    }
    return CalendarAccessStatus.denied;
  }
}
