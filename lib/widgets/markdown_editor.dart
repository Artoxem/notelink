import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import '../services/voice_note_recorder.dart';
import '../widgets/voice_record_button.dart';
import '../widgets/voice_note_player.dart';
import '../services/media_service.dart';

class MarkdownEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final double? height;
  final Function(String mediaPath)? onMediaAdded;

  const MarkdownEditor({
    Key? key,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.autofocus = false,
    this.onChanged,
    this.readOnly = false,
    this.height,
    this.onMediaAdded,
  }) : super(key: key);

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor>
    with TickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isPreviewMode = false;
  bool _isFocusMode = false;
  bool _isLoading = false;
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Контроллер анимации для режима фокусировки
  late AnimationController _focusModeController;
  late Animation<double> _focusModeAnimation;

  // Регулярные выражения для определения типа списка
  final RegExp _bulletListRegex = RegExp(r'^\s*[-*+]\s+');
  final RegExp _numberedListRegex = RegExp(r'^\s*(\d+)\.\s+');

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _tabController = TabController(length: 2, vsync: this);

    // Инициализация контроллера анимации
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

    // Слушаем фокус для определения режима фокусировки
    _focusNode.addListener(_handleFocusChange);

    // Добавляем обработчик клавиш для поддержки автоматического продолжения списков
    widget.controller.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _focusNode.removeListener(_handleFocusChange);
    _tabController.dispose();
    _focusModeController.dispose();

    // Удаляем обработчик при удалении виджета
    widget.controller.removeListener(_handleTextChange);

    super.dispose();
  }

  void _handleTextChange() {
    // Наблюдаем за изменениями, но не делаем ничего дополнительного здесь
    // Все обработки списков мы делаем по нажатию клавиш в методе _handleKeyEvent
  }

  // Функция для обработки нажатий клавиш в текстовом поле
  bool _handleKeyEvent(RawKeyEvent event) {
    // Обрабатываем только нажатия клавиши Enter и Backspace
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.enter) {
        final TextEditingValue value = widget.controller.value;
        final String text = value.text;
        final int cursorPosition = value.selection.baseOffset;

        // Если курсор не находится в правильной позиции, выходим
        if (cursorPosition < 0 || cursorPosition > text.length) {
          return false;
        }

        // Определяем текущую строку до курсора
        final String textBeforeCursor = text.substring(0, cursorPosition);
        final int lineStartOffset = textBeforeCursor.lastIndexOf('\n') + 1;
        final String currentLine = textBeforeCursor.substring(lineStartOffset);

        // Проверяем, находимся ли мы в нумерованном списке
        final numberedMatch = _numberedListRegex.firstMatch(currentLine);
        if (numberedMatch != null) {
          // Получаем текущий номер и увеличиваем его
          final int currentNumber = int.parse(numberedMatch.group(1)!);

          // Если строка содержит только маркер списка без текста, удаляем маркер
          if (currentLine.trim() == '$currentNumber. ') {
            final newText =
                text.replaceRange(lineStartOffset, cursorPosition, '');
            widget.controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: lineStartOffset),
            );
            return true;
          }

          // Иначе создаем новый элемент списка
          final nextNumber = currentNumber + 1;
          final injectedText = '\n$nextNumber. ';

          // Вставляем текст и перемещаем курсор после нового маркера
          final String newText =
              text.replaceRange(cursorPosition, cursorPosition, injectedText);
          // Рассчитываем новое положение курсора после маркера
          final int newCursorPosition = cursorPosition + injectedText.length;

          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCursorPosition),
          );

          if (widget.onChanged != null) {
            widget.onChanged!(newText);
          }

          return true;
        }

        // Проверяем, находимся ли мы в маркированном списке
        final bulletMatch = _bulletListRegex.firstMatch(currentLine);
        if (bulletMatch != null) {
          // Получаем используемый маркер (-, *, +)
          final String marker = currentLine.trim()[0];

          // Если строка содержит только маркер списка без текста, удаляем маркер
          if (currentLine.trim() == '$marker ') {
            final newText =
                text.replaceRange(lineStartOffset, cursorPosition, '');
            widget.controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: lineStartOffset),
            );
            return true;
          }

          // Иначе создаем новый элемент списка
          final injectedText = '\n$marker ';

          // Вставляем текст и перемещаем курсор после нового маркера
          final String newText =
              text.replaceRange(cursorPosition, cursorPosition, injectedText);
          // Рассчитываем новое положение курсора после маркера
          final int newCursorPosition = cursorPosition + injectedText.length;

          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCursorPosition),
          );

          if (widget.onChanged != null) {
            widget.onChanged!(newText);
          }

          return true;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.backspace) {
        // Можно добавить логику для удаления маркера, если пользователь
        // нажимает Backspace в начале пустого пункта списка
        final TextEditingValue value = widget.controller.value;
        final String text = value.text;
        final int cursorPosition = value.selection.baseOffset;

        // Если курсор не находится в правильной позиции или находится в начале текста, выходим
        if (cursorPosition <= 0 || cursorPosition > text.length) {
          return false;
        }

        // Определяем текущую строку до курсора
        final String textBeforeCursor = text.substring(0, cursorPosition);
        final int lineStartOffset = textBeforeCursor.lastIndexOf('\n') + 1;
        final String currentLine = textBeforeCursor.substring(lineStartOffset);

        // Проверяем, находимся ли мы в конце маркера списка (нумерованного или маркированного)
        final bool isAtBulletEnd = _bulletListRegex.hasMatch(currentLine) &&
            currentLine.trim().length == 2;
        final bool isAtNumberedEnd = _numberedListRegex.hasMatch(currentLine);

        if (isAtNumberedEnd) {
          final match = _numberedListRegex.firstMatch(currentLine);
          final String fullMatch = match!.group(0)!;
          if (currentLine.length == fullMatch.length) {
            // Если курсор находится сразу после маркера списка, удаляем всю строку
            final newText =
                text.replaceRange(lineStartOffset, cursorPosition, '');
            widget.controller.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: lineStartOffset),
            );
            return true;
          }
        }

        if (isAtBulletEnd) {
          // Если курсор находится сразу после маркера списка, удаляем всю строку
          final newText =
              text.replaceRange(lineStartOffset, cursorPosition, '');
          widget.controller.value = TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: lineStartOffset),
          );
          return true;
        }
      }
    }

    return false;
  }

  // Функция для вставки текста в текущую позицию курсора
  void _insertText(String textToInsert) {
    final TextEditingValue value = widget.controller.value;
    final int start = value.selection.baseOffset;

    if (start < 0) return;

    final String newText = value.text.replaceRange(start, start, textToInsert);

    // Определяем позицию курсора для маркеров списков
    int cursorPosition = start + textToInsert.length;

    // Для списков перемещаем курсор сразу после маркера
    if (_bulletListRegex.hasMatch(textToInsert.trim()) ||
        _numberedListRegex.hasMatch(textToInsert.trim())) {
      // Найдем позицию пробела после маркера списка
      final match = textToInsert.indexOf(' ', textToInsert.indexOf('\n') + 1);
      if (match > 0) {
        cursorPosition = start + match + 1;
      }
    }

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursorPosition),
    );

    if (widget.onChanged != null) {
      widget.onChanged!(newText);
    }
  }

  void _handleFocusChange() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    // Активируем режим фокусировки только если фокус на редакторе и включена опция в настройках
    if (_focusNode.hasFocus && appProvider.enableFocusMode && !_isPreviewMode) {
      _setFocusMode(true);
    } else {
      _setFocusMode(false);
    }
  }

  void _setFocusMode(bool enabled) {
    if (_isFocusMode != enabled) {
      setState(() {
        _isFocusMode = enabled;
      });

      if (enabled) {
        _focusModeController.forward();
        // Запрашиваем фокус при активации режима
        if (!_focusNode.hasFocus) {
          _focusNode.requestFocus();
        }
      } else {
        _focusModeController.reverse();
      }
    }
  }

  void _showImagePickerOptions(BuildContext context) {
    // Предотвращаем множественные вызовы
    if (_isLoading) return;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.camera_alt,
                    color: AppColors.accentSecondary),
                title: const Text('Сделать фото'),
                onTap: () async {
                  // Закрываем модальное окно перед началом операции
                  Navigator.pop(context);

                  final MediaService mediaService = MediaService();
                  final imagePath = await mediaService.pickImageFromCamera();

                  // Проверяем, что виджет все еще монтирован
                  if (imagePath != null &&
                      widget.onMediaAdded != null &&
                      mounted) {
                    widget.onMediaAdded!(imagePath);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library,
                    color: AppColors.accentSecondary),
                title: const Text('Выбрать из галереи'),
                onTap: () async {
                  // Закрываем модальное окно перед началом операции
                  Navigator.pop(context);

                  final MediaService mediaService = MediaService();
                  final imagePath = await mediaService.pickImageFromGallery();

                  // Проверяем, что виджет все еще монтирован
                  if (imagePath != null &&
                      widget.onMediaAdded != null &&
                      mounted) {
                    widget.onMediaAdded!(imagePath);
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

  void _pickFile() async {
    // Предотвращаем множественные вызовы
    if (_isLoading) return;

    final MediaService mediaService = MediaService();
    final filePath = await mediaService.pickFile();

    // Проверяем, что виджет все еще монтирован
    if (filePath != null && widget.onMediaAdded != null && mounted) {
      widget.onMediaAdded!(filePath);
    }
  }

  // Вставка голосовой заметки в текст
  void _insertVoiceNote(String audioPath) {
    final TextEditingValue value = widget.controller.value;
    final int start = value.selection.baseOffset;

    if (start < 0) return; // Защита от некорректных значений

    // Формат вставки: ![voice](voice:id)
    final String voiceMarkup = ' ![voice](voice:$audioPath) ';

    // Вставляем метку голосового сообщения в текст
    final String newText = value.text.replaceRange(start, start, voiceMarkup);

    // Обновляем текст и позицию курсора
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + voiceMarkup.length),
    );

    // Вызываем колбэк, если он определен
    if (widget.onChanged != null) {
      widget.onChanged!(newText);
    }
  }

  // Вставка Markdown-синтаксиса
  void _insertMarkdown(String markdownSyntax, {bool surroundSelection = true}) {
    // Сохраняем текущую позицию и выделение
    final TextEditingValue value = widget.controller.value;
    final int start = value.selection.baseOffset;
    final int end = value.selection.extentOffset;

    if (start < 0 || end < 0) return; // Защита от некорректных значений

    String newText;
    TextSelection newSelection;

    if (surroundSelection && start != end) {
      // Обрамляем выделенный текст синтаксисом Markdown
      final String selectedText = value.text.substring(start, end);
      if (markdownSyntax == MarkdownSyntax.bulletList ||
          markdownSyntax == MarkdownSyntax.numberedList) {
        // Для списков добавляем синтаксис в начало каждой строки
        final lines = selectedText.split('\n');
        final newLines = lines.map((line) => '$markdownSyntax$line').join('\n');
        newText = value.text.replaceRange(start, end, newLines);
        newSelection = TextSelection.collapsed(offset: start + newLines.length);
      } else {
        // Для остальных элементов обрамляем текст
        newText = value.text.replaceRange(
            start, end, '$markdownSyntax$selectedText$markdownSyntax');
        newSelection =
            TextSelection.collapsed(offset: end + markdownSyntax.length * 2);
      }
    } else {
      // Вставляем синтаксис Markdown на текущую позицию
      if (markdownSyntax == MarkdownSyntax.bulletList ||
          markdownSyntax == MarkdownSyntax.numberedList) {
        newText = value.text.replaceRange(start, end, markdownSyntax);
        newSelection =
            TextSelection.collapsed(offset: start + markdownSyntax.length);
      } else if (markdownSyntax.startsWith(MarkdownSyntax.heading1) ||
          markdownSyntax.startsWith(MarkdownSyntax.heading2) ||
          markdownSyntax.startsWith(MarkdownSyntax.heading3) ||
          markdownSyntax.startsWith(MarkdownSyntax.quote)) {
        // Для элементов, которые добавляются в начало строки
        // Находим начало текущей строки
        int lineStartOffset = start;
        while (lineStartOffset > 0 && value.text[lineStartOffset - 1] != '\n') {
          lineStartOffset--;
        }

        // Вставляем синтаксис в начало строки
        newText = value.text
            .replaceRange(lineStartOffset, lineStartOffset, markdownSyntax);
        newSelection =
            TextSelection.collapsed(offset: start + markdownSyntax.length);
      } else {
        // Для остальных элементов (жирный, курсив и т.д.)
        newText = value.text
            .replaceRange(start, end, '$markdownSyntax$markdownSyntax');
        newSelection =
            TextSelection.collapsed(offset: start + markdownSyntax.length);
      }
    }

    // Устанавливаем новый текст и позицию курсора
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );

    // Вызываем колбэк, если он определен
    if (widget.onChanged != null) {
      widget.onChanged!(newText);
    }
  }

  // Методы для копирования и вырезания текста
  void _cutSelectedText() {
    final selection = widget.controller.selection;
    if (selection.isValid && selection.baseOffset != selection.extentOffset) {
      final text = widget.controller.text;
      final selectedText =
          text.substring(selection.baseOffset, selection.extentOffset);
      Clipboard.setData(ClipboardData(text: selectedText));

      final newText =
          text.replaceRange(selection.baseOffset, selection.extentOffset, '');
      widget.controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.baseOffset),
      );

      if (widget.onChanged != null) {
        widget.onChanged!(newText);
      }
    }
  }

  void _copySelectedText() {
    final selection = widget.controller.selection;
    if (selection.isValid && selection.baseOffset != selection.extentOffset) {
      final text = widget.controller.text;
      final selectedText =
          text.substring(selection.baseOffset, selection.extentOffset);
      Clipboard.setData(ClipboardData(text: selectedText));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final bool markdownEnabled = appProvider.enableMarkdownFormatting;

    return AnimatedBuilder(
      animation: _focusModeAnimation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Основное содержимое - редактор
            Container(
              decoration: BoxDecoration(
                color: AppColors.textBackground,
                borderRadius:
                    BorderRadius.circular(AppDimens.buttonBorderRadius),
                boxShadow: [_isFocusMode ? AppShadows.large : AppShadows.small],
              ),
              child: Stack(
                children: [
                  // Затемнение для режима фокусировки
                  if (_isFocusMode)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                                AppDimens.buttonBorderRadius),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                    0.7 * _focusModeAnimation.value),
                                blurRadius: 15,
                                spreadRadius: 10,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Основное содержимое
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Вкладки редактор/предпросмотр и кнопки форматирования
                      if (markdownEnabled && !widget.readOnly)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.only(
                              topLeft:
                                  Radius.circular(AppDimens.buttonBorderRadius),
                              topRight:
                                  Radius.circular(AppDimens.buttonBorderRadius),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TabBar(
                                controller: _tabController,
                                labelColor: AppColors.accentSecondary,
                                unselectedLabelColor:
                                    AppColors.textOnDark.withOpacity(0.7),
                                indicatorColor: AppColors.accentSecondary,
                                indicatorSize: TabBarIndicatorSize.label,
                                tabs: const [
                                  Tab(text: 'Редактор'),
                                  Tab(text: 'Предпросмотр'),
                                ],
                              ),
                              // Обновленная панель для кнопок прикрепления файлов
                              if (!_isPreviewMode)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      // Иконка для прикрепления фото (без стиля кнопки)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () {
                                          _showImagePickerOptions(context);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: AppColors.textOnDark,
                                            size: 20,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(width: 12),

                                      // Иконка для прикрепления файла (без стиля кнопки)
                                      InkWell(
                                        borderRadius: BorderRadius.circular(18),
                                        onTap: () {
                                          _pickFile();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.attachment_outlined,
                                            color: AppColors.textOnDark,
                                            size: 20,
                                          ),
                                        ),
                                      ),

                                      const Spacer(),

                                      // Кнопка голосовой записи
                                      VoiceRecordButton(
                                        size: 36, // Уменьшен размер с 44
                                        onRecordComplete: (audioPath) {
                                          _insertVoiceNote(audioPath);
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                      // Содержимое вкладок
                      Container(
                        height:
                            widget.height ?? 250, // Уменьшаем высоту редактора
                        constraints: BoxConstraints(
                          minHeight: 150,
                          maxHeight: widget.height ??
                              400, // Уменьшаем максимальную высоту
                        ),
                        child: markdownEnabled
                            ? TabBarView(
                                controller: _tabController,
                                physics: widget.readOnly
                                    ? const NeverScrollableScrollPhysics()
                                    : null,
                                children: [
                                  // Вкладка редактирования
                                  _buildEditor(),

                                  // Вкладка предпросмотра
                                  _buildPreview(),
                                ],
                              )
                            : _buildEditor(),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Отдельный блок для панели форматирования
            const SizedBox(height: 8), // Расстояние между блоками
            if (!_isPreviewMode && markdownEnabled)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius:
                      BorderRadius.circular(AppDimens.buttonBorderRadius),
                  boxShadow: [AppShadows.small],
                ),
                child: _buildFormattingToolbarAsBlock(),
              ),
          ],
        );
      },
    );
  }

  // Построение редактора
  Widget _buildEditor() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: RawKeyboardListener(
        // Добавляем обертку для отслеживания нажатий клавиш
        focusNode: FocusNode(),
        onKey: _handleKeyEvent,
        child: TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: AppTextStyles.bodyMediumLight,
          decoration: InputDecoration(
            hintText: widget.placeholder ?? 'Введите текст...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
          keyboardType: TextInputType.multiline,
          maxLines: null,
          expands: true,
          autofocus: widget.autofocus || _isFocusMode,
          readOnly: widget.readOnly,
          onChanged: widget.onChanged,
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return Container(
      color: AppColors.textBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: widget.controller.text.isEmpty
            ? Center(
                child: Text(
                  'Начните вводить текст для предпросмотра',
                  style: TextStyle(
                    color: AppColors.textOnLight.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : _buildMarkdownWithVoiceNotes(widget.controller.text),
      ),
    );
  }

  // Форматирование как отдельный блок
  Widget _buildFormattingToolbarAsBlock() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildToolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Жирный',
              onPressed: () => _insertMarkdown(MarkdownSyntax.bold),
            ),
            _buildToolbarButton(
              icon: Icons.format_italic,
              tooltip: 'Курсив',
              onPressed: () => _insertMarkdown(MarkdownSyntax.italic),
            ),
            _buildToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: 'Список',
              onPressed: () => _insertMarkdown(MarkdownSyntax.bulletList),
            ),
            _buildToolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: 'Нумерованный',
              onPressed: () => _insertMarkdown(MarkdownSyntax.numberedList),
            ),
            _buildDivider(),
            _buildToolbarButton(
              icon: Icons.format_quote,
              tooltip: 'Цитата',
              onPressed: () => _insertMarkdown(MarkdownSyntax.quote),
            ),
            _buildToolbarButton(
              icon: Icons.code,
              tooltip: 'Код',
              onPressed: () => _insertMarkdown(MarkdownSyntax.inlineCode),
            ),
            _buildDivider(),
            _buildToolbarButton(
              icon: Icons.title,
              tooltip: 'Заголовок',
              onPressed: () => _insertMarkdown(MarkdownSyntax.heading2),
            ),
            _buildDivider(),
            _buildToolbarButton(
              icon: Icons.content_cut,
              tooltip: 'Вырезать',
              onPressed: _cutSelectedText,
            ),
            _buildToolbarButton(
              icon: Icons.content_copy,
              tooltip: 'Копировать',
              onPressed: _copySelectedText,
            ),
          ],
        ),
      ),
    );
  }

  // Разделитель для панели инструментов
  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6), // Уменьшен с 8 до 6
      width: 1,
      height: 20, // Уменьшен с 24 до 20
      color: AppColors.secondary.withOpacity(0.3),
    );
  }

  // Кнопка для панели инструментов форматирования
  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(6), // Уменьшен радиус с 8 до 6
        child: InkWell(
          borderRadius: BorderRadius.circular(6), // Уменьшен радиус с 8 до 6
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(6.0), // Уменьшены отступы с 8 до 6
            child: Icon(
              icon,
              size: 20, // Уменьшен размер иконок с 22 до 20
              color: AppColors.textOnDark,
            ),
          ),
        ),
      ),
    );
  }

  // Метод для отображения markdown с голосовыми сообщениями
  Widget _buildMarkdownWithVoiceNotes(String content) {
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
}
