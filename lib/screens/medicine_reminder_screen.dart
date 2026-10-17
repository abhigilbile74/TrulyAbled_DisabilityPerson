import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/medicine_notification_service.dart';

class MedicineReminder {
  MedicineReminder({
    required this.id,
    required this.name,
    required this.dose,
    required this.instructions,
    required this.hour,
    required this.minute,
    this.enabled = true,
  });

  final int id;
  final String name;
  final String dose;
  final String instructions;
  final int hour;
  final int minute;
  final bool enabled;

  String get timeLabel {
    final time = TimeOfDay(hour: hour, minute: minute);
    return time.formatFromTimeOfDay();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'instructions': instructions,
        'hour': hour,
        'minute': minute,
        'enabled': enabled,
      };

  factory MedicineReminder.fromJson(Map<String, dynamic> json) =>
      MedicineReminder(
        id: json['id'] as int,
        name: json['name'] as String,
        dose: (json['dose'] ?? '') as String,
        instructions: (json['instructions'] ?? '') as String,
        hour: json['hour'] as int,
        minute: json['minute'] as int,
        enabled: (json['enabled'] ?? true) as bool,
      );

  MedicineReminder copyWith({bool? enabled}) => MedicineReminder(
        id: id,
        name: name,
        dose: dose,
        instructions: instructions,
        hour: hour,
        minute: minute,
        enabled: enabled ?? this.enabled,
      );
}

extension on TimeOfDay {
  String formatFromTimeOfDay() {
    final h = hourOfPeriod == 0 ? 12 : hourOfPeriod;
    final m = minute.toString().padLeft(2, '0');
    final period = this.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }
}

class MedicineReminderScreen extends StatefulWidget {
  const MedicineReminderScreen({super.key});

  @override
  State<MedicineReminderScreen> createState() =>
      _MedicineReminderScreenState();
}

class _MedicineReminderScreenState extends State<MedicineReminderScreen> {
  static const _storageKey = 'trulyabled_medicine_reminders_v1';

  final _notifications = MedicineNotificationService();
  final List<MedicineReminder> _reminders = [];
  final Set<String> _alreadyAlertedThisMinute = {};
  Timer? _webCheckTimer;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    await _notifications.initialize();
    await _loadReminders();
    // This timer supports reminders in Chrome while the app tab is open.
    _webCheckTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkWebReminders(),
    );
  }

  Future<void> _loadReminders() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        _reminders
          ..clear()
          ..addAll(decoded.map(
            (e) => MedicineReminder.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          ));
      } catch (_) {
        // If an old/corrupt value exists, keep the screen usable.
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_reminders.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _checkWebReminders() async {
    if (!mounted) return;
    final now = TimeOfDay.now();
    final date = DateTime.now();
    final minuteKey =
        '${date.year}-${date.month}-${date.day}-${now.hour}-${now.minute}';

    for (final reminder in _reminders) {
      if (!reminder.enabled ||
          reminder.hour != now.hour ||
          reminder.minute != now.minute) {
        continue;
      }
      final key = '${reminder.id}-$minuteKey';
      if (_alreadyAlertedThisMinute.contains(key)) continue;
      _alreadyAlertedThisMinute.add(key);

      final message =
          '${reminder.name} ${reminder.dose.isEmpty ? '' : '• ${reminder.dose}'}'
              .trim();
      await _notifications.showNow(
        title: 'Medicine reminder',
        body: 'It is time to take $message.',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Medicine reminder: ${reminder.name}'),
            duration: const Duration(seconds: 8),
            action: SnackBarAction(
              label: 'OK',
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  Future<void> _addReminder() async {
    final result = await showDialog<MedicineReminder>(
      context: context,
      builder: (_) => const _AddMedicineDialog(),
    );
    if (result == null) return;

    setState(() {
      _reminders.add(result);
      _reminders.sort((a, b) {
        final aMins = a.hour * 60 + a.minute;
        final bMins = b.hour * 60 + b.minute;
        return aMins.compareTo(bMins);
      });
    });
    await _save();
    if (result.enabled) await _schedule(result);
  }

  Future<void> _schedule(MedicineReminder reminder) async {
    await _notifications.scheduleDaily(
      id: reminder.id,
      title: 'Time to take your medicine',
      body: '${reminder.name}${reminder.dose.isEmpty ? '' : ' • ${reminder.dose}'}'
          '${reminder.instructions.isEmpty ? '' : ' — ${reminder.instructions}'}',
      hour: reminder.hour,
      minute: reminder.minute,
    );
  }

  Future<void> _toggle(MedicineReminder reminder, bool enabled) async {
    final index = _reminders.indexWhere((e) => e.id == reminder.id);
    if (index < 0) return;
    final updated = reminder.copyWith(enabled: enabled);
    setState(() => _reminders[index] = updated);
    await _save();
    if (enabled) {
      await _schedule(updated);
    } else {
      await _notifications.cancel(updated.id);
    }
  }

  Future<void> _delete(MedicineReminder reminder) async {
    await _notifications.cancel(reminder.id);
    setState(() => _reminders.removeWhere((e) => e.id == reminder.id));
    await _save();
  }

  @override
  void dispose() {
    _webCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicine Reminder'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Add medicine',
            onPressed: _addReminder,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        icon: const Icon(Icons.add_alarm),
        label: const Text('Add medicine'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reminders.isEmpty
              ? _emptyState(theme)
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              radius: 25,
                              child: Icon(Icons.medication_outlined, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your medicine schedule',
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_reminders.where((e) => e.enabled).length} active reminder(s)',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final reminder in _reminders)
                      Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.12),
                                    child: Icon(
                                      Icons.medication,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          reminder.name,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (reminder.dose.isNotEmpty)
                                          Text('Dose: ${reminder.dose}'),
                                        if (reminder.instructions.isNotEmpty)
                                          Text(reminder.instructions),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: reminder.enabled,
                                    onChanged: (value) =>
                                        _toggle(reminder, value),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Row(
                                children: [
                                  const Icon(Icons.access_time),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      reminder.timeLabel,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete reminder',
                                    onPressed: () => _delete(reminder),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              Text(
                                reminder.enabled
                                    ? 'Repeats every day'
                                    : 'Reminder paused',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _emptyState(ThemeData theme) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.notifications_active_outlined,
                size: 72,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'No medicine reminders yet',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Add a medicine, dose, and time. TrulyAbled will save the schedule and remind you.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _addReminder,
                icon: const Icon(Icons.add_alarm),
                label: const Text('Add your first medicine'),
              ),
            ],
          ),
        ),
      );
}

class _AddMedicineDialog extends StatefulWidget {
  const _AddMedicineDialog();

  @override
  State<_AddMedicineDialog> createState() => _AddMedicineDialogState();
}

class _AddMedicineDialogState extends State<_AddMedicineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _doseController = TextEditingController();
  final _instructionsController = TextEditingController();
  TimeOfDay _time = TimeOfDay.now();

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add medicine reminder'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Medicine name *',
                  hintText: 'e.g. Vitamin tablet',
                  prefixIcon: Icon(Icons.medication),
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the medicine name'
                    : null,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _doseController,
                decoration: const InputDecoration(
                  labelText: 'Dose (optional)',
                  hintText: 'e.g. 1 tablet',
                  prefixIcon: Icon(Icons.scale_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _instructionsController,
                decoration: const InputDecoration(
                  labelText: 'Instructions (optional)',
                  hintText: 'e.g. After food',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.alarm),
                title: const Text('Reminder time'),
                subtitle: Text(_time.format(context)),
                trailing: const Icon(Icons.edit),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _time,
                  );
                  if (picked != null) setState(() => _time = picked);
                },
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'This reminder repeats daily. Add the same medicine again for another dose time.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            final id = DateTime.now().microsecondsSinceEpoch
                .remainder(2147483647);
            Navigator.pop(
              context,
              MedicineReminder(
                id: id,
                name: _nameController.text.trim(),
                dose: _doseController.text.trim(),
                instructions: _instructionsController.text.trim(),
                hour: _time.hour,
                minute: _time.minute,
              ),
            );
          },
          child: const Text('Save reminder'),
        ),
      ],
    );
  }
}
