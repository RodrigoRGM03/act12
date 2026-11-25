enum CalendarAccessStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unavailable,
}

class DeviceCalendarInfo {
  const DeviceCalendarInfo({
    required this.id,
    required this.name,
    required this.isReadOnly,
  });

  final String id;
  final String name;
  final bool isReadOnly;
}

class DeviceCalendarEvent {
  const DeviceCalendarEvent({
    required this.id,
    required this.calendarId,
    required this.title,
    required this.start,
    required this.end,
  });

  final String? id;
  final String calendarId;
  final String title;
  final DateTime? start;
  final DateTime? end;
}

class CalendarOperationException implements Exception {
  const CalendarOperationException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class CalendarRepositoryBackend {
  Future<CalendarAccessStatus> checkPermission();

  Future<CalendarAccessStatus> requestPermission();

  Future<List<DeviceCalendarInfo>> retrieveCalendars();

  Future<List<DeviceCalendarEvent>> retrieveEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  );

  Future<void> createCalendar(String name);

  Future<void> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
  });

  Future<void> deleteEvent(String calendarId, String eventId);
}
