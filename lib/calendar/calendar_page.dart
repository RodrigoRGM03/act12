import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import 'calendar_repository.dart';

class CalendarPage extends StatefulWidget {
  CalendarPage({super.key, CalendarRepository? repository})
    : repository = repository ?? CalendarRepository();

  final CalendarRepository repository;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage>
    with WidgetsBindingObserver {
  static const _brandColor = Color(0xFF315EDC);
  static const _weekdays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  late DateTime _visibleMonth;
  late DateTime _selectedDate;
  CalendarAccessStatus _accessStatus = CalendarAccessStatus.denied;
  List<DeviceCalendarInfo> _calendars = const [];
  List<DeviceCalendarEvent> _events = const [];
  String? _selectedCalendarId;
  String? _errorMessage;
  bool _isBusy = false;

  bool get _hasCalendarAccess => _accessStatus == CalendarAccessStatus.granted;

  DeviceCalendarInfo? get _selectedCalendar {
    for (final calendar in _calendars) {
      if (calendar.id == _selectedCalendarId) {
        return calendar;
      }
    }
    return null;
  }

  bool get _canWrite =>
      !kIsWeb &&
      _hasCalendarAccess &&
      _selectedCalendar != null &&
      !_selectedCalendar!.isReadOnly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final today = DateTime.now();
    _visibleMonth = DateTime(today.year, today.month);
    _selectedDate = DateTime(today.year, today.month, today.day);
    if (kIsWeb) {
      _accessStatus = CalendarAccessStatus.unavailable;
    } else {
      _checkPermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    await _runOperation(() async {
      final status = await widget.repository.checkPermission();
      if (!mounted) return;
      setState(() => _accessStatus = status);
      if (status == CalendarAccessStatus.granted) {
        await _loadCalendarData();
      }
    });
  }

  Future<void> _requestPermission() async {
    await _runOperation(() async {
      final status = await widget.repository.requestPermission();
      if (!mounted) return;
      setState(() => _accessStatus = status);
      if (status == CalendarAccessStatus.granted) {
        await _loadCalendarData();
      }
    });
  }

  Future<void> _runOperation(Future<void> Function() operation) async {
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });
    try {
      await operation();
    } on CalendarOperationException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage =
              error.message ?? 'Android no pudo completar la operación.',
        );
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _loadCalendarData() async {
    final calendars = await widget.repository.retrieveCalendars();
    final previous = _selectedCalendarId;
    final selected =
        calendars.where((calendar) => calendar.id == previous).firstOrNull ??
        calendars.where((calendar) => !calendar.isReadOnly).firstOrNull ??
        calendars.firstOrNull;
    final events = selected == null
        ? <DeviceCalendarEvent>[]
        : await _retrieveVisibleMonthEvents(selected.id);

    if (!mounted) return;
    setState(() {
      _calendars = calendars;
      _selectedCalendarId = selected?.id;
      _events = events;
    });
  }

  Future<List<DeviceCalendarEvent>> _retrieveVisibleMonthEvents(
    String calendarId,
  ) {
    final start = DateTime(_visibleMonth.year, _visibleMonth.month);
    final end = DateTime(_visibleMonth.year, _visibleMonth.month + 1);
    return widget.repository.retrieveEvents(calendarId, start, end);
  }

  Future<void> _selectCalendar(String? calendarId) async {
    if (calendarId == null) return;
    setState(() {
      _selectedCalendarId = calendarId;
      _events = const [];
    });
    if (_hasCalendarAccess) {
      await _runOperation(() async {
        final events = await _retrieveVisibleMonthEvents(calendarId);
        if (mounted) setState(() => _events = events);
      });
    }
  }

  Future<void> _changeMonth(int offset) async {
    final nextMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + offset,
    );
    setState(() {
      _visibleMonth = nextMonth;
      _selectedDate = DateTime(nextMonth.year, nextMonth.month, 1);
      _events = const [];
    });
    final calendar = _selectedCalendar;
    if (_hasCalendarAccess && calendar != null) {
      await _runOperation(() async {
        final events = await _retrieveVisibleMonthEvents(calendar.id);
        if (mounted) setState(() => _events = events);
      });
    }
  }

  Future<void> _createLocalCalendar() async {
    await _runOperation(() async {
      await widget.repository.createCalendar('Actividad 12 - Equipo 6');
      await _loadCalendarData();
    });
  }

  Future<void> _createEvent() async {
    final calendar = _selectedCalendar;
    if (!_canWrite || calendar == null) return;

    final controller = TextEditingController();
    var startTime = const TimeOfDay(hour: 9, minute: 0);
    var endTime = const TimeOfDay(hour: 10, minute: 0);
    String? formError;
    try {
      final event = await showDialog<_NewCalendarEvent>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Nuevo evento'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del evento',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Inicio'),
                  trailing: Text(startTime.format(context)),
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (selected != null) {
                      setDialogState(() => startTime = selected);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.timelapse_outlined),
                  title: const Text('Fin'),
                  trailing: Text(endTime.format(context)),
                  onTap: () async {
                    final selected = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                    );
                    if (selected != null) {
                      setDialogState(() => endTime = selected);
                    }
                  },
                ),
                if (formError != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      formError!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final title = controller.text.trim();
                  final start = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    startTime.hour,
                    startTime.minute,
                  );
                  var end = DateTime(
                    _selectedDate.year,
                    _selectedDate.month,
                    _selectedDate.day,
                    endTime.hour,
                    endTime.minute,
                  );
                  if (end.isBefore(start)) {
                    end = end.add(const Duration(days: 1));
                  }
                  if (title.isEmpty) {
                    setDialogState(
                      () => formError = 'Escribe un nombre para el evento.',
                    );
                  } else {
                    Navigator.pop(
                      context,
                      _NewCalendarEvent(title: title, start: start, end: end),
                    );
                  }
                },
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      );

      if (event == null) return;
      await _runOperation(() async {
        await widget.repository.createEvent(
          calendarId: calendar.id,
          title: event.title,
          start: event.start,
          end: event.end,
        );
        await _loadCalendarData();
      });
    } finally {
      controller.dispose();
    }
  }

  Future<void> _deleteEvent(DeviceCalendarEvent event) async {
    final eventId = event.id;
    if (eventId == null) return;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: Text('¿Quieres eliminar “${event.title}” del calendario?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Conservar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (shouldDelete != true) return;
    await _runOperation(() async {
      await widget.repository.deleteEvent(event.calendarId, eventId);
      await _loadCalendarData();
    });
  }

  List<DateTime?> _monthDays() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final offset = (firstOfMonth.weekday + 6) % 7;
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final cellCount = ((offset + daysInMonth + 6) ~/ 7) * 7;
    return List<DateTime?>.generate(cellCount, (index) {
      final day = index - offset + 1;
      if (day < 1 || day > daysInMonth) return null;
      return DateTime(_visibleMonth.year, _visibleMonth.month, day);
    });
  }

  List<DeviceCalendarEvent> get _selectedDayEvents {
    final dayEvents = _events.where((event) {
      final start = event.start;
      return start != null &&
          start.year == _selectedDate.year &&
          start.month == _selectedDate.month &&
          start.day == _selectedDate.day;
    }).toList();
    dayEvents.sort((a, b) {
      if (a.start == null) return 1;
      if (b.start == null) return -1;
      return a.start!.compareTo(b.start!);
    });
    return dayEvents;
  }

  bool _hasEventOn(DateTime date) => _events.any((event) {
    final start = event.start;
    return start != null &&
        start.year == date.year &&
        start.month == date.month &&
        start.day == date.day;
  });

  bool _isSameDay(DateTime first, DateTime second) =>
      first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;

  @override
  Widget build(BuildContext context) {
    final canCreateCalendar =
        _hasCalendarAccess &&
        !_calendars.any((calendar) => !calendar.isReadOnly);

    return Scaffold(
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              onPressed: _isBusy ? null : _createEvent,
              icon: const Icon(Icons.add),
              label: const Text('Evento'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 840),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                if (kIsWeb) ...[
                  _buildWebPreviewBanner(),
                  const SizedBox(height: 16),
                ],
                if (_errorMessage != null) ...[
                  _buildErrorBanner(_errorMessage!),
                  const SizedBox(height: 16),
                ],
                _buildMonthCard(),
                if (_isBusy) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(),
                ],
                const SizedBox(height: 16),
                if (!kIsWeb && !_hasCalendarAccess) ...[
                  _buildPermissionCard(),
                  const SizedBox(height: 16),
                ],
                if (_hasCalendarAccess && _calendars.isEmpty) ...[
                  _buildNoCalendarCard(canCreateCalendar),
                  const SizedBox(height: 16),
                ],
                if (_hasCalendarAccess && _calendars.isNotEmpty) ...[
                  if (_calendars.length > 1) ...[
                    _buildCalendarSelector(),
                    const SizedBox(height: 16),
                  ],
                  _buildEventsCard(),
                ] else if (kIsWeb) ...[
                  _buildPreviewEventsCard(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ACTIVIDAD 12 · EQUIPO 6',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: _brandColor,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mi calendario',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            Text(
              'Organiza tus días y eventos',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFF68738A)),
            ),
          ],
        ),
      ),
      Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFFE7EDFF),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.calendar_month_rounded, color: _brandColor),
      ),
    ],
  );

  Widget _buildWebPreviewBanner() => _InfoBanner(
    icon: Icons.desktop_windows_outlined,
    title: 'Vista previa en Chrome',
    message:
        'Aquí puedes revisar la interfaz. Para leer o guardar eventos y '
        'solicitar permisos, ejecuta la app en Android.',
  );

  Widget _buildErrorBanner(String message) => _InfoBanner(
    icon: Icons.error_outline,
    title: 'No se pudo completar la operación',
    message: message,
    isError: true,
  );

  Widget _buildMonthCard() {
    final monthLabel = DateFormat.yMMMM('es_MX').format(_visibleMonth);
    final today = DateTime.now();

    return _CardSurface(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthLabel,
                  style: Theme.of(context).textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: _isBusy ? null : () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: _isBusy ? null : () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: _weekdays
                .map(
                  (day) => Expanded(
                    child: Center(
                      child: Text(
                        day,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: const Color(0xFF7C879C),
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _monthDays().length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 46,
            ),
            itemBuilder: (context, index) {
              final date = _monthDays()[index];
              if (date == null) return const SizedBox.shrink();
              final selected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, today);
              final hasEvent = _hasEventOn(date);

              return Semantics(
                button: true,
                selected: selected,
                label: DateFormat.yMMMMd('es_MX').format(date),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => setState(() => _selectedDate = date),
                  child: Center(
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: selected ? _brandColor : Colors.transparent,
                        shape: BoxShape.circle,
                        border: !selected && isToday
                            ? Border.all(color: _brandColor)
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '${date.day}',
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF253047),
                                fontWeight: selected || isToday
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (hasEvent)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: selected ? Colors.white : _brandColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionCard() {
    final status = _accessStatus;
    final title = switch (status) {
      CalendarAccessStatus.permanentlyDenied => 'Permiso bloqueado',
      CalendarAccessStatus.restricted => 'Acceso restringido',
      CalendarAccessStatus.unavailable => 'Calendario no disponible',
      _ => 'Conecta tu calendario',
    };
    final message = switch (status) {
      CalendarAccessStatus.permanentlyDenied =>
        'El permiso fue denegado de forma permanente. Actívalo desde los '
            'ajustes de la aplicación para continuar.',
      CalendarAccessStatus.restricted =>
        'El sistema restringe este permiso y no puede modificarse desde la '
            'aplicación.',
      CalendarAccessStatus.unavailable =>
        'El calendario del dispositivo solo está disponible en Android.',
      _ =>
        'Necesitamos permiso para mostrar, crear y eliminar eventos en tus '
            'calendarios.',
    };
    final canRequest = status == CalendarAccessStatus.denied;
    final canOpenSettings = status == CalendarAccessStatus.permanentlyDenied;

    return _CardSurface(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _LeadingIcon(icon: Icons.lock_outline_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: const Color(0xFF68738A)),
                ),
                if (canRequest || canOpenSettings) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _isBusy
                        ? null
                        : canRequest
                        ? _requestPermission
                        : _openSettings,
                    icon: Icon(
                      canRequest ? Icons.lock_open_rounded : Icons.settings,
                    ),
                    label: Text(
                      canRequest ? 'Permitir acceso' : 'Abrir ajustes',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSettings() async {
    final opened = await permissions.openAppSettings();
    if (!opened && mounted) {
      setState(
        () => _errorMessage =
            'No fue posible abrir los ajustes de permisos de la aplicación.',
      );
    }
  }

  Widget _buildNoCalendarCard(bool canCreateCalendar) => _CardSurface(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _LeadingIcon(icon: Icons.event_busy_outlined),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No hay calendarios disponibles',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                canCreateCalendar
                    ? 'Crea un calendario local para guardar tus eventos.'
                    : 'No hay calendarios editables en este dispositivo.',
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF68738A)),
              ),
              if (canCreateCalendar) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _isBusy ? null : _createLocalCalendar,
                  icon: const Icon(Icons.add),
                  label: const Text('Crear calendario local'),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildCalendarSelector() => _CardSurface(
    child: Row(
      children: [
        const _LeadingIcon(icon: Icons.calendar_today_outlined),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButton<String>(
            value: _selectedCalendarId,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            hint: const Text('Selecciona un calendario'),
            items: _calendars
                .map(
                  (calendar) => DropdownMenuItem(
                    value: calendar.id,
                    child: Text(
                      calendar.isReadOnly
                          ? '${calendar.name} · solo lectura'
                          : calendar.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _isBusy ? null : _selectCalendar,
          ),
        ),
      ],
    ),
  );

  Widget _buildEventsCard() {
    final dateLabel = DateFormat('EEEE d MMMM', 'es_MX').format(_selectedDate);
    final events = _selectedDayEvents;

    return _CardSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _LeadingIcon(icon: Icons.event_note_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Agenda del día',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      dateLabel,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: const Color(0xFF68738A)),
                    ),
                  ],
                ),
              ),
              if (_canWrite)
                IconButton(
                  tooltip: 'Crear evento',
                  onPressed: _isBusy ? null : _createEvent,
                  icon: const Icon(Icons.add_circle_outline),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (events.isEmpty)
            const _EmptyAgenda()
          else
            ...events.map(_buildEventTile),
        ],
      ),
    );
  }

  Widget _buildEventTile(DeviceCalendarEvent event) {
    final start = event.start;
    final end = event.end;
    final timeLabel = start == null
        ? 'Hora no disponible'
        : end == null
        ? DateFormat.Hm('es_MX').format(start)
        : '${DateFormat.Hm('es_MX').format(start)} – '
              '${DateFormat.Hm('es_MX').format(end)}';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 4,
        height: 42,
        decoration: BoxDecoration(
          color: _brandColor,
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      title: Text(
        event.title,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(timeLabel),
      trailing: event.id == null
          ? null
          : IconButton(
              tooltip: 'Eliminar ${event.title}',
              onPressed: _isBusy ? null : () => _deleteEvent(event),
              icon: const Icon(Icons.delete_outline),
            ),
    );
  }

  Widget _buildPreviewEventsCard() => _CardSurface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const _LeadingIcon(icon: Icons.event_note_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Agenda del día',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const _EmptyAgenda(),
      ],
    ),
  );
}

class _NewCalendarEvent {
  const _NewCalendarEvent({
    required this.title,
    required this.start,
    required this.end,
  });

  final String title;
  final DateTime start;
  final DateTime end;
}

class _CardSurface extends StatelessWidget {
  const _CardSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE8ECF4)),
      boxShadow: const [
        BoxShadow(
          color: Color(0x080D1B3E),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _LeadingIcon extends StatelessWidget {
  const _LeadingIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0FF),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: const Color(0xFF315EDC)),
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF315EDC);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFF0EF) : const Color(0xFFEAF0FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(color: Color(0xFF4F5B72))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAgenda extends StatelessWidget {
  const _EmptyAgenda();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Row(
      children: [
        const Icon(Icons.event_available_outlined, color: Color(0xFF8994A8)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'No hay eventos para este día.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: const Color(0xFF68738A)),
          ),
        ),
      ],
    ),
  );
}
