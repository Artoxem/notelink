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
import 'package:flutter_markdown/flutter_markdown.dart'; // Добавлен импорт для поддержки Markdown

class NoteDetailScreen extends StatefulWidget {
  final Note? note; // Null если создаем новую заметку
  final DateTime? initialDate; // Начальная дата, если пришли из календаря

  const NoteDetailScreen({
    super.key,
    this.note,
    this.initialDate,
  });

  @override
  State<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends State<NoteDetailScreen>
    with TickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _contentFocusNode = FocusNode();

  bool _hasDeadline = false;
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

    // Инициализация контроллера анимации для режима перехода
    _modeTransitionController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _modeTransitionAnimation = CurvedAnimation(
      parent: _modeTransitionController,
      curve: Curves.easeInOut,
    );

    if (widget.note != null) {
      // Редактирование существующей заметки
      _contentController.text = widget.note!.content;
      _hasDeadline = widget.note!.hasDeadline;
      _deadlineDate = widget.note!.deadlineDate;

      // Автоматически устанавливаем привязку к дате
      _hasDateLink = true;
      _linkedDate =
          widget.note!.hasDateLink ? widget.note!.linkedDate : DateTime.now();

      _selectedThemeIds = List.from(widget.note!.themeIds);
      _emoji = widget.note!.emoji;
      _isEditing = true;
      _isEditMode = false;
    } else {
      // Создание новой заметки - сразу включаем режим редактирования
      _isEditMode = true;
      _modeTransitionController.value = 1.0; // Анимация в конечном состоянии

      // Но не активируем автофокус для предотвращения появления клавиатуры
      _contentFocusNode.canRequestFocus = false;

      // Автоматически привязываем к выбранной или текущей дате
      _hasDateLink = true;
      _linkedDate = widget.initialDate ?? DateTime.now();

      // Не устанавливаем дедлайн автоматически
    }

    // Слушаем изменения табов для переключения между режимами
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
        _isPreviewMode = _selectedTabIndex == 1;
      });
    });

    if (widget.note != null) {
      // Редактирование существующей заметки
      _contentController.text = widget.note!.content;
      _hasDeadline = widget.note!.hasDeadline;
      _deadlineDate = widget.note!.deadlineDate;
      _hasDateLink = widget.note!.hasDateLink;
      _linkedDate = widget.note!.linkedDate;
      _selectedThemeIds = List.from(widget.note!.themeIds);
      _emoji = widget.note!.emoji;
      _isEditing = true;
      // Начинаем в режиме просмотра для существующих заметок
      _isEditMode = false;
    } else {
      // Создание новой заметки - сразу включаем режим редактирования
      _isEditMode = true;
      _modeTransitionController.value = 1.0; // Анимация в конечном состоянии

      // Если пришли из календаря, автоматически привязываем к выбранной дате
      if (widget.initialDate != null) {
        _hasDateLink = true;
        _linkedDate = widget.initialDate;

        // Не устанавливаем дедлайн автоматически
      } else {
        // Иначе привязываем к текущей дате
        _hasDateLink = true;
        _linkedDate = DateTime.now();
      }
    }

    // Слушаем изменения фокуса
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
              onSelected: (value) {
                switch (value) {
                  case 'delete':
                    if (_isEditing) {
                      _showDeleteConfirmation();
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
                  value: 'link',
                  child: ListTile(
                    leading: Icon(Icons.link),
                    title: Text('Управление связями'),
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
            : AnimatedBuilder(
                animation: _modeTransitionAnimation,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Режим просмотра
                      Opacity(
                        opacity: 1.0 - _modeTransitionAnimation.value,
                        child: IgnorePointer(
                          ignoring: _isEditMode,
                          child: _buildViewMode(),
                        ),
                      ),

                      // Режим редактирования
                      Opacity(
                        opacity: _modeTransitionAnimation.value,
                        child: IgnorePointer(
                          ignoring: !_isEditMode,
                          child: _buildEditMode(),
                        ),
                      ),
                    ],
                  );
                },
              ),
        resizeToAvoidBottomInset: true,
      ),
    );
  }

  // Построение режима просмотра
  Widget _buildViewMode() {
    final bool enableMarkdown =
        Provider.of<AppProvider>(context).enableMarkdownFormatting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppDimens.mediumPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Информация о дате
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 16,
                color: AppColors.textOnDark.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                'Создано: ${DateFormat('d MMMM yyyy, HH:mm').format(widget.note?.createdAt ?? DateTime.now())}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textOnDark.withOpacity(0.7),
                ),
              ),
            ],
          ),

          // Информация о дедлайне, если есть
          if (_hasDeadline && _deadlineDate != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Row(
                children: [
                  Icon(
                    widget.note?.isCompleted ?? false
                        ? Icons.check_circle
                        : Icons.timer,
                    size: 16,
                    color: _getDeadlineColor(),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Дедлайн: ${DateFormat('d MMMM yyyy').format(_deadlineDate!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: _getDeadlineColor(),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.note?.isCompleted ?? false)
                    const Text(
                      ' (Выполнено)',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.completed,
                      ),
                    ),
                ],
              ),
            ),

          // Теги/темы, если есть
          if (_selectedThemeIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: _buildThemeTags(),
            ),

          // Разделитель
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),

          // Содержимое заметки с поддержкой Markdown
          // Здесь изменим на MarkdownBody для режима просмотра
          if (enableMarkdown)
            // Используем MarkdownBody для отображения с форматированием
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.textBackground,
                borderRadius:
                    BorderRadius.circular(AppDimens.buttonBorderRadius),
              ),
              child: MarkdownBody(
                data: _contentController.text,
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
            )
          else
            // Используем обычный текстовый виджет, если Markdown отключен
            Text(
              _contentController.text,
              style: AppTextStyles.bodyMediumLight,
            ),
        ],
      ),
    );
  }

  // Построение режима редактирования
  Widget _buildEditMode() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppDimens.mediumPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Редактор Markdown
          Container(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height * 0.4,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: MarkdownEditor(
              controller: _contentController,
              focusNode: _contentFocusNode,
              placeholder: 'Начните вводить текст заметки...',
              autofocus: false,
            ),
          ),

          // Нижняя панель с настройками заметки в двух колонках
          Container(
            margin: const EdgeInsets.only(top: AppDimens.mediumPadding),
            padding: const EdgeInsets.all(AppDimens.mediumPadding),
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
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: AppDimens.mediumPadding),

                // Двухколоночная структура
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Левая колонка - настройки дат и дедлайнов
                    Expanded(
                      flex: 6,
                      child: _buildDateSettings(),
                    ),

                    // Разделитель
                    Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: AppDimens.mediumPadding),
                      width: 1,
                      height: 220, // Высота может быть адаптируемой
                      color: AppColors.secondary.withOpacity(0.3),
                    ),

                    // Правая колонка - выбор тем
                    Expanded(
                      flex: 8,
                      child: _buildThemeSettings(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Добавляем дополнительное пространство внизу для клавиатуры
          SizedBox(
              height: MediaQuery.of(context).viewInsets.bottom > 0 ? 200 : 0),
        ],
      ),
    );
  }

// Настройки даты и дедлайна (левая колонка)
  Widget _buildDateSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Настройка дедлайна
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(
            'Deadline',
            style: TextStyle(fontSize: 14),
          ),
          value: _hasDeadline,
          onChanged: (value) {
            setState(() {
              _hasDeadline = value;
              _isSettingsChanged = true; // Отмечаем изменение настроек
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
            title: const Text('Deadline'),
            subtitle: Text(_deadlineDate != null
                ? DateFormat('yyyy-MM-dd').format(_deadlineDate!)
                : 'Выберите дату'),
            leading: const Icon(Icons.calendar_today),
            onTap: () async {
              final selectedDate = await showDatePicker(
                context: context,
                initialDate: _deadlineDate ??
                    DateTime.now().add(const Duration(days: 1)),
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selectedDate != null) {
                setState(() {
                  _deadlineDate = selectedDate;
                  _isSettingsChanged = true; // Отмечаем изменение настроек
                });
              }
            },
          ),

        // Настройка связанной даты
        const SizedBox(height: AppDimens.smallPadding),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Создано'),
          subtitle: Text(_linkedDate != null
              ? DateFormat('yyyy-MM-dd').format(_linkedDate!)
              : 'Выберите дату'),
          leading: const Icon(Icons.link),
          onTap: () async {
            final selectedDate = await showDatePicker(
              context: context,
              initialDate: _linkedDate ?? widget.initialDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (selectedDate != null) {
              setState(() {
                _linkedDate = selectedDate;
                _isSettingsChanged = true; // Отмечаем изменение настроек
              });
            }
          },
        ),
      ],
    );
  }

// Настройки тем (правая колонка)
  Widget _buildThemeSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Темы:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: AppDimens.smallPadding),

        // Виджет выбора тем
        Container(
          constraints: BoxConstraints(
            // Минимальная высота, чтобы блок не был слишком маленьким
            minHeight: 150,
            // Максимальная высота, после которой появляется скролл
            maxHeight: 220,
          ),
          child: SingleChildScrollView(
            child: _buildThemeSelectionChips(),
          ),
        ),
      ],
    );
  }

  // Отображение чипов с выбранными темами
  Widget _buildThemeSelectionChips() {
    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        if (themesProvider.themes.isEmpty) {
          return const Text(
            'Нет доступных тем. Создайте темы в разделе Темы.',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          );
        }

        return Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: themesProvider.themes.map((theme) {
            final isSelected = _selectedThemeIds.contains(theme.id);

            // Парсим цвет из строки
            Color themeColor;
            try {
              themeColor = Color(int.parse(theme.color));
            } catch (e) {
              themeColor = Colors.blue; // Дефолтный цвет в случае ошибки
            }

            return FilterChip(
              label: Text(
                theme.name,
                style: TextStyle(
                  color:
                      isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                  fontSize: 13, // Чуть меньший размер для компактности
                ),
              ),
              selected: isSelected,
              checkmarkColor: Colors.white,
              selectedColor: themeColor.withOpacity(0.7),
              backgroundColor: themeColor.withOpacity(0.3),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (!_selectedThemeIds.contains(theme.id)) {
                      _selectedThemeIds.add(theme.id);
                      _isSettingsChanged = true; // Отмечаем изменение настроек
                    }
                  } else {
                    _selectedThemeIds.remove(theme.id);
                    _isSettingsChanged = true; // Отмечаем изменение настроек
                  }
                });
              },
            );
          }).toList(),
        );
      },
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
    if (widget.note?.isCompleted ?? false) {
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

  // Переключение между режимами просмотра и редактирования
  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (_isEditMode) {
        _modeTransitionController.forward();

        // При переходе в режим редактирования разрешаем фокус, но не запрашиваем его автоматически
        _contentFocusNode.canRequestFocus = true;

        // Проверяем дату дедлайна при переходе в режим редактирования
        if (_hasDeadline &&
            (_deadlineDate == null ||
                _deadlineDate!.isBefore(DateTime.now()))) {
          _deadlineDate = DateTime.now().add(const Duration(days: 1));
        }
      } else {
        _modeTransitionController.reverse();
      }
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
            _modeTransitionController.reverse();

            // Восстанавливаем исходное содержимое
            if (widget.note != null) {
              _contentController.text = widget.note!.content;
              _hasDeadline = widget.note!.hasDeadline;
              _deadlineDate = widget.note!.deadlineDate;
              _hasDateLink = widget.note!.hasDateLink;
              _linkedDate = widget.note!.linkedDate;
              _selectedThemeIds = List.from(widget.note!.themeIds);
              _emoji = widget.note!.emoji;
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

  Future<void> _saveNote() async {
    // Добавляем индикатор состояния сохранения
    bool isSaving = false;
    setState(() {
      isSaving = true;
    });

    final content = _contentController.text.trim();

    if (content.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Содержимое заметки не может быть пустым')),
      );
      setState(() {
        isSaving = false;
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
        );

        await notesProvider.updateNote(updatedNote);

        // Обновляем состояние только если виджет все еще в дереве
        if (!mounted) return;

        // Переключаемся в режим просмотра
        if (_isEditMode) {
          setState(() {
            _isEditMode = false;
            _modeTransitionController.reverse();
            _isContentChanged = false;
            _isSettingsChanged = false; // Сбрасываем флаг изменений настроек
            isSaving = false;
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
        );

        // После создания новой заметки закрываем экран создания
        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      // Обработка ошибок
      if (!mounted) return;

      setState(() {
        isSaving = false;
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
