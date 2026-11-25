import 'calendar_models.dart';
import 'calendar_repository_stub.dart'
    if (dart.library.io) 'calendar_repository_platform.dart'
    as platform;

export 'calendar_models.dart';

class CalendarRepository implements CalendarRepositoryBackend {
  CalendarRepository({CalendarRepositoryBackend? backend})
    : _backend = backend ?? platform.createCalendarRepository();

  final CalendarRepositoryBackend _backend;

  @override
  Future<CalendarAccessStatus> checkPermission() => _backend.checkPermission();

  @override
  Future<CalendarAccessStatus> requestPermission() =>
      _backend.requestPermission();

  @override
  Future<List<DeviceCalendarInfo>> retrieveCalendars() =>
      _backend.retrieveCalendars();

  @override
  Future<List<DeviceCalendarEvent>> retrieveEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  ) => _backend.retrieveEvents(calendarId, start, end);

  @override
  Future<void> createCalendar(String name) => _backend.createCalendar(name);

  @override
  Future<void> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
  }) => _backend.createEvent(
    calendarId: calendarId,
    title: title,
    start: start,
    end: end,
  );

  @override
  Future<void> deleteEvent(String calendarId, String eventId) =>
      _backend.deleteEvent(calendarId, eventId);
}
