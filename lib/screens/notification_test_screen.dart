import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../models/note.dart';
import '../models/reminder.dart' as reminder_model;
import 'package:provider/provider.dart';
import '../providers/notes_provider.dart';

class NotificationTestScreen extends StatefulWidget {
  const NotificationTestScreen({Key? key}) : super(key: key);

  @override
  State<NotificationTestScreen> createState() => _NotificationTestScreenState();
}

class _NotificationTestScreenState extends State<NotificationTestScreen> {
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _titleController =
      TextEditingController(text: 'Тестовое уведомление');
  final TextEditingController _bodyController = TextEditingController(
      text: 'Это тестовое уведомление для проверки работы');

  // Время для отложенного уведомления
  DateTime _scheduledDate = DateTime.now().add(const Duration(seconds: 10));

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест уведомлений'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Поле для заголовка
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Заголовок уведомления',
              ),
            ),
            const SizedBox(height: 16),

            // Поле для текста
            TextField(
              controller: _bodyController,
              decoration: const InputDecoration(
                labelText: 'Текст уведомления',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Выбор времени
            ListTile(
              title: const Text('Время уведомления'),
              subtitle: Text(
                '${_scheduledDate.day}.${_scheduledDate.month}.${_scheduledDate.year} ${_scheduledDate.hour}:${_scheduledDate.minute.toString().padLeft(2, '0')}',
              ),
              trailing: const Icon(Icons.access_time),
              onTap: _selectDateTime,
            ),
            const SizedBox(height: 24),

            // Кнопка для мгновенного уведомления
            ElevatedButton(
              onPressed: _showInstantNotification,
              child: const Text('Показать уведомление сейчас'),
            ),
            const SizedBox(height: 16),

            // Кнопка для отложенного уведомления
            ElevatedButton(
              onPressed: _scheduleNotification,
              child: const Text('Запланировать уведомление'),
            ),
            const SizedBox(height: 16),

            // Кнопка для создания тестовой заметки с уведомлением
            ElevatedButton(
              onPressed: _createTestNoteWithReminder,
              child: const Text('Создать тестовую заметку с уведомлением'),
            ),
          ],
        ),
      ),
    );
  }

  // Выбор времени и даты
  Future<void> _selectDateTime() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledDate),
      );

      if (pickedTime != null) {
        setState(() {
          _scheduledDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  // Показать мгновенное уведомление
  Future<void> _showInstantNotification() async {
    await _notificationService.showTestNotification(
      _titleController.text,
      _bodyController.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Уведомление отправлено!')),
    );
  }

  // Запланировать уведомление
  Future<void> _scheduleNotification() async {
    // Создаем временную заметку для тестирования
    final testNote = Note(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      content: _bodyController.text,
      themeIds: [],
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      hasDeadline: true,
      deadlineDate: _scheduledDate.add(const Duration(hours: 1)),
      hasDateLink: false,
      linkedDate: null,
      isCompleted: false,
      mediaUrls: [],
      reminderDates: [_scheduledDate],
      reminderType: ReminderType.exactTime,
    );

    await _notificationService.scheduleNotificationsForNote(testNote);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Уведомление запланировано на ${_scheduledDate.hour}:${_scheduledDate.minute.toString().padLeft(2, '0')}',
        ),
      ),
    );
  }

  // Создать тестовую заметку с напоминанием
  Future<void> _createTestNoteWithReminder() async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Используем правильный метод createNote
    final note = await notesProvider.createNote(
      content: 'Тестовая заметка с напоминанием',
      hasDeadline: true,
      deadlineDate: _scheduledDate.add(const Duration(hours: 1)),
      reminderDates: [_scheduledDate],
      reminderType: ReminderType.exactTime,
      reminderSound: 'default',
    );

    if (note != null) {
      // Уведомления планируются автоматически в createNote
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Создана тестовая заметка с напоминанием на ${_scheduledDate.hour}:${_scheduledDate.minute.toString().padLeft(2, '0')}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка при создании тестовой заметки'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
