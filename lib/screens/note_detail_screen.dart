import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import '../providers/themes_provider.dart';
import '../widgets/voice_note_player.dart';
import '../widgets/media_attachment_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:math';
import '../widgets/quill_editor_wrapper.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'dart:convert';
import '../services/media_service.dart';
import '../widgets/reminder_settings_section.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:flutter_quill/quill_delta.dart';
import '../models/note.dart' as note_model;
import '../models/theme.dart' as app_theme;
import '../services/media_service.dart';
import '../utils/extensions.dart';
import '../widgets/animated_check.dart';
import '../widgets/emoji_selector.dart';
import '../widgets/expandable_fab.dart';
import '../widgets/custom_date_picker.dart';
import '../widgets/theme_chip.dart';
import '../widgets/theme_selector.dart';
import '../widgets/voice_record_button.dart';
import '../widgets/custom_time_picker.dart';

class NoteDetailScreen extends StatefulWidget {
  final Note? note; // Null если создаем новую заметку
  final DateTime? initialDate; // Начальная дата, если пришли из календаря
  final bool isEditMode; // Параметр для начального режима редактирования
  final List<String>?
  initialThemeIds; // Добавлен новый параметр для автоматической привязки к теме

  const NoteDetailScreen({
    super.key,
    this.note,
    this.initialDate,
    this.isEditMode = false, // По умолчанию режим просмотра
    this.initialThemeIds, // Новый параметр
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen>
    with TickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();

  bool _hasDeadline = false;
  bool _isTaskCompleted = false;
  DateTime? _deadlineDate;
  bool _hasDateLink = false;
  DateTime? _linkedDate;
  String? _emoji;
  List<String> _selectedThemeIds = [];
  bool _isSettingsChanged = false;
  bool _isEditing = false;
  bool _isEditMode = false;
  bool _isContentChanged = false;
  bool _isFocusMode = false;
  bool _isLoading = false;
  List<String> _mediaFiles = []; // Поле для медиафайлов

  // Добавленные переменные для напоминаний
  bool _hasReminders = false;
  List<DateTime> _reminderDates = [];
  String _reminderSound = 'default';
  // Новые поля для типа напоминания
  ReminderType _reminderType = ReminderType.exactTime;
  RelativeReminder? _relativeReminder;

  // Для перехода между режимами
  late AnimationController _modeTransitionController;
  late Animation<double> _modeTransitionAnimation;

  // Для режима фокусировки
  late AnimationController _focusModeController;
  late Animation<double> _focusModeAnimation;

  late FocusNode _focusNode;
  late TabController _tabController;
  int _selectedTabIndex = 0;
  bool _isPreviewMode = false;

  // Добавляем отсутствующие переменные
  late QuillController _quillController;
  TimeOfDay? _deadlineTime;

  // Методы для настройки автосохранения и аналитики
  Timer? _autoSaveTimer;

  void _contentChangeListener() {
    // При каждом изменении контента сбрасываем и создаем новый таймер
    _autoSaveTimer?.cancel();

    // Устанавливаем флаг изменений, если текст изменился
    if (!_isContentChanged &&
        widget.note != null &&
        _contentController.text != widget.note!.content) {
      setState(() {
        _isContentChanged = true;
      });
    }

    // Запускаем новый таймер - он сработает через 5 секунд бездействия
    _autoSaveTimer = Timer(const Duration(seconds: 5), () {
      if (mounted && (_isContentChanged || _isSettingsChanged)) {
        debugPrint('Отложенное автосохранение после 5 секунд бездействия');
        _performAutoSave();
      }
    });
  }

  void _performAutoSave() {
    // Получаем длину контента в обоих местах для диагностики
    try {
      final quillLength = _quillController.document.length;
      final controllerLength = _contentController.text.length;
      debugPrint(
        'Диагностика перед автосохранением: Длина: quill=$quillLength, controller=$controllerLength',
      );

      // Проверяем, что текст не пустой перед сохранением
      final quillTextLength =
          _quillController.document.toPlainText().trim().length;
      if (quillTextLength == 0 && _contentController.text.isNotEmpty) {
        debugPrint(
          'ВНИМАНИЕ: документ пуст, но контроллер не пуст - пропускаем автосохранение',
        );
        return;
      }

      // Если длина quillController слишком мала - возможно проблема с синхронизацией
      if (quillLength < 5 &&
          widget.note != null &&
          widget.note!.content.isNotEmpty) {
        debugPrint(
          'ВНИМАНИЕ: подозрительно короткая длина документа - пропускаем автосохранение',
        );
        return;
      }

      _saveNote();
    } catch (e) {
      debugPrint('Ошибка при автосохранении: $e');
    }
  }

  // Улучшенный метод настройки автосохранения
  void _setupAutoSave() {
    // Вместо постоянного таймера, используем отложенное сохранение
    // при бездействии пользователя

    // 1. Отменяем предыдущий таймер автосохранения при создании нового
    _autoSaveTimer?.cancel();

    // Периодическое сохранение каждые 30 секунд
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        debugPrint('Виджет не в дереве, отменяем автосохранение');
        timer.cancel();
        return;
      }

      debugPrint('Сработал таймер периодического автосохранения');
      debugPrint(
        'Статус изменений: _isContentChanged=$_isContentChanged, _isSettingsChanged=$_isSettingsChanged',
      );

      if (_isContentChanged || _isSettingsChanged) {
        debugPrint('Есть изменения, выполняем автосохранение');
        _performAutoSave();
      } else {
        debugPrint('Нет изменений, пропускаем автосохранение');
      }
    });

    // Настраиваем обработчики для отложенного сохранения при изменении контента
    _contentController.addListener(_contentChangeListener);
  }

  @override
  void disposeOld() {
    // Метод оставлен пустым намеренно, так как он дублирует dispose()
  }

  void _handleFocusChange() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    // Активируем режим фокусировки только если фокус на редакторе и включена опция в настройках
    if (_focusNode.hasFocus && appProvider.enableFocusMode && !_isPreviewMode) {
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
  void initState() {
    super.initState();
    _initializeEditorFromNote();
    // Настраиваем автосохранение
    _setupAutoSave();
    // Включаем режим редактирования для новых заметок
    if (widget.note == null) {
      _isEditMode = true;
    }
    _setupAnalytics();

    _focusNode = _contentFocusNode;
    _tabController = TabController(length: 2, vsync: this);

    // Инициализация контроллеров анимации
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

    // Слушаем изменения табов для переключения между режимами
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
        _isPreviewMode = _selectedTabIndex == 1;
      });
    });

    // Слушаем фокус
    _focusNode.addListener(_handleFocusChange);

    // Слушаем изменения содержимого
    if (_isEditing) {
      // Слушаем изменения содержимого
      _contentController.addListener(() {
        if (!_isContentChanged &&
            widget.note != null &&
            _contentController.text != widget.note!.content) {
          setState(() {
            _isContentChanged = true;
          });
        }
      });

      // Инициализируем флаг изменений настроек
      _isSettingsChanged = false;
    }
  }

  // Метод инициализации редактора из заметки
  void _initializeEditorFromNote() {
    if (widget.note != null) {
      _contentController.text = widget.note!.content;

      // Инициализируем контроллер Quill из данных заметки
      _initializeQuillController();

      // Загружаем данные дедлайна, если есть
      if (widget.note!.deadlineDate != null) {
        _hasDeadline = true;
        _deadlineDate = widget.note!.deadlineDate;

        // Инициализируем время дедлайна, если есть
        if (widget.note!.deadlineDate != null) {
          _deadlineTime = TimeOfDay(
            hour: widget.note!.deadlineDate!.hour,
            minute: widget.note!.deadlineDate!.minute,
          );
        }

        _isTaskCompleted = widget.note!.isCompleted;
      }

      // Загружаем темы
      if (widget.note!.themeIds.isNotEmpty) {
        _selectedThemeIds = widget.note!.themeIds;
      }

      // Загружаем медиа-файлы, если есть
      _loadMediaFiles();
    } else {
      // Инициализируем пустой документ Quill
      _quillController = QuillController.basic();
    }
  }

  // Метод сохранения заметки
  Future<void> _saveNote() async {
    try {
      debugPrint(
        '=================== НАЧАЛО СОХРАНЕНИЯ ЗАМЕТКИ ===================',
      );

      // Проверяем, есть ли изменения
      if (!_isContentChanged && !_isSettingsChanged) {
        debugPrint('Нет изменений для сохранения.');
        return; // Выходим, если нет изменений
      }

      setState(() {
        _isLoading = true;
      });

      // Прежде чем получать содержимое - убедимся, что QuillController инициализирован
      if (_quillController == null) {
        debugPrint(
          '_quillController не инициализирован, инициализируем с базовым контентом',
        );
        _quillController = QuillController.basic();
      }

      // Получаем содержимое из Quill контроллера в виде JSON Delta
      // Важно: используем правильный формат Delta JSON с ключом 'ops'
      final deltaJson = jsonEncode({
        'ops': _quillController!.document.toDelta().toJson(),
      });

      // Обновляем TextEditingController с новым JSON
      _contentController.text = deltaJson;

      debugPrint(
        'Контент сохранен в формате Delta JSON длиной: ${deltaJson.length}',
      );

      // Получаем текстовое содержимое для проверки
      final plainText = _quillController!.document.toPlainText().trim();
      debugPrint(
        'Текстовое содержимое: "${plainText}", длина: ${plainText.length}',
      );

      // Проверяем, не пустая ли заметка (если контент пустой и нет связанных тем/дат)
      final bool isEmptyNote =
          plainText.isEmpty &&
          _selectedThemeIds.isEmpty &&
          !_hasDeadline &&
          !_hasDateLink &&
          _mediaFiles.isEmpty;

      if (isEmptyNote) {
        setState(() {
          _isLoading = false;
        });

        // Показываем уведомление о пустой заметке
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Нельзя сохранить пустую заметку. Добавьте текст или прикрепите медиафайл.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Получаем доступ к провайдеру
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      // Определяем, создаем новую заметку или обновляем существующую
      if (widget.note == null) {
        // Создание новой заметки
        debugPrint('Создание новой заметки...');

        // Если содержимое пустое, но есть медиафайлы или настройки, добавляем базовый контент
        if (plainText.isEmpty && !isEmptyNote) {
          debugPrint(
            'Добавляем базовый контент для пустой заметки с настройками',
          );
          _contentController.text = jsonEncode({
            'ops': [
              {'insert': 'Новая заметка\n'},
            ],
          });
        }

        final newNote = await notesProvider.createNote(
          content: _contentController.text,
          themeIds: _selectedThemeIds,
          hasDeadline: _hasDeadline,
          deadlineDate: _deadlineDate,
          hasDateLink: _hasDateLink,
          linkedDate: _linkedDate,
          mediaUrls: _mediaFiles,
          emoji: _emoji,
          reminderDates: _reminderDates,
          reminderSound: _reminderSound,
          reminderType: _reminderType,
          relativeReminder: _relativeReminder,
        );

        debugPrint(
          'Результат создания: ${newNote != null ? "Успешно, ID: ${newNote.id}" : "Ошибка"}',
        );

        if (newNote == null) {
          throw Exception('Не удалось создать заметку через провайдер');
        }
      } else {
        // Обновление существующей заметки
        debugPrint('Обновление существующей заметки ID: ${widget.note!.id}');

        // Создаем обновленную копию заметки
        final updatedNote = widget.note!.copyWith(
          content: _contentController.text,
          themeIds: _selectedThemeIds,
          hasDeadline: _hasDeadline,
          deadlineDate: _deadlineDate,
          hasDateLink: _hasDateLink,
          linkedDate: _linkedDate,
          isCompleted: _isTaskCompleted, // Обновляем статус выполнения
          mediaUrls: _mediaFiles,
          emoji: _emoji,
          reminderDates: _reminderDates,
          reminderSound: _reminderSound,
          reminderType: _reminderType,
          relativeReminder: _relativeReminder,
          updatedAt: DateTime.now(), // Обновляем время последнего изменения
        );

        debugPrint('Отправка обновленной заметки в провайдер...');
        final success = await notesProvider.updateNote(updatedNote);
        debugPrint('Результат обновления: ${success ? "Успешно" : "Ошибка"}');

        if (!success) {
          throw Exception('Не удалось обновить заметку через провайдер');
        }
      }

      // Сбрасываем флаги изменений после успешного сохранения
      setState(() {
        _isContentChanged = false;
        _isSettingsChanged = false;
        _isLoading = false;
      });

      // Показываем уведомление пользователю для подтверждения
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заметка успешно сохранена'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 1),
        ),
      );

      // Возвращаемся на предыдущий экран, если виджет все еще в дереве
      if (mounted) {
        Navigator.of(context).pop();
      }
      debugPrint(
        '=================== СОХРАНЕНИЕ ЗАМЕТКИ ЗАВЕРШЕНО УСПЕШНО ===================',
      );
    } catch (error) {
      debugPrint('!!!!! ОШИБКА ПРИ СОХРАНЕНИИ ЗАМЕТКИ: $error !!!!!');
      debugPrint('Стек вызовов ошибки: ${StackTrace.current}');

      setState(() {
        _isLoading = false;
      });

      // Показываем уведомление пользователю
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Не удалось сохранить заметку: ${error.toString().split(':').last.trim()}',
            ), // Показываем более короткое сообщение об ошибке
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Метод инициализации Quill контроллера из заметки
  void _initializeQuillController() {
    if (_contentController.text.isEmpty) {
      // Если содержимое пустое, создаем пустой документ
      debugPrint('Инициализация пустого Quill документа');
      _quillController = QuillController.basic();

      // Устанавливаем слушатель изменений для документа
      _quillController.document.changes.listen((event) {
        if (!_isContentChanged) {
          setState(() {
            _isContentChanged = true;
          });
        }
      });

      return;
    }

    try {
      // Пробуем разобрать JSON Delta из контента заметки
      final previewLength =
          _contentController.text.length > 50
              ? 50
              : _contentController.text.length;
      debugPrint(
        'Попытка инициализации Quill из JSON: ${_contentController.text.substring(0, previewLength)}...',
      );

      // Декодируем JSON
      final dynamic contentJson = json.decode(_contentController.text);

      // Определяем формат JSON Delta и создаем Delta из соответствующего источника
      Delta delta;
      if (contentJson is Map<String, dynamic> &&
          contentJson.containsKey('ops')) {
        // Формат с ключом 'ops'
        debugPrint('Обнаружен формат Delta JSON с ключом "ops"');
        delta = Delta.fromJson(contentJson['ops'] as List);
      } else if (contentJson is List) {
        // Формат без ключа 'ops' (просто массив операций)
        debugPrint('Обнаружен формат Delta JSON без ключа "ops"');
        delta = Delta.fromJson(contentJson);
      } else {
        // Неизвестный формат JSON
        debugPrint('Неизвестный формат JSON, создаем пустой документ');
        throw FormatException('Неизвестный формат JSON Delta');
      }

      // Создаем документ из Delta и инициализируем контроллер
      final document = Document.fromDelta(delta);
      _quillController = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );

      // Устанавливаем слушатель изменений для документа
      _quillController.document.changes.listen((event) {
        if (!_isContentChanged) {
          setState(() {
            _isContentChanged = true;
          });
        }
      });

      debugPrint('Quill контроллер успешно инициализирован из JSON Delta');
    } catch (e) {
      debugPrint('Ошибка при инициализации Quill документа из JSON: $e');

      // Если формат не распознан или данные пустые - создаем новый документ с текстом
      _quillController = QuillController.basic();

      // Устанавливаем слушатель изменений
      _quillController.document.changes.listen((event) {
        if (!_isContentChanged) {
          setState(() {
            _isContentChanged = true;
          });
        }
      });

      // Пытаемся интерпретировать контент как обычный текст
      final plainText = _contentController.text;
      if (plainText.isNotEmpty) {
        try {
          if (plainText.startsWith('{') || plainText.startsWith('[')) {
            debugPrint(
              'Контент похож на JSON, но не удалось разобрать. Создаем пустой документ.',
            );
          } else {
            // Вставляем текст в документ только если он не похож на JSON
            _quillController.document.insert(0, plainText);
            final previewLength = plainText.length > 50 ? 50 : plainText.length;
            debugPrint(
              'Вставлен обычный текст в документ: ${plainText.substring(0, previewLength)}...',
            );
          }
        } catch (textError) {
          debugPrint('Ошибка вставки обычного текста: $textError');
        }
      }
    }
  }

  @override
  void dispose() {
    // Очищаем ресурсы
    _autoSaveTimer?.cancel();
    _contentController.removeListener(_contentChangeListener);

    _contentController.dispose();
    _contentFocusNode.dispose();

    // Освобождение всех контроллеров анимации
    _modeTransitionController.dispose();
    _focusModeController.dispose();
    _tabController.dispose();

    if (_focusNode != _contentFocusNode) {
      _focusNode.removeListener(_handleFocusChange);
    }
    super.dispose();
  }

  // Добавляем метод для выбора медиафайлов
  void _pickMedia(BuildContext context) {
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
                      _isSettingsChanged = true;
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
                      _isSettingsChanged = true;
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
                      _isSettingsChanged = true;
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

  // Метод для удаления медиафайла
  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      _isSettingsChanged = true;
    });
  }

  // Обработчик изменения напоминаний
  void _handleRemindersChanged(
    List<DateTime> dates,
    String sound, {
    bool isRelativeTimeActive = false,
    int? relativeMinutes,
    String? relativeDescription,
  }) {
    if (!mounted) return;

    setState(() {
      _reminderDates = dates;
      _reminderSound = sound;

      // Обновляем тип напоминания и информацию о относительном напоминании
      if (isRelativeTimeActive &&
          relativeMinutes != null &&
          relativeDescription != null) {
        _reminderType = ReminderType.relativeTime;
        _relativeReminder = RelativeReminder(
          minutes: relativeMinutes,
          description: relativeDescription,
        );
      } else {
        _reminderType = ReminderType.exactTime;
        _relativeReminder = null;
      }

      _isSettingsChanged = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return WillPopScope(
      onWillPop: () async {
        _onBackPressed();
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing
                ? (_isEditMode ? 'Редактирование заметки' : 'Просмотр заметки')
                : 'Новая заметка',
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _onBackPressed(),
          ),
          actions: [
            // Переключатель режима редактирования/просмотра (только для существующих заметок)
            if (_isEditing)
              IconButton(
                icon: Icon(_isEditMode ? Icons.visibility : Icons.edit),
                tooltip:
                    _isEditMode ? 'Режим просмотра' : 'Режим редактирования',
                onPressed: _toggleEditMode,
              ),

            // Кнопка сохранения (видима только в режиме редактирования)
            if (_isEditMode)
              IconButton(icon: const Icon(Icons.check), onPressed: _saveNote),

            // Меню действий
            PopupMenuButton<String>(
              itemBuilder:
                  (context) => [
                    if (_isEditing)
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
                if (value == 'delete' && _isEditing) {
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
              child: _getActiveEditor(),
            ),

            // Информация о дедлайне и заметке
            if (_hasDeadline || _hasDateLink || _selectedThemeIds.isNotEmpty)
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
                    if (_selectedThemeIds.isNotEmpty)
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
            // Используем уже существующий QuillEditorWrapper для редактирования
            QuillEditorWrapper(
              controller: _contentController,
              focusNode: _contentFocusNode,
              readOnly: !_isEditMode,
              onChanged: (content) {
                if (_isEditMode) {
                  // Прямая установка флага изменений
                  setState(() {
                    _isContentChanged = true;

                    // Сохраняем текущий контент в _contentController (должен быть установлен в QuillEditorWrapper)
                    debugPrint(
                      'Содержимое заметки изменено: ${content.substring(0, min(50, content.length))}...',
                    );
                  });
                }
              },
              onMediaAdded: (mediaPath) {
                if (mediaPath.isNotEmpty) {
                  setState(() {
                    _mediaFiles.add(mediaPath);
                    _isSettingsChanged = true;
                  });
                }
              },
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
                        // Левая колонка - настройки дат и дедлайнов (без напоминаний)
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

  // Оптимизированные настройки тем (правая колонка)
  Widget _buildThemeSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Темы:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13, // Уменьшение с 14 до 13
          ),
        ),
        const SizedBox(
          height: 4,
        ), // Уменьшен отступ с AppDimens.smallPadding до 4

        Consumer<ThemesProvider>(
          builder: (context, themesProvider, _) {
            if (themesProvider.themes.isEmpty) {
              return const Text(
                'Нет доступных тем. Создайте темы в разделе Темы.',
                style: TextStyle(
                  fontSize: 12, // Уменьшение с 14 до 12
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              );
            }

            // Возвращаем Wrap с чипами тем (компактнее)
            return Wrap(
              spacing: 6.0, // Уменьшен с 8.0 до 6.0
              runSpacing: 6.0, // Уменьшен с 8.0 до 6.0
              children:
                  themesProvider.themes.map((theme) {
                    final isSelected = _selectedThemeIds.contains(theme.id);

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
                          fontSize: 12, // Уменьшен с 13 до 12
                        ),
                      ),
                      selected: isSelected,
                      checkmarkColor: Colors.white,
                      selectedColor: themeColor.withOpacity(0.7),
                      backgroundColor: themeColor.withOpacity(0.3),
                      visualDensity:
                          VisualDensity.compact, // Компактный размер чипа
                      padding: const EdgeInsets.symmetric(
                        horizontal: 2,
                        vertical: 0,
                      ), // Уменьшены отступы
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            if (!_selectedThemeIds.contains(theme.id)) {
                              _selectedThemeIds.add(theme.id);

                              // Если выбрана тема, также добавляем noteId к теме
                              if (widget.note != null) {
                                final themesProvider =
                                    Provider.of<ThemesProvider>(
                                      context,
                                      listen: false,
                                    );
                                themesProvider.addNoteToTheme(
                                  widget.note!.id,
                                  theme.id,
                                );
                              }

                              _isSettingsChanged = true;
                            }
                          } else {
                            _selectedThemeIds.remove(theme.id);

                            // Если тема снята, также удаляем noteId из темы
                            if (widget.note != null) {
                              final themesProvider =
                                  Provider.of<ThemesProvider>(
                                    context,
                                    listen: false,
                                  );
                              themesProvider.removeNoteFromTheme(
                                widget.note!.id,
                                theme.id,
                              );
                            }

                            _isSettingsChanged = true;
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
            _selectedThemeIds
                .map(
                  (id) => themesProvider.themes.firstWhere(
                    (t) => t.id == id,
                    orElse:
                        () => themesProvider.themes.firstWhere(
                          (t) => true,
                          orElse:
                              () => NoteTheme(
                                id: '',
                                name: 'Unknown',
                                color:
                                    AppColors.themeColors[0].value.toString(),
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                                noteIds: [],
                              ),
                        ),
                  ),
                )
                .where((t) => t.id.isNotEmpty)
                .toList();

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children:
              themes.map((theme) {
                Color themeColor;
                try {
                  themeColor = Color(int.parse(theme.color));
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
                    theme.name,
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

  // Метод для переключения режима (просмотр <-> редактирование)
  void _toggleEditMode() {
    // Если переходим из просмотра в редактирование
    if (!_isEditMode && widget.note != null) {
      // Загружаем содержимое заметки в Quill редактор
      // QuillEditorWrapper позаботится о преобразовании JSON в Delta

      // _contentController для QuillEditorWrapper используется только как хранилище JSON
      _contentController.text = widget.note!.content;

      // Сбрасываем флаг изменений, так как мы только загрузили текст
      _isContentChanged = false;
    }

    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _modeTransitionController.forward();
      } else {
        _modeTransitionController.reverse();
      }
    });
  }

  // Метод для получения активного редактора с настроенным интерфейсом
  Widget _getActiveEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Используем уже существующий QuillEditorWrapper для редактирования
        QuillEditorWrapper(
          controller: _contentController,
          focusNode: _contentFocusNode,
          readOnly: !_isEditMode,
          onChanged: (content) {
            if (_isEditMode) {
              setState(() {
                _isContentChanged = true;
              });
            }
          },
          onMediaAdded: (mediaPath) {
            if (mediaPath.isNotEmpty) {
              setState(() {
                _mediaFiles.add(mediaPath);
                _isSettingsChanged = true;
              });
            }
          },
        ),
      ],
    );
  }

  // Методы для настройки автосохранения и аналитики
  void _setupAutoSaveOld() {
    // Настройка автоматического сохранения каждые 30 секунд
    Timer.periodic(const Duration(seconds: 30), (timer) {
      if (!mounted) {
        debugPrint('Виджет не в дереве, отменяем автосохранение');
        timer.cancel();
        return;
      }

      debugPrint('Сработал таймер автосохранения');
      debugPrint(
        'Статус изменений: _isContentChanged=$_isContentChanged, _isSettingsChanged=$_isSettingsChanged',
      );

      if (_isContentChanged || _isSettingsChanged) {
        debugPrint('Есть изменения, выполняем автосохранение');

        // Получаем длину контента в обоих местах для диагностики
        String diagnosticInfo = '';
        try {
          final quillLength = _quillController.document.length;
          final controllerLength = _contentController.text.length;
          diagnosticInfo =
              'Длина: quill=$quillLength, controller=$controllerLength';
        } catch (e) {
          diagnosticInfo = 'Ошибка при получении длины: $e';
        }
        debugPrint('Диагностика перед автосохранением: $diagnosticInfo');

        // Проверяем, что текст не пустой перед сохранением
        try {
          final quillTextLength =
              _quillController.document.toPlainText().trim().length;
          if (quillTextLength == 0 && _contentController.text.isNotEmpty) {
            debugPrint(
              'ВНИМАНИЕ: документ пуст, но контроллер не пуст - пропускаем автосохранение',
            );
            return;
          }
        } catch (e) {
          debugPrint('Ошибка при проверке длины текста: $e');
        }

        _saveNote();
      } else {
        debugPrint('Нет изменений, пропускаем автосохранение');
      }
    });
  }

  void _setupAnalytics() {
    // Метод-заглушка для аналитики
    // В реальном приложении здесь могут быть вызовы к Firebase Analytics и т.п.
  }

  // Метод для загрузки медиа-файлов
  void _loadMediaFiles() {
    if (widget.note != null && widget.note!.mediaUrls.isNotEmpty) {
      setState(() {
        _mediaFiles = List.from(widget.note!.mediaUrls);
      });
    }
  }

  // Метод для обработки выбора вложений
  void _onAttachmentSelect(String mediaPath) {
    if (mediaPath.isNotEmpty) {
      setState(() {
        _mediaFiles.add(mediaPath);
        _isSettingsChanged = true;
      });
    }
  }

  // Обработка нажатия кнопки "Назад"
  void _onBackPressed() async {
    // Если есть несохраненные изменения, показываем диалог подтверждения
    if (_isEditing && (_isContentChanged || _isSettingsChanged)) {
      final result = await _showUnsavedChangesDialog();

      if (result == null) {
        // Пользователь выбрал "Отмена", остаемся на экране редактирования
        return;
      } else if (result) {
        // Пользователь выбрал "Сохранить"
        await _saveNote();
      } else {
        // Пользователь выбрал "Не сохранять"
        if (_isEditMode) {
          // Если мы редактируем существующую заметку, переходим в режим просмотра
          setState(() {
            _isEditMode = false;

            // Восстанавливаем исходное содержимое
            if (widget.note != null) {
              _contentController.text = widget.note!.content;
              _hasDeadline = widget.note!.hasDeadline;
              _deadlineDate = widget.note!.deadlineDate;
              _hasDateLink = widget.note!.hasDateLink;
              _linkedDate = widget.note!.linkedDate;
              _selectedThemeIds = List.from(widget.note!.themeIds);
              _emoji = widget.note!.emoji;
              _mediaFiles = List.from(
                widget.note!.mediaUrls,
              ); // Сбрасываем список медиафайлов
              // Восстанавливаем настройки напоминаний
              _hasReminders =
                  widget.note!.reminderDates != null &&
                  widget.note!.reminderDates!.isNotEmpty;
              _reminderDates =
                  widget.note!.reminderDates != null
                      ? List<DateTime>.from(widget.note!.reminderDates!)
                      : [];
              _reminderSound = widget.note!.reminderSound ?? 'default';
            }

            _isContentChanged = false;
            _isSettingsChanged = false; // Сбрасываем флаг изменений настроек
          });
        } else {
          // Если это новая заметка, просто закрываем экран
          Navigator.pop(context);
        }
      }
    } else {
      // Если изменений нет, просто возвращаемся
      Navigator.pop(context);
    }
  }

  // Проверка при попытке выхода
  Future<bool> _onWillPop() async {
    // Если есть несохраненные изменения, показываем диалог подтверждения
    if (_isEditing && (_isContentChanged || _isSettingsChanged)) {
      final result = await _showUnsavedChangesDialog();

      if (result == null) {
        // Пользователь выбрал "Отмена", остаемся на экране
        return false;
      } else if (result) {
        // Пользователь выбрал "Сохранить"
        await _saveNote();
        return true;
      } else {
        // Пользователь выбрал "Не сохранять"
        return true;
      }
    }
    return true;
  }

  // Диалог подтверждения при наличии несохраненных изменений
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
                onPressed: () {
                  Navigator.of(context).pop(false); // Не сохранять и выйти
                },
                child: const Text('Не сохранять'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true); // Сохранить и выйти
                },
                child: const Text('Сохранить'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(null); // Отмена (остаться)
                },
                child: const Text('Отмена'),
              ),
            ],
          ),
    );
  }

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
                    final notesProvider = Provider.of<NotesProvider>(
                      context,
                      listen: false,
                    );

                    try {
                      // Установим loading state перед удалением
                      setState(() {
                        _isLoading = true;
                      });

                      // Выполняем удаление заметки
                      await notesProvider.deleteNote(widget.note!.id);

                      // Отключаем loading state
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });
                      }

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Заметка удалена')),
                        );

                        // Задержка перед закрытием экрана, чтобы избежать ошибок при анимации
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (mounted) {
                            Navigator.pop(
                              context,
                            ); // Возвращаемся на предыдущий экран
                          }
                        });
                      }
                    } catch (e) {
                      // Отключаем loading state в случае ошибки
                      if (mounted) {
                        setState(() {
                          _isLoading = false;
                        });

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Ошибка удаления: ${e.toString()}'),
                          ),
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

  // Метод настройки дат и дедлайнов
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
              _isSettingsChanged = true;
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
              final selectedDate = await showDatePicker(
                context: context,
                initialDate:
                    _deadlineDate ??
                    DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                locale: const Locale('ru', 'RU'),
              );
              if (selectedDate != null) {
                setState(() {
                  _deadlineDate = selectedDate;
                  _isSettingsChanged = true;
                });
              }
            },
          ),

        // Настройка связанной даты
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Привязка к дате', style: TextStyle(fontSize: 13)),
          dense: true,
          value: _hasDateLink,
          onChanged: (value) {
            setState(() {
              _hasDateLink = value;
              _isSettingsChanged = true;
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
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: _linkedDate ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                locale: const Locale('ru', 'RU'),
              );
              if (selectedDate != null) {
                setState(() {
                  _linkedDate = selectedDate;
                  _isSettingsChanged = true;
                });
              }
            },
          ),
      ],
    );
  }
}
