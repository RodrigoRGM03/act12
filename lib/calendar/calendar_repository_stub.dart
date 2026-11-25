import 'calendar_models.dart';

CalendarRepositoryBackend createCalendarRepository() =>
    const _UnsupportedCalendarRepository();

class _UnsupportedCalendarRepository implements CalendarRepositoryBackend {
  const _UnsupportedCalendarRepository();

  @override
  Future<CalendarAccessStatus> checkPermission() async =>
      CalendarAccessStatus.unavailable;

  @override
  Future<CalendarAccessStatus> requestPermission() async =>
      CalendarAccessStatus.unavailable;

  @override
  Future<List<DeviceCalendarInfo>> retrieveCalendars() =>
      _unsupported<List<DeviceCalendarInfo>>();

  @override
  Future<List<DeviceCalendarEvent>> retrieveEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  ) => _unsupported<List<DeviceCalendarEvent>>();

  @override
  Future<void> createCalendar(String name) => _unsupported<void>();

  @override
  Future<void> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
  }) => _unsupported<void>();

  @override
  Future<void> deleteEvent(String calendarId, String eventId) =>
      _unsupported<void>();

  Future<T> _unsupported<T>() => Future<T>.error(
    const CalendarOperationException(
      'El acceso a calendarios del dispositivo solo está disponible en Android.',
    ),
  );
}
