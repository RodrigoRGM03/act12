// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:actividad12_equipo6/calendar/calendar_page.dart';
import 'package:actividad12_equipo6/calendar/calendar_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('es_MX');
  });

  testWidgets('requests calendar access and displays device events', (
    tester,
  ) async {
    final repository = CalendarRepository(backend: _FakeCalendarRepository());

    await tester.pumpWidget(
      MaterialApp(home: CalendarPage(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Conecta tu calendario'), findsOneWidget);
    expect(find.text('Permitir acceso'), findsOneWidget);

    await tester.ensureVisible(find.text('Permitir acceso'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Permitir acceso'));
    await tester.pumpAndSettle();

    expect(find.text('Reunión de equipo'), findsOneWidget);
    expect(find.text('Conecta tu calendario'), findsNothing);
  });
}

class _FakeCalendarRepository implements CalendarRepositoryBackend {
  bool _granted = false;

  final _calendar = const DeviceCalendarInfo(
    id: 'team-calendar',
    name: 'Equipo 6',
    isReadOnly: false,
  );

  @override
  Future<CalendarAccessStatus> checkPermission() async =>
      _granted ? CalendarAccessStatus.granted : CalendarAccessStatus.denied;

  @override
  Future<CalendarAccessStatus> requestPermission() async {
    _granted = true;
    return CalendarAccessStatus.granted;
  }

  @override
  Future<List<DeviceCalendarInfo>> retrieveCalendars() async => [_calendar];

  @override
  Future<List<DeviceCalendarEvent>> retrieveEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async => [
    DeviceCalendarEvent(
      id: 'team-meeting',
      calendarId: calendarId,
      title: 'Reunión de equipo',
      start: DateTime(start.year, start.month, DateTime.now().day, 10),
      end: DateTime(start.year, start.month, DateTime.now().day, 11),
    ),
  ];

  @override
  Future<void> createCalendar(String name) async {}

  @override
  Future<void> createEvent({
    required String calendarId,
    required String title,
    required DateTime start,
    required DateTime end,
  }) async {}

  @override
  Future<void> deleteEvent(String calendarId, String eventId) async {}
}
