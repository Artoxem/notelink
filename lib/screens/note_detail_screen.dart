import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';
import '../providers/themes_provider.dart';
import '../widgets/markdown_editor.dart';
import '../widgets/voice_note_player.dart';
import '../widgets/media_attachment_widget.dart';
import '../widgets/reminder_settings_section.dart';
import '../services/media_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

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
  bool _hasDateLink = true;
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

    if (widget.note != null) {
      // Редактирование существующей заметки
      _contentController.text = widget.note!.content;
      _hasDeadline = widget.note!.hasDeadline;
      _deadlineDate = widget.note!.deadlineDate;

      // Инициализация напоминаний
      _hasReminders = widget.note!.reminderDates != null &&
          widget.note!.reminderDates!.isNotEmpty;
      _reminderDates = widget.note!.reminderDates != null
          ? List<DateTime>.from(widget.note!.reminderDates!)
          : [];
      _reminderSound = widget.note!.reminderSound ?? 'default';

      // Инициализация типа напоминания и относительного напоминания
      _reminderType = widget.note!.reminderType;
      _relativeReminder = widget.note!.relativeReminder;

      // Автоматически устанавливаем привязку к дате
      _hasDateLink = true;
      _linkedDate =
          widget.note!.hasDateLink ? widget.note!.linkedDate : DateTime.now();

      _selectedThemeIds = List.from(widget.note!.themeIds);
      _emoji = widget.note!.emoji;

      // Загружаем медиафайлы
      _mediaFiles = List.from(widget.note!.mediaUrls);

      // Инициализируем статус задачи
      _isTaskCompleted = widget.note!.isCompleted;

      _isEditing = true;

      // Используем переданный параметр для определения начального режима
      _isEditMode = widget.isEditMode;

      // Если нужен режим редактирования, сразу устанавливаем состояние анимации
      if (_isEditMode) {
        _modeTransitionController.value = 1.0; // Анимация в конечном состоянии
      }
    } else {
      // Создание новой заметки
      _contentController.text = '';
      _hasDeadline = false;
      _deadlineDate = null;
      _hasDateLink = true;
      _linkedDate = widget.initialDate ?? DateTime.now();
      _selectedThemeIds = widget.initialThemeIds != null
          ? List.from(widget.initialThemeIds!)
          : [];
      _emoji = null;
      _mediaFiles = [];
      _isTaskCompleted = false;
      _isEditing = false;
      _isEditMode =
          true; // Для новой заметки сразу включаем режим редактирования

      // Инициализация напоминаний для новой заметки
      _hasReminders = false;
      _reminderDates = [];
      _reminderSound = 'default';
      _reminderType = ReminderType.exactTime;
      _relativeReminder = null;

      // Для новой заметки сразу устанавливаем анимацию редактирования
      _modeTransitionController.value = 1.0;
    }

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

  @override
  void dispose() {
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
                leading: const Icon(Icons.camera_alt,
                    color: AppColors.accentPrimary),
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
                leading: const Icon(Icons.photo_library,
                    color: AppColors.accentPrimary),
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
                leading: const Icon(Icons.attach_file,
                    color: AppColors.accentPrimary),
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
  void _handleRemindersChanged(List<DateTime> dates, String sound,
      {bool isRelativeTimeActive = false,
      int? relativeMinutes,
      String? relativeDescription}) {
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
    final notesProvider = Provider.of<NotesProvider>(context);
    final themesProvider = Provider.of<ThemesProvider>(context);

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing
              ? (_isEditMode ? 'Редактирование заметки' : 'Просмотр заметки')
              : 'Новая заметка'),
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
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: _saveNote,
              ),

            // Меню действий
            PopupMenuButton<String>(
              onSelected: (value) async {
                switch (value) {
                  case 'delete':
                    if (_isEditing) {
                      _showDeleteConfirmation();
                    }
                    break;
                  case 'favorite':
                    final notesProvider =
                        Provider.of<NotesProvider>(context, listen: false);
                    await notesProvider.toggleFavorite(widget.note!.id);

                    // Получаем обновленную заметку
                    final updatedNote = notesProvider.notes.firstWhere(
                      (n) => n.id == widget.note!.id,
                      orElse: () => widget.note!,
                    );

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(updatedNote.isFavorite
                              ? 'Заметка добавлена в избранное'
                              : 'Заметка удалена из избранного'),
                        ),
                      );
                    }
                    break;
                  case 'link':
                    // Открыть страницу связей (будет реализовано позже)
                    break;
                  case 'share':
                    // Поделиться заметкой (будет реализовано позже)
                    break;
                }
              },
              itemBuilder: (context) => [
                if (_isEditing)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Удалить'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                const PopupMenuItem<String>(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Поделиться'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ],
        ),
        body: themesProvider.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SizedBox(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: IndexedStack(
                  // Используем IndexedStack вместо анимированного переключения
                  index: _isEditMode ? 1 : 0,
                  children: [
                    // Режим просмотра
                    _buildViewMode(),

                    // Режим редактирования
                    _buildEditMode(),
                  ],
                ),
              ),
        resizeToAvoidBottomInset: true,
      ),
    );
  }

  // Метод для показа диалога подтверждения завершения задачи
  Future<void> _showCompleteTaskDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Завершить задачу'),
        content: const Text(
          'Вы уверены, что хотите пометить эту задачу как выполненную?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.completed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Выполнено'),
          ),
        ],
      ),
    );

    if (result == true && widget.note != null) {
      final notesProvider = Provider.of<NotesProvider>(context, listen: false);

      try {
        // Вызываем метод completeNote для изменения статуса
        await notesProvider.completeNote(widget.note!.id);

        // Обновляем данные на экране
        if (mounted) {
          setState(() {
            // Используем локальное состояние вместо изменения widget.note
            _isTaskCompleted = true;
          });

          // Показываем уведомление
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Задача помечена как выполненная'),
              backgroundColor: AppColors.completed,
            ),
          );
        }
      } catch (e) {
        // Обработка ошибок
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

// Обновляем метод _buildViewMode() - добавляем отображение медиа-файлов
  Widget _buildViewMode() {
    final bool enableMarkdown =
        Provider.of<AppProvider>(context).enableMarkdownFormatting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0), // Уменьшен с AppDimens.mediumPadding
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Информация о дате - компактно в одну строку
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Дата создания
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14, // Уменьшен размер с 16 до 14
                    color: AppColors.textOnDark.withOpacity(0.7),
                  ),
                  const SizedBox(width: 4), // Уменьшен отступ
                  Text(
                    'Создано: ${DateFormat('dd.MM.yyyy').format(widget.note?.createdAt ?? DateTime.now())}',
                    style: TextStyle(
                      fontSize: 12, // Уменьшен с 14 до 12
                      color: AppColors.textOnDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),

              // Информация о дедлайне рядом с датой создания
              if (_hasDeadline && _deadlineDate != null)
                Row(
                  children: [
                    Icon(
                      _isTaskCompleted ? Icons.check_circle : Icons.timer,
                      size: 14, // Уменьшен с 16 до 14
                      color: _getDeadlineColor(),
                    ),
                    const SizedBox(width: 4), // Уменьшен отступ
                    Text(
                      'Дедлайн: ${DateFormat('dd.MM.yyyy').format(_deadlineDate!)}',
                      style: TextStyle(
                        fontSize: 12, // Уменьшен с 14 до 12
                        color: _getDeadlineColor(),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Теги/темы, если есть - компактно в одну строку, а также кнопка "Выполнено"
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Маркеры тем (если есть)
                if (_selectedThemeIds.isNotEmpty)
                  Expanded(child: _buildThemeTags())
                else
                  const Spacer(),

                const Spacer(),

                // Кнопка "Выполнено" для незавершенных задач
                if (_hasDeadline && _deadlineDate != null)
                  _isTaskCompleted
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.completed,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.check_circle,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 4),
                              Text(
                                'Выполнено',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ElevatedButton.icon(
                          onPressed: _showCompleteTaskDialog,
                          icon:
                              const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Выполнить',
                              style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentSecondary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: const Size(0, 30),
                          ),
                        ),
              ],
            ),
          ),

          // Разделитель
          const Padding(
            padding:
                EdgeInsets.symmetric(vertical: 8.0), // Уменьшено с 16.0 до 8.0
            child: Divider(height: 1),
          ),

          // Добавляем улучшенное отображение медиа-файлов в режиме просмотра
          if (_mediaFiles.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "Прикрепленные файлы:",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  // Отдельно отображаем изображения и другие файлы
                  _buildMediaFilesSection(),
                ],
              ),
            ),

          // Содержимое заметки с поддержкой Markdown и голосовых сообщений
          if (enableMarkdown)
            Container(
              width: double
                  .infinity, // Добавляем это свойство для растягивания на всю ширину
              padding: const EdgeInsets.all(12.0), // Уменьшено с 16.0 до 12.0
              decoration: BoxDecoration(
                color: AppColors.textBackground,
                borderRadius:
                    BorderRadius.circular(AppDimens.buttonBorderRadius),
              ),
              child: _buildMarkdownWithVoiceNotes(_contentController.text),
            )
          else
            SizedBox(
              width: double
                  .infinity, // Добавляем SizedBox с full width для текстового варианта
              child: Text(
                _contentController.text,
                style: AppTextStyles.bodyMediumLight,
              ),
            ),
        ],
      ),
    );
  }

// Метод для группировки и отображения медиа-файлов по типам
  Widget _buildMediaFilesSection() {
    final MediaService mediaService = MediaService();

    // Разделяем файлы по типам
    final List<String> images = [];
    final List<String> otherFiles = [];

    for (String mediaPath in _mediaFiles) {
      if (mediaService.isImage(mediaPath)) {
        images.add(mediaPath);
      } else {
        otherFiles.add(mediaPath);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Отображаем изображения в виде сетки
        if (images.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: images.map((path) => _buildImagePreview(path)).toList(),
            ),
          ),

        // Отображаем остальные файлы в виде списка
        if (otherFiles.isNotEmpty)
          ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            itemCount: otherFiles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return MediaAttachmentWidget(
                mediaPath: otherFiles[index],
                onRemove: () {},
                isEditing: false,
                onTap: () => _openFileWithPreview(otherFiles[index]),
              );
            },
          ),
      ],
    );
  }

// Добавляем метод для отображения превью изображения
  Widget _buildImagePreview(String imagePath) {
    // Проверяем существование файла
    final file = File(imagePath);
    final fileExists = file.existsSync();

    return GestureDetector(
      onTap: () {
        if (fileExists) {
          _showImageFullscreen(imagePath);
        }
      },
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: fileExists
              ? AppColors.textBackground
              : AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: fileExists
                ? AppColors.secondary.withOpacity(0.3)
                : AppColors.error.withOpacity(0.5),
            width: 1,
          ),
        ),
        child: fileExists
            ? ClipRRect(
                borderRadius: BorderRadius.circular(7),
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    color: AppColors.error,
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Файл не найден",
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

// Добавляем метод для отображения изображения в полноэкранном режиме
  void _showImageFullscreen(String imagePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            children: [
              // Изображение с InteractiveViewer для зума
              InteractiveViewer(
                panEnabled: true,
                boundaryMargin: const EdgeInsets.all(20),
                minScale: 0.5,
                maxScale: 4,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    alignment: Alignment.center,
                    child: Image.file(
                      File(imagePath),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Icon(Icons.broken_image,
                              size: 48, color: Colors.white),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Кнопка закрытия
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // Кнопка для открытия во внешнем приложении
              Positioned(
                bottom: 40,
                right: 20,
                child: FloatingActionButton(
                  heroTag: 'openImageExternal',
                  backgroundColor: AppColors.accentSecondary,
                  mini: true,
                  child: const Icon(Icons.open_in_new, color: Colors.white),
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _openFileExternally(imagePath);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Метод для открытия файла с предварительным просмотром
  void _openFileWithPreview(String filePath) {
    final MediaService mediaService = MediaService();
    final extension = filePath.toLowerCase();

    // Проверяем тип файла и показываем соответствующий предпросмотр
    if (mediaService.isImage(filePath)) {
      _showImageFullscreen(filePath);
    } else if (extension.endsWith('.pdf') ||
        extension.endsWith('.doc') ||
        extension.endsWith('.docx') ||
        extension.endsWith('.txt')) {
      _showDocumentPreview(filePath);
    } else if (extension.endsWith('.mp3') ||
        extension.endsWith('.wav') ||
        extension.endsWith('.m4a')) {
      _showAudioPreview(filePath);
    } else {
      // Для других форматов показываем общее диалоговое окно
      _showFileOptionsDialog(filePath);
    }
  }

// Метод для показа диалога с опциями файла
  void _showFileOptionsDialog(String filePath) {
    final File file = File(filePath);
    final bool fileExists = file.existsSync();
    final MediaService mediaService = MediaService();
    final String fileName = mediaService.getFileNameFromPath(filePath);
    final String extension = mediaService.getFileExtension(filePath);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип файла: ${extension.toUpperCase().substring(1)}',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            if (!fileExists)
              const Text(
                'Файл не найден или был удален.',
                style: TextStyle(color: Colors.red, fontSize: 14),
              )
            else
              const Text(
                'Выберите действие:',
                style: TextStyle(fontSize: 14),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          if (fileExists)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openFileExternally(filePath);
              },
              child: const Text('Открыть'),
            ),
        ],
      ),
    );
  }

// Метод для показа предпросмотра аудио файла
  void _showAudioPreview(String filePath) {
    final File file = File(filePath);
    final bool fileExists = file.existsSync();
    final MediaService mediaService = MediaService();
    final String fileName = mediaService.getFileNameFromPath(filePath);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!fileExists)
              const Text(
                'Аудиофайл не найден или был удален.',
                style: TextStyle(color: Colors.red, fontSize: 14),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.music_note,
                        size: 48, color: Colors.purple),
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          if (fileExists)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openFileExternally(filePath);
              },
              child: const Text('Открыть'),
            ),
        ],
      ),
    );
  }

// Метод для показа предпросмотра документа
  void _showDocumentPreview(String filePath) {
    final File file = File(filePath);
    final bool fileExists = file.existsSync();
    final MediaService mediaService = MediaService();
    final String fileName = mediaService.getFileNameFromPath(filePath);
    final String extension = mediaService.getFileExtension(filePath);

    // Определяем иконку на основе расширения
    IconData fileIcon;
    Color iconColor;

    switch (extension) {
      case '.pdf':
        fileIcon = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case '.doc':
      case '.docx':
        fileIcon = Icons.description;
        iconColor = Colors.blue;
        break;
      case '.txt':
        fileIcon = Icons.article;
        iconColor = Colors.grey;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        iconColor = Colors.blue;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          fileName,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!fileExists)
              const Text(
                'Документ не найден или был удален.',
                style: TextStyle(color: Colors.red, fontSize: 14),
              )
            else
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(fileIcon, size: 48, color: iconColor),
                    const SizedBox(height: 8),
                    Text(
                      fileName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Формат: ${extension.toUpperCase().substring(1)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          if (fileExists)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openFileExternally(filePath);
              },
              child: const Text('Открыть'),
            ),
        ],
      ),
    );
  }

// Метод для открытия файла во внешнем приложении
  Future<void> _openFileExternally(String filePath) async {
    File file = File(filePath);
    if (await file.exists()) {
      try {
        // Используем url_launcher для открытия файла
        final uri = Uri.file(filePath);
        final canLaunch = await canLaunchUrl(uri);

        if (canLaunch) {
          await launchUrl(uri);
        } else {
          // Если не можем открыть, показываем сообщение
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content:
                      Text('Не удалось открыть файл во внешнем приложении')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: ${e.toString()}')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Файл не существует')),
        );
      }
    }
  }

  // Оптимизированный метод построения медиа-секции
  Widget _buildMediaSection() {
    // Если нет медиафайлов, не добавляем пустое пространство
    if (_mediaFiles.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Заголовок секции медиа
          const Padding(
            padding: EdgeInsets.only(bottom: 8.0),
            child: Text(
              "Прикрепленные файлы:",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),

          // Использем обертку для потенциально проблемных контентов
          Container(
            constraints: const BoxConstraints(
              maxHeight: 200, // Ограничиваем максимальную высоту
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _mediaFiles.map((mediaPath) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildMediaPreview(mediaPath),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Улучшенный метод для отображения предварительного просмотра медиафайла с обработкой ошибок
  Widget _buildMediaPreview(String mediaPath) {
    final extension = mediaPath.toLowerCase();

    // Проверка существования файла
    final file = File(mediaPath);
    final fileExists = file.existsSync();

    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: fileExists
            ? AppColors.textBackground
            : AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: fileExists
              ? AppColors.secondary.withOpacity(0.3)
              : AppColors.error.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Содержимое медиа или сообщение об ошибке
          if (!fileExists)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  color: AppColors.error,
                  size: 24,
                ),
                const SizedBox(height: 4),
                const Text(
                  "Файл не найден",
                  style: TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            )
          else if (extension.endsWith('.jpg') ||
              extension.endsWith('.jpeg') ||
              extension.endsWith('.png'))
            ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.file(
                File(mediaPath),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  );
                },
              ),
            )
          else if (extension.endsWith('.mp3') ||
              extension.endsWith('.wav') ||
              extension.endsWith('.m4a'))
            const Icon(Icons.audiotrack, size: 48, color: Colors.purple)
          else
            const Icon(Icons.insert_drive_file, size: 48, color: Colors.blue),

          // Кнопка удаления в режиме редактирования
          if (_isEditMode)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  color: Colors.white,
                  constraints: const BoxConstraints(
                    minWidth: 24,
                    minHeight: 24,
                  ),
                  padding: EdgeInsets.zero,
                  onPressed: () => _removeMedia(_mediaFiles.indexOf(mediaPath)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Построение режима редактирования с добавлением медиафайлов
  Widget _buildEditMode() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Редактор Markdown
            MarkdownEditor(
              controller: _contentController,
              focusNode: _contentFocusNode,
              placeholder: 'Начните вводить текст заметки...',
              autofocus: false,
              onMediaAdded: (mediaPath) {
                setState(() {
                  _mediaFiles.add(mediaPath);
                  _isSettingsChanged = true;
                });
              },
            ),

            // Раздел с медиафайлами
            _buildMediaSection(),

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
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Настройки в две колонки
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Левая колонка - настройки дат и дедлайнов (без напоминаний)
                        Expanded(
                          flex: 6,
                          child: _buildDateSettings(),
                        ),

                        // Разделитель
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          width: 1,
                          color: AppColors.secondary.withOpacity(0.3),
                        ),

                        // Правая колонка - выбор тем
                        Expanded(
                          flex: 8,
                          child: _buildThemeSettings(),
                        ),
                      ],
                    ),
                  ),

                  // Разделитель перед блоком напоминаний
                  if (_hasDeadline)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Divider(height: 1),
                    ),

                  // Блок настроек напоминаний (появляется только когда есть дедлайн)
                  if (_hasDeadline && _deadlineDate != null)
                    ReminderSettingsSection(
                      reminderDates: _reminderDates,
                      reminderSound: _reminderSound,
                      deadlineDate: _deadlineDate!,
                      hasReminders: _hasReminders,
                      onRemindersChanged: (
                        hasReminders,
                        dates,
                        sound, {
                        isRelativeTimeActive = false,
                        relativeMinutes,
                        relativeDescription,
                      }) {
                        setState(() {
                          _hasReminders = hasReminders;
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
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Метод форматирования даты с днем недели
  String _formatDateWithWeekday(DateTime date) {
    // Массив дней недели на русском языке
    final List<String> weekdays = [
      'понедельник',
      'вторник',
      'среда',
      'четверг',
      'пятница',
      'суббота',
      'воскресенье'
    ];

    // Получаем индекс дня недели (в Dart дни недели индексируются с 1, поэтому вычитаем 1)
    final int weekdayIndex = date.weekday - 1;

    // Форматируем дату в виде "DD.MM (день недели)"
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} (${weekdays[weekdayIndex]})';
  }

// Обновленный метод _buildDateSettings
  Widget _buildDateSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Настройка дедлайна с уменьшенными размерами
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Deadline',
            style: TextStyle(fontSize: 13),
          ),
          dense: true, // Делает виджет компактнее
          value: _hasDeadline,
          onChanged: (value) {
            setState(() {
              _hasDeadline = value;
              _isSettingsChanged = true;
              if (_hasDeadline && _deadlineDate == null) {
                _deadlineDate = DateTime.now().add(const Duration(days: 1));
              }
              // Сбрасываем напоминания, если отключаем дедлайн
              if (!_hasDeadline) {
                _hasReminders = false;
                _reminderDates = [];
              }
            });
          },
        ),

        // Выбор даты для дедлайна (компактнее) с оранжевым цветом
        if (_hasDeadline)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true, // Компактный размер
            title: const Text('Deadline', style: TextStyle(fontSize: 13)),
            subtitle: Text(
                _deadlineDate != null
                    ? _formatDateWithWeekday(_deadlineDate!)
                    : 'Выберите дату',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange, // Оранжевый цвет для даты дедлайна
                  fontWeight:
                      FontWeight.bold, // Делаем текст жирным для выделения
                )),
            leading: const Icon(Icons.calendar_today,
                size: 20, color: Colors.orange), // Оранжевый цвет иконки
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: _deadlineDate ??
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

        // Настройка связанной даты (компактнее)
        const SizedBox(height: 4),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true, // Компактный размер
          title: const Text('Создано', style: TextStyle(fontSize: 13)),
          subtitle: Text(
              _linkedDate != null
                  ? _formatDateWithWeekday(_linkedDate!)
                  : 'Выберите дату',
              style: const TextStyle(fontSize: 12)),
          leading: const Icon(Icons.link, size: 20),
          onTap: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: _linkedDate ?? widget.initialDate ?? DateTime.now(),
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
            height: 4), // Уменьшен отступ с AppDimens.smallPadding до 4

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
              children: themesProvider.themes.map((theme) {
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
                      color: isSelected
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
                      horizontal: 2, vertical: 0), // Уменьшены отступы
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        if (!_selectedThemeIds.contains(theme.id)) {
                          _selectedThemeIds.add(theme.id);
                          _isSettingsChanged = true;
                        }
                      } else {
                        _selectedThemeIds.remove(theme.id);
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
        final themes = _selectedThemeIds
            .map((id) => themesProvider.themes.firstWhere(
                  (t) => t.id == id,
                  orElse: () => themesProvider.themes.firstWhere(
                    (t) => true,
                    orElse: () => NoteTheme(
                      id: '',
                      name: 'Unknown',
                      color: AppColors.themeColors[0].value.toString(),
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                      noteIds: [],
                    ),
                  ),
                ))
            .where((t) => t.id.isNotEmpty)
            .toList();

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: themes.map((theme) {
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

  // Метод для отображения markdown с голосовыми сообщениями
  Widget _buildMarkdownWithVoiceNotes(String content) {
    if (!mounted) return const SizedBox();

    // Проверяем наличие голосовых сообщений в тексте
    final RegExp voiceRegex = RegExp(r'!\[voice\]\(voice:([^)]+)\)');
    final matches = voiceRegex.allMatches(content);

    if (matches.isEmpty) {
      // Если голосовых сообщений нет, просто отображаем markdown
      return MarkdownBody(
        data: content,
        selectable: true,
        styleSheet: MarkdownStyleSheet(
          h1: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppColors.textOnLight,
          ),
          h2: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textOnLight,
          ),
          h3: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textOnLight,
          ),
          p: TextStyle(
            fontSize: 16,
            color: AppColors.textOnLight,
          ),
          listBullet: TextStyle(
            fontSize: 16,
            color: AppColors.textOnLight,
          ),
          listIndent: 20.0,
          a: TextStyle(
            color: AppColors.accentPrimary,
            decoration: TextDecoration.underline,
          ),
          em: TextStyle(
            fontStyle: FontStyle.italic,
            color: AppColors.textOnLight,
          ),
          strong: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textOnLight,
          ),
          blockquoteDecoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: AppColors.accentPrimary,
                width: 4,
              ),
            ),
            color: AppColors.accentPrimary.withOpacity(0.1),
          ),
          blockquote: TextStyle(
            fontStyle: FontStyle.italic,
            color: AppColors.textOnLight.withOpacity(0.8),
          ),
          code: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: AppColors.secondary.withOpacity(0.2),
            color: AppColors.textOnLight,
          ),
          codeblockDecoration: BoxDecoration(
            color: AppColors.secondary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
              width: 1,
            ),
          ),
        ),
        onTapLink: (text, href, title) {
          if (href != null) {
            launchUrl(Uri.parse(href));
          }
        },
      );
    }

    // Если голосовые сообщения есть, создаем комбинированный виджет
    List<Widget> contentWidgets = [];
    int lastEnd = 0;

    for (final match in matches) {
      // Текст до голосового сообщения
      if (match.start > lastEnd) {
        final textBefore = content.substring(lastEnd, match.start);
        contentWidgets.add(
          MarkdownBody(
            data: textBefore,
            selectable: true,
            styleSheet: MarkdownStyleSheet(
              h1: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textOnLight,
              ),
              h2: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textOnLight,
              ),
              h3: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textOnLight,
              ),
              p: TextStyle(
                fontSize: 16,
                color: AppColors.textOnLight,
              ),
              listBullet: TextStyle(
                fontSize: 16,
                color: AppColors.textOnLight,
              ),
              listIndent: 20.0,
              a: TextStyle(
                color: AppColors.accentPrimary,
                decoration: TextDecoration.underline,
              ),
              em: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textOnLight,
              ),
              strong: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textOnLight,
              ),
              blockquoteDecoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.accentPrimary,
                    width: 4,
                  ),
                ),
                color: AppColors.accentPrimary.withOpacity(0.1),
              ),
              blockquote: TextStyle(
                fontStyle: FontStyle.italic,
                color: AppColors.textOnLight.withOpacity(0.8),
              ),
              code: TextStyle(
                fontFamily: 'monospace',
                backgroundColor: AppColors.secondary.withOpacity(0.2),
                color: AppColors.textOnLight,
              ),
              codeblockDecoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.3),
                  width: 1,
                ),
              ),
            ),
          ),
        );
      }

      // Добавляем виджет голосового сообщения в компактном виде
      final voiceNoteId = match.group(1);
      if (voiceNoteId != null) {
        contentWidgets.add(
          VoiceNotePlayer(
            audioPath: voiceNoteId,
            maxWidth: 280,
            compact: true, // Используем компактный режим
          ),
        );
      }

      lastEnd = match.end;
    }

    // Добавляем оставшийся текст
    if (lastEnd < content.length) {
      final textAfter = content.substring(lastEnd);
      contentWidgets.add(
        MarkdownBody(
          data: textAfter,
          selectable: true,
          styleSheet: MarkdownStyleSheet(
            h1: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnLight,
            ),
            h2: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnLight,
            ),
            h3: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textOnLight,
            ),
            p: TextStyle(
              fontSize: 16,
              color: AppColors.textOnLight,
            ),
            listBullet: TextStyle(
              fontSize: 16,
              color: AppColors.textOnLight,
            ),
            listIndent: 20.0,
            a: TextStyle(
              color: AppColors.accentPrimary,
              decoration: TextDecoration.underline,
            ),
            em: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textOnLight,
            ),
            strong: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textOnLight,
            ),
            blockquoteDecoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: AppColors.accentPrimary,
                  width: 4,
                ),
              ),
              color: AppColors.accentPrimary.withOpacity(0.1),
            ),
            blockquote: TextStyle(
              fontStyle: FontStyle.italic,
              color: AppColors.textOnLight.withOpacity(0.8),
            ),
            code: TextStyle(
              fontFamily: 'monospace',
              backgroundColor: AppColors.secondary.withOpacity(0.2),
              color: AppColors.textOnLight,
            ),
            codeblockDecoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.secondary.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contentWidgets,
    );
  }

  // Переключение между режимами просмотра и редактирования
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
    });
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
                  widget.note!.mediaUrls); // Сбрасываем список медиафайлов
              // Восстанавливаем настройки напоминаний
              _hasReminders = widget.note!.reminderDates != null &&
                  widget.note!.reminderDates!.isNotEmpty;
              _reminderDates = widget.note!.reminderDates != null
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
      builder: (context) => AlertDialog(
        title: const Text('Несохраненные изменения'),
        content: const Text(
            'У вас есть несохраненные изменения. Сохранить перед выходом?'),
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

  // Метод для сохранения напоминаний
  Future<void> _saveNote() async {
    setState(() {
      // Используем поле класса вместо локальной переменной
      _isLoading = true;
    });

    final content = _contentController.text.trim();

    if (content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Содержимое заметки не может быть пустым')),
      );
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    try {
      if (_isEditing && widget.note != null) {
        // Обновление существующей заметки
        final updatedNote = widget.note!.copyWith(
          content: content,
          themeIds: _selectedThemeIds,
          hasDeadline: _hasDeadline,
          deadlineDate: _hasDeadline ? _deadlineDate : null,
          hasDateLink: true,
          linkedDate: _linkedDate ?? DateTime.now(),
          emoji: _emoji,
          mediaUrls: _mediaFiles,
          reminderDates: _hasReminders && _hasDeadline ? _reminderDates : null,
          reminderSound: _hasReminders && _hasDeadline ? _reminderSound : null,
          reminderType: _hasReminders && _hasDeadline
              ? _reminderType
              : ReminderType.exactTime,
          relativeReminder:
              _hasReminders && _hasDeadline ? _relativeReminder : null,
          voiceNotes: widget.note!.voiceNotes, // Сохраняем голосовые заметки
        );

        final success = await notesProvider.updateNote(updatedNote);

        // Добавляем проверку успешности операции
        if (!success) {
          throw Exception('Не удалось обновить заметку');
        }

        // Обновляем состояние только если виджет все еще в дереве
        if (!mounted) return;

        // Переключаемся в режим просмотра
        if (_isEditMode) {
          setState(() {
            _isEditMode = false;
            _isContentChanged = false;
            _isSettingsChanged = false;
            _isLoading = false;
          });
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Заметка сохранена')),
        );
      } else {
        // Создание новой заметки
        final newNote = await notesProvider.createNote(
          content: content,
          themeIds: _selectedThemeIds,
          hasDeadline: _hasDeadline,
          deadlineDate: _hasDeadline ? _deadlineDate : null,
          hasDateLink: true,
          linkedDate: _linkedDate ?? DateTime.now(),
          emoji: _emoji,
          mediaUrls: _mediaFiles,
          reminderDates: _hasReminders && _hasDeadline ? _reminderDates : null,
          reminderSound: _hasReminders && _hasDeadline ? _reminderSound : null,
          reminderType: _hasReminders && _hasDeadline
              ? _reminderType
              : ReminderType.exactTime,
          relativeReminder:
              _hasReminders && _hasDeadline ? _relativeReminder : null,
        );

        // Добавляем проверку результата
        if (newNote == null) {
          throw Exception('Не удалось создать заметку');
        }

        // После создания новой заметки закрываем экран создания
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        Navigator.pop(context);
      }
    } catch (e) {
      // Обработка ошибок
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Повторить',
            textColor: Colors.white,
            onPressed: _saveNote,
          ),
        ),
      );

      // Логирование подробностей ошибки
      print('Ошибка при сохранении заметки: $e');
      print(StackTrace.current);
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить заметку'),
        content: const Text(
            'Вы уверены, что хотите удалить эту заметку? Это действие нельзя будет отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              if (widget.note != null) {
                final notesProvider =
                    Provider.of<NotesProvider>(context, listen: false);

                try {
                  await notesProvider.deleteNote(widget.note!.id);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Заметка удалена')),
                    );
                    Navigator.pop(context); // Возвращаемся на предыдущий экран
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Ошибка удаления: ${e.toString()}')),
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
}
