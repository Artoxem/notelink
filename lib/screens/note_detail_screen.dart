import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/note.dart';
import '../providers/app_provider.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../services/media_service.dart';
import '../utils/constants.dart';
import '../utils/delta_utils.dart';
import '../widgets/custom_date_picker.dart';
import '../widgets/custom_time_picker.dart';
import '../widgets/quill_editor_wrapper.dart';
import '../widgets/theme_chip.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note? note; // Null если создаем новую заметку
  final DateTime? initialDate; // Начальная дата, если пришли из календаря
  final bool isEditMode; // Параметр для начального режима редактирования
  final List<String>?
  initialThemeIds; // Добавлен новый параметр для автоматической привязки к теме

  const NoteDetailScreen({
    Key? key,
    this.note,
    this.initialDate,
    this.isEditMode = false, // По умолчанию режим просмотра
    this.initialThemeIds, // Новый параметр
  }) : super(key: key);

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen>
    with TickerProviderStateMixin {
  // Контроллеры
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();
  final _quillEditorKey = GlobalKey<QuillEditorWrapperState>();

  // Состояние заметки
  bool _hasDeadline = false;
  bool _isTaskCompleted = false;
  DateTime? _deadlineDate;
  TimeOfDay? _deadlineTime;
  bool _hasDateLink = false;
  DateTime? _linkedDate;
  String? _emoji;
  List<String> _themeIds = [];
  bool _isContentChanged = false;
  bool _isDirty = false;
  bool _isLoading = false;
  bool _isFocusMode = false;
  List<String> _mediaFiles = []; // Поле для медиафайлов

  // Напоминания
  bool _hasReminders = false;
  List<DateTime> _reminderDates = [];
  String _reminderSound = 'default';
  ReminderType _reminderType = ReminderType.exactTime;
  RelativeReminder? _relativeReminder;

  // Контроллеры анимации
  late AnimationController _modeTransitionController;
  late Animation<double> _modeTransitionAnimation;
  late AnimationController _focusModeController;
  late Animation<double> _focusModeAnimation;

  // Режим просмотра/редактирования
  bool _isEditing = false;

  // Автосохранение
  Timer? _autoSaveTimer;

  @override
  void initState() {
    super.initState();
    _initializeFromNote();
    _setupAutoSave();

    // Устанавливаем начальный режим
    _isEditing = widget.note == null || widget.isEditMode;

    // Инициализация анимаций
    _modeTransitionController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _modeTransitionAnimation = CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeInOut,
    );

    _focusModeController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _focusModeAnimation = CurvedAnimation(
      parent: _focusModeController,
      curve: Curves.easeInOut,
    );

    // Начальные обработчики фокуса
    _contentFocusNode.addListener(_handleFocusChange);

    // Если есть начальные темы, добавляем их
    if (widget.initialThemeIds != null && widget.initialThemeIds!.isNotEmpty) {
      _themeIds = List.from(widget.initialThemeIds!);
      _isDirty = true;
    }
  }

  void _initializeFromNote() {
    if (widget.note != null) {
      // Инициализация контента
      _contentController.text = widget.note!.content;

      // Инициализация дедлайна
      if (widget.note!.hasDeadline && widget.note!.deadlineDate != null) {
        _hasDeadline = true;
        _deadlineDate = widget.note!.deadlineDate;
        _isTaskCompleted = widget.note!.isCompleted;

        // Инициализация времени
        if (widget.note!.deadlineDate != null) {
          _deadlineTime = TimeOfDay(
            hour: widget.note!.deadlineDate!.hour,
            minute: widget.note!.deadlineDate!.minute,
          );
        }
      }

      // Инициализация привязки к дате
      if (widget.note!.hasDateLink && widget.note!.linkedDate != null) {
        _hasDateLink = true;
        _linkedDate = widget.note!.linkedDate;
      }

      // Инициализация тем
      if (widget.note!.themeIds.isNotEmpty) {
        _themeIds = List.from(widget.note!.themeIds);
      }

      // Инициализация эмодзи
      _emoji = widget.note!.emoji;

      // Инициализация медиа-файлов
      if (widget.note!.mediaUrls.isNotEmpty) {
        _mediaFiles = List.from(widget.note!.mediaUrls);
      }

      // Инициализация напоминаний
      if (widget.note!.reminderDates != null &&
          widget.note!.reminderDates!.isNotEmpty) {
        _hasReminders = true;
        _reminderDates = List.from(widget.note!.reminderDates!);
        _reminderSound = widget.note!.reminderSound ?? 'default';
        _reminderType = widget.note!.reminderType;
        _relativeReminder = widget.note!.relativeReminder;
      }
    } else if (widget.initialDate != null) {
      // Если есть начальная дата (из календаря)
      _hasDateLink = true;
      _linkedDate = widget.initialDate;
      _isDirty = true;
    }
  }

  void _setupAutoSave() {
    // Отменяем предыдущий таймер, если он есть
    _autoSaveTimer?.cancel();

    // Настраиваем слушатель изменений контента
    _contentController.addListener(() {
      if (!_isContentChanged) {
        setState(() {
          _isContentChanged = true;
          _isDirty = true;
        });
      }

      // Сбрасываем таймер автосохранения
      _autoSaveTimer?.cancel();
      _autoSaveTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _isDirty) {
          _saveNote();
        }
      });
    });

    // Настраиваем периодическое сохранение
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_isDirty) {
        _saveNote();
      }
    });
  }

  void _handleFocusChange() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (_contentFocusNode.hasFocus && appProvider.enableFocusMode) {
      setState(() {
        _isFocusMode = true;
        _focusModeController.forward();
      });
    } else {
      setState(() {
        _isFocusMode = false;
        _focusModeController.reverse();
      });
    }
  }

  @override
  void dispose() {
    // Очищаем ресурсы
    _autoSaveTimer?.cancel();
    _contentController.removeListener(() {});
    _contentController.dispose();
    _contentFocusNode.removeListener(_handleFocusChange);
    _contentFocusNode.dispose();
    _modeTransitionController.dispose();
    _focusModeController.dispose();
    super.dispose();
  }

  // Сохранение заметки
  Future<bool> _saveNote() async {
    if (_isLoading) return false;

    setState(() {
      _isLoading = true;
    });

    try {
      // Получаем QuillController из wrapper
      final quillController =
          _quillEditorKey.currentState?.getQuillController();

      String deltaJson;
      if (quillController != null) {
        // Получаем Delta JSON в стандартном формате
        deltaJson = jsonEncode({
          'ops': quillController.document.toDelta().toJson(),
        });
      } else {
        // Используем существующий текст, но стандартизируем его
        deltaJson =
            _contentController.text.isNotEmpty
                ? _contentController.text
                : '{"ops":[{"insert":"\\n"}]}';
      }

      // Проверяем наличие текста
      final plainText = quillController?.document.toPlainText().trim() ?? '';
      final isEmptyNote =
          plainText.isEmpty &&
          _themeIds.isEmpty &&
          !_hasDeadline &&
          !_hasDateLink &&
          _mediaFiles.isEmpty;

      if (isEmptyNote) {
        _showErrorSnackBar('Нельзя сохранить пустую заметку');
        setState(() {
          _isLoading = false;
        });
        return false;
      }

      // Получаем провайдер заметок
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      if (widget.note == null) {
        // Создаем новую заметку
        final newNote = Note(
          id: const Uuid().v4(),
          content: deltaJson,
          themeIds: _themeIds,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          hasDeadline: _hasDeadline,
          deadlineDate: _hasDeadline ? _getFullDeadlineDate() : null,
          hasDateLink: _hasDateLink,
          linkedDate: _linkedDate,
          isCompleted: _isTaskCompleted,
          mediaUrls: _mediaFiles,
          emoji: _emoji,
          reminderDates: _hasReminders ? _reminderDates : null,
          reminderSound: _hasReminders ? _reminderSound : null,
          reminderType: _reminderType,
          relativeReminder: _relativeReminder,
        );

        final success = await notesProvider.createNote(newNote);
        if (!success) {
          throw Exception('Не удалось создать заметку');
        }
      } else {
        // Обновляем существующую заметку
        final updatedNote = widget.note!.copyWith(
          content: deltaJson,
          themeIds: _themeIds,
          updatedAt: DateTime.now(),
          hasDeadline: _hasDeadline,
          deadlineDate: _hasDeadline ? _getFullDeadlineDate() : null,
          hasDateLink: _hasDateLink,
          linkedDate: _linkedDate,
          isCompleted: _isTaskCompleted,
          mediaUrls: _mediaFiles,
          emoji: _emoji,
          reminderDates: _hasReminders ? _reminderDates : null,
          reminderSound: _hasReminders ? _reminderSound : null,
          reminderType: _reminderType,
          relativeReminder: _relativeReminder,
        );

        final success = await notesProvider.updateNote(updatedNote);
        if (!success) {
          throw Exception('Не удалось обновить заметку');
        }
      }

      setState(() {
        _isLoading = false;
        _isDirty = false;
        _isContentChanged = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.note == null ? 'Заметка создана' : 'Заметка обновлена',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Ошибка при сохранении заметки: $e');

      if (context.mounted) {
        _showErrorSnackBar('Не удалось сохранить заметку: ${e.toString()}');
      }

      setState(() {
        _isLoading = false;
      });

      return false;
    }
  }

  // Комбинирует дату и время дедлайна
  DateTime _getFullDeadlineDate() {
    if (_deadlineDate == null) return DateTime.now();

    if (_deadlineTime != null) {
      return DateTime(
        _deadlineDate!.year,
        _deadlineDate!.month,
        _deadlineDate!.day,
        _deadlineTime!.hour,
        _deadlineTime!.minute,
      );
    }

    return _deadlineDate!;
  }

  void _showErrorSnackBar(String message) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Переключение режима редактирования/просмотра
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _modeTransitionController.forward();
      } else {
        _modeTransitionController.reverse();
      }
    });
  }

  // Обработка нажатия кнопки Назад
  Future<bool> _onWillPop() async {
    if (_isDirty) {
      final result = await _showUnsavedChangesDialog();

      if (result == null) {
        return false;
      } else if (result) {
        final saved = await _saveNote();
        return saved;
      }
    }
    return true;
  }

  // Диалог несохраненных изменений
  Future<bool?> _showUnsavedChangesDialog() {
    return showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Несохраненные изменения'),
            content: const Text(
              'У вас есть несохраненные изменения. Сохранить перед выходом?',
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.of(context).pop(false), // Не сохранять
                child: const Text('Не сохранять'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // Сохранить
                child: const Text('Сохранить'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(null), // Отмена
                child: const Text('Отмена'),
              ),
            ],
          ),
    );
  }

  // Показать подтверждение удаления
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Удалить заметку'),
            content: const Text(
              'Вы уверены, что хотите удалить эту заметку? Это действие нельзя будет отменить.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);

                  if (widget.note != null) {
                    setState(() {
                      _isLoading = true;
                    });

                    try {
                      final notesProvider = Provider.of<NotesProvider>(
                        context,
                        listen: false,
                      );
                      await notesProvider.deleteNote(widget.note!.id);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Заметка удалена')),
                        );

                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                        _showErrorSnackBar(
                          'Ошибка при удалении: ${e.toString()}',
                        );
                      }
                    }
                  }
                },
                child: const Text(
                  'Удалить',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  // Обработчик выбора медиафайла
  void _pickMedia() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: AppColors.accentPrimary,
                ),
                title: const Text('Сделать фото'),
                onTap: () async {
                  Navigator.pop(context);
                  final MediaService mediaService = MediaService();
                  final imagePath = await mediaService.pickImageFromCamera();
                  if (imagePath != null && mounted) {
                    setState(() {
                      _mediaFiles.add(imagePath);
                      _isDirty = true;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.accentPrimary,
                ),
                title: const Text('Выбрать из галереи'),
                onTap: () async {
                  Navigator.pop(context);
                  final MediaService mediaService = MediaService();
                  final imagePath = await mediaService.pickImageFromGallery();
                  if (imagePath != null && mounted) {
                    setState(() {
                      _mediaFiles.add(imagePath);
                      _isDirty = true;
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.attach_file,
                  color: AppColors.accentPrimary,
                ),
                title: const Text('Прикрепить файл'),
                onTap: () async {
                  Navigator.pop(context);
                  final MediaService mediaService = MediaService();
                  final filePath = await mediaService.pickFile();
                  if (filePath != null && mounted) {
                    setState(() {
                      _mediaFiles.add(filePath);
                      _isDirty = true;
                    });
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Отмена'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  // Обработчик удаления медиафайла
  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      _isDirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing
                ? (widget.note == null
                    ? 'Новая заметка'
                    : 'Редактирование заметки')
                : 'Просмотр заметки',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final canPop = await _onWillPop();
              if (canPop && mounted) {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            // Для существующих заметок показываем переключатель режима
            if (widget.note != null)
              IconButton(
                icon: Icon(_isEditing ? Icons.visibility : Icons.edit),
                tooltip:
                    _isEditing ? 'Режим просмотра' : 'Режим редактирования',
                onPressed: _toggleEditMode,
              ),

            // Кнопка сохранения (только в режиме редактирования)
            if (_isEditing)
              IconButton(icon: const Icon(Icons.check), onPressed: _saveNote),

            // Меню действий
            if (widget.note != null)
              PopupMenuButton<String>(
                itemBuilder:
                    (context) => [
                      const PopupMenuItem<String>(
                        value: 'delete',
                        child: ListTile(
                          leading: Icon(Icons.delete, color: Colors.red),
                          title: Text('Удалить'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                onSelected: (value) {
                  if (value == 'delete') {
                    _showDeleteConfirmation();
                  }
                },
              ),
          ],
        ),
        backgroundColor: AppColors.textBackground,
        body: Stack(
          children: [
            // Основное содержимое
            AnimatedSwitcher(
              duration: AppAnimations.mediumDuration,
              child:
                  _isEditMode ? _buildEditModeContent() : _buildViewContent(),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),

            // Индикатор загрузки
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }

  // Построение режима просмотра
  Widget _buildViewContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Информация о дате создания
            if (widget.note != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  'Создано: ${DateFormat('dd.MM.yyyy').format(widget.note!.createdAt)}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ),

            // Редактор Quill в режиме чтения через QuillEditorWrapper
            Container(
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.textBackground,
                borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
                boxShadow: [AppShadows.small],
              ),
              padding: const EdgeInsets.all(16),
              child: QuillEditorWrapper(
                key: _quillEditorKey,
                controller: _contentController,
                focusNode: _contentFocusNode,
                readOnly: true,
                placeholder: 'Пустая заметка',
              ),
            ),

            // Отображение медиафайлов
            if (_mediaFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _buildMediaFilesGrid(),
              ),

            // Информация о дедлайне и заметке
            if (_hasDeadline || _hasDateLink || _themeIds.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(
                    AppDimens.cardBorderRadius,
                  ),
                  boxShadow: [AppShadows.small],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Информация о дедлайне
                    if (_hasDeadline && _deadlineDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              color: _getDeadlineColor(),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Срок: ${DateFormat('dd.MM.yyyy').format(_deadlineDate!)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: _getDeadlineColor(),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (_deadlineTime != null)
                              Text(
                                ' ${_deadlineTime!.format(context)}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _getDeadlineColor(),
                                ),
                              ),
                          ],
                        ),
                      ),

                    // Информация о привязке к дате
                    if (_hasDateLink && _linkedDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Дата: ${DateFormat('dd.MM.yyyy').format(_linkedDate!)}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Отображение тем
                    if (_themeIds.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: _buildThemeTags(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Режим редактирования
  Widget _buildEditModeContent() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Используем QuillEditorWrapper для редактирования
            QuillEditorWrapper(
              key: _quillEditorKey,
              controller: _contentController,
              focusNode: _contentFocusNode,
              readOnly: false,
              placeholder: 'Начните писать заметку...',
              onChanged: (content) {
                if (!_isDirty) {
                  setState(() {
                    _isDirty = true;
                  });
                }
              },
              onMediaAdded: (mediaPath) {
                if (mediaPath.isNotEmpty) {
                  setState(() {
                    _mediaFiles.add(mediaPath);
                    _isDirty = true;
                  });
                }
              },
            ),

            // Отображение медиафайлов
            if (_mediaFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: _buildMediaFilesGrid(),
              ),

            // Кнопка добавления медиа
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: _pickMedia,
                icon: const Icon(Icons.attach_file),
                label: const Text('Добавить медиафайл'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),

            // Нижняя панель с настройками заметки
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
                boxShadow: [AppShadows.small],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок панели
                  const Text(
                    'Атрибуты:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),

                  // Настройки в две колонки
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Левая колонка - настройки дат и дедлайнов
                        Expanded(flex: 6, child: _buildDateSettings()),

                        // Разделитель
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 1,
                          color: AppColors.secondary.withOpacity(0.3),
                        ),

                        // Правая колонка - выбор тем
                        Expanded(flex: 8, child: _buildThemeSettings()),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Отображение прикрепленных медиафайлов в сетке
  Widget _buildMediaFilesGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: _mediaFiles.length,
      itemBuilder: (context, index) {
        final mediaPath = _mediaFiles[index];
        final MediaService mediaService = MediaService();
        final bool isImage = mediaService.isImage(mediaPath);

        return Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              clipBehavior: Clip.antiAlias,
              child:
                  isImage
                      ? Image.file(
                        File(mediaPath),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        errorBuilder:
                            (context, error, stack) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                      )
                      : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.insert_drive_file, size: 40),
                      ),
            ),
            if (_isEditing)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _removeMedia(index),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Настройки даты и дедлайнов
  Widget _buildDateSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Настройка дедлайна
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Срок выполнения', style: TextStyle(fontSize: 13)),
          dense: true,
          value: _hasDeadline,
          onChanged: (value) {
            setState(() {
              _hasDeadline = value;
              _isDirty = true;
              if (_hasDeadline && _deadlineDate == null) {
                _deadlineDate = DateTime.now().add(const Duration(days: 1));
              }
            });
          },
        ),

        // Выбор даты для дедлайна
        if (_hasDeadline)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Выбрать дату', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              _deadlineDate != null
                  ? DateFormat('dd.MM.yyyy').format(_deadlineDate!)
                  : 'Выберите дату',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
            leading: const Icon(
              Icons.calendar_today,
              size: 20,
              color: Colors.orange,
            ),
            onTap: () async {
              final selectedDate = await DatePickerDialog.show(
                context: context,
                initialDate:
                    _deadlineDate ??
                    DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selectedDate != null) {
                setState(() {
                  _deadlineDate = selectedDate;
                  _isDirty = true;
                });
              }
            },
          ),

        // Выбор времени для дедлайна
        if (_hasDeadline && _deadlineDate != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Выбрать время', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              _deadlineTime != null
                  ? _deadlineTime!.format(context)
                  : 'Выберите время',
              style: const TextStyle(fontSize: 12),
            ),
            leading: const Icon(Icons.access_time, size: 20),
            onTap: () async {
              final selectedTime = await TimePickerDialog.show(
                context: context,
                initialTime:
                    _deadlineTime ?? const TimeOfDay(hour: 12, minute: 0),
              );
              if (selectedTime != null) {
                setState(() {
                  _deadlineTime = selectedTime;
                  _isDirty = true;
                });
              }
            },
          ),

        // Настройка привязки к дате
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Привязка к дате', style: TextStyle(fontSize: 13)),
          dense: true,
          value: _hasDateLink,
          onChanged: (value) {
            setState(() {
              _hasDateLink = value;
              _isDirty = true;
              if (_hasDateLink && _linkedDate == null) {
                _linkedDate = DateTime.now();
              }
            });
          },
        ),

        // Выбор связанной даты
        if (_hasDateLink)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Выбрать дату', style: TextStyle(fontSize: 13)),
            subtitle: Text(
              _linkedDate != null
                  ? DateFormat('dd.MM.yyyy').format(_linkedDate!)
                  : 'Выберите дату',
              style: const TextStyle(fontSize: 12),
            ),
            leading: const Icon(Icons.link, size: 20),
            onTap: () async {
              final selectedDate = await DatePickerDialog.show(
                context: context,
                initialDate: _linkedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (selectedDate != null) {
                setState(() {
                  _linkedDate = selectedDate;
                  _isDirty = true;
                });
              }
            },
          ),
      ],
    );
  }

  // Настройки тем
  Widget _buildThemeSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Темы:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),

        Consumer<ThemesProvider>(
          builder: (context, themesProvider, _) {
            if (themesProvider.themes.isEmpty) {
              return const Text(
                'Нет доступных тем. Создайте темы в разделе Темы.',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              );
            }

            // Возвращаем Wrap с чипами тем
            return Wrap(
              spacing: 6.0,
              runSpacing: 6.0,
              children:
                  themesProvider.themes.map((theme) {
                    final isSelected = _themeIds.contains(theme.id);

                    // Парсим цвет из строки
                    Color themeColor;
                    try {
                      themeColor = Color(int.parse(theme.color));
                    } catch (e) {
                      themeColor = Colors.blue;
                    }

                    return FilterChip(
                      label: Text(
                        theme.name,
                        style: TextStyle(
                          color:
                              isSelected
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.9),
                          fontSize: 12,
                        ),
                      ),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      selectedColor: themeColor.withOpacity(0.7),
                      backgroundColor: themeColor.withOpacity(0.3),
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 0,
                      ),
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_themeIds.contains(theme.id)) {
                              _themeIds.add(theme.id);
                              _isDirty = true;
                            }
                          } else {
                            _themeIds.remove(theme.id);
                            _isDirty = true;
                          }
                        });
                      },
                    );
                  }).toList(),
            );
          },
        ),
      ],
    );
  }

  // Теги тем в режиме просмотра
  Widget _buildThemeTags() {
    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        final themes =
            _themeIds
                .map((id) => themesProvider.getThemeById(id))
                .where((t) => t != null)
                .toList();

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              themes.map((theme) {
                Color themeColor;
                try {
                  themeColor = Color(int.parse(theme!.color));
                } catch (e) {
                  themeColor = AppColors.themeColors[0];
                }

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: themeColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    theme!.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
        );
      },
    );
  }

  // Определение цвета для дедлайна
  Color _getDeadlineColor() {
    if (_isTaskCompleted) {
      return AppColors.completed;
    }

    if (!_hasDeadline || _deadlineDate == null) {
      return Colors.grey;
    }

    final now = DateTime.now();
    final daysUntilDeadline = _deadlineDate!.difference(now).inDays;

    if (daysUntilDeadline < 0) {
      return AppColors.deadlineUrgent; // Просрочено
    } else if (daysUntilDeadline <= 2) {
      return AppColors.deadlineUrgent; // Срочно
    } else if (daysUntilDeadline <= 7) {
      return AppColors.deadlineNear; // Скоро
    } else {
      return AppColors.deadlineFar; // Не срочно
    }
  }
}
