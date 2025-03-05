import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../providers/note_links_provider.dart';
import 'package:note_link/widgets/note_link_dialog.dart';
import '../screens/note_detail_screen.dart';
import '../models/note_link.dart';

class MarkdownEditor extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final double? height;

  const MarkdownEditor({
    Key? key,
    required this.controller,
    this.focusNode,
    this.placeholder,
    this.autofocus = false,
    this.onChanged,
    this.readOnly = false,
    this.height,
  }) : super(key: key);

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor>
    with TickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isPreviewMode = false;
  bool _isFocusMode = false;
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Для контекстного меню
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isTextSelected = false;

  // Контроллер анимации для режима фокусировки
  late AnimationController _focusModeController;
  late Animation<double> _focusModeAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _tabController = TabController(length: 2, vsync: this);

    // Добавляем слушатель изменений для контроллера текста
    widget.controller.addListener(_checkTextSelection);

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

        // Скрываем контекстное меню при переключении вкладок
        _removeOverlay();
      });
    });

    // Слушаем фокус для определения режима фокусировки
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _focusNode.removeListener(_handleFocusChange);
    widget.controller.removeListener(_checkTextSelection);
    _tabController.dispose();
    _focusModeController.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _checkTextSelection() {
    // Проверяем, есть ли выделенный текст
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.baseOffset == selection.extentOffset) {
      return;
    }

    final hasSelection = selection.baseOffset != selection.extentOffset;

    if (hasSelection && !_isPreviewMode) {
      _showSelectionOverlay();
      setState(() {
        _isTextSelected = true;
      });
    } else {
      _removeOverlay();
      setState(() {
        _isTextSelected = false;
      });
    }
  }

  void _showSelectionOverlay() {
    // Сначала удаляем старое, если оно есть
    _removeOverlay();

    // Создаем новое всплывающее меню
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: 220, // Фиксированная ширина для меню
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 30), // Показываем меню ниже текста
          child: Material(
            elevation: 4.0,
            borderRadius: BorderRadius.circular(8),
            color: AppColors.cardBackground,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      // Текстовое форматирование
                      _buildFormatButton(
                        icon: Icons.format_bold,
                        tooltip: 'Жирный',
                        onPressed: () =>
                            _formatSelectedText(MarkdownSyntax.bold),
                      ),
                      _buildFormatButton(
                        icon: Icons.format_italic,
                        tooltip: 'Курсив',
                        onPressed: () =>
                            _formatSelectedText(MarkdownSyntax.italic),
                      ),
                      _buildFormatButton(
                        icon: Icons.format_list_bulleted,
                        tooltip: 'Маркированный список',
                        onPressed: () =>
                            _formatSelectedText(MarkdownSyntax.bulletList),
                      ),
                      _buildFormatButton(
                        icon: Icons.format_list_numbered,
                        tooltip: 'Нумерованный список',
                        onPressed: () =>
                            _formatSelectedText(MarkdownSyntax.numberedList),
                      ),
                      _buildFormatButton(
                        icon: Icons.format_quote,
                        tooltip: 'Цитата',
                        onPressed: () =>
                            _formatSelectedText(MarkdownSyntax.quote),
                      ),
                      _buildFormatButton(
                        icon: Icons.code,
                        tooltip: 'Код',
                        onPressed: () =>
                            _formatSelectedText(MarkdownSyntax.inlineCode),
                      ),
                      _buildFormatButton(
                        icon: Icons.link,
                        tooltip: 'Ссылка',
                        onPressed: _createNoteLink,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Кнопки для копирования и вырезания
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.content_cut, size: 20),
                        tooltip: 'Вырезать',
                        onPressed: () {
                          final selection = widget.controller.selection;
                          if (selection.isValid &&
                              selection.baseOffset != selection.extentOffset) {
                            final text = widget.controller.text;
                            final selectedText = text.substring(
                                selection.baseOffset, selection.extentOffset);
                            Clipboard.setData(
                                ClipboardData(text: selectedText));

                            final newText = text.replaceRange(
                                selection.baseOffset,
                                selection.extentOffset,
                                '');
                            widget.controller.value = TextEditingValue(
                              text: newText,
                              selection: TextSelection.collapsed(
                                  offset: selection.baseOffset),
                            );

                            if (widget.onChanged != null) {
                              widget.onChanged!(newText);
                            }

                            _removeOverlay();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.content_copy, size: 20),
                        tooltip: 'Копировать',
                        onPressed: () {
                          final selection = widget.controller.selection;
                          if (selection.isValid &&
                              selection.baseOffset != selection.extentOffset) {
                            final text = widget.controller.text;
                            final selectedText = text.substring(
                                selection.baseOffset, selection.extentOffset);
                            Clipboard.setData(
                                ClipboardData(text: selectedText));
                            _removeOverlay();
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.select_all, size: 20),
                        tooltip: 'Выделить всё',
                        onPressed: () {
                          widget.controller.selection = TextSelection(
                            baseOffset: 0,
                            extentOffset: widget.controller.text.length,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Добавляем меню в наложение
    Overlay.of(context)?.insert(_overlayEntry!);
  }

  // Удалить контекстное меню
  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // Кнопки форматирования для контекстного меню
  Widget _buildFormatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () {
          onPressed();
          _removeOverlay();
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: 20,
            color: AppColors.textOnDark,
          ),
        ),
      ),
    );
  }

  // Форматирование выделенного текста
  void _formatSelectedText(String markdownSyntax) {
    final selection = widget.controller.selection;
    if (!selection.isValid || selection.baseOffset == selection.extentOffset)
      return;

    _insertMarkdown(markdownSyntax, surroundSelection: true);
  }

  void _handleFocusChange() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    // Активируем режим фокусировки только если фокус на редакторе и включена опция в настройках
    if (_focusNode.hasFocus && appProvider.enableFocusMode && !_isPreviewMode) {
      _setFocusMode(true);
    } else {
      _setFocusMode(false);
    }

    // Если теряем фокус, скрываем контекстное меню
    if (!_focusNode.hasFocus) {
      _removeOverlay();
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
        int lineStart = start;
        while (lineStart > 0 && value.text[lineStart - 1] != '\n') {
          lineStart--;
        }

        // Вставляем синтаксис в начало строки
        newText = value.text.replaceRange(lineStart, lineStart, markdownSyntax);
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

  // Создание ссылки на другую заметку
  void _createNoteLink() async {
    _removeOverlay(); // Скрываем меню при создании ссылки

    // Получаем ID текущей заметки
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final currentNoteId = _getCurrentNoteId(notesProvider);

    if (currentNoteId == null) {
      // Если ID текущей заметки не удалось определить, показываем сообщение
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Заметка должна быть сохранена, прежде чем создавать связи')),
      );
      return;
    }

    // Показываем диалог выбора заметки
    final selectedNote = await NoteLinkDialog.show(context, currentNoteId);

    // Если заметка не выбрана, прерываем выполнение
    if (selectedNote == null) return;

    // Вставляем ссылку на заметку в текст
    _insertNoteLinkInText(selectedNote);

    // Создаем прямую связь между заметками
    final linksProvider =
        Provider.of<NoteLinksProvider>(context, listen: false);
    await linksProvider.createLink(
      sourceNoteId: currentNoteId,
      targetNoteId: selectedNote.id,
      linkType: LinkType.direct,
    );
  }

  // Получение ID текущей заметки
  String? _getCurrentNoteId(NotesProvider notesProvider) {
    // Ищем заметку по её содержимому
    // Это временное решение, лучше передавать ID заметки в конструктор
    final content = widget.controller.text;
    final matchingNotes =
        notesProvider.notes.where((note) => note.content == content).toList();

    if (matchingNotes.isNotEmpty) {
      // Берем самую последнюю заметку, если есть несколько с таким содержимым
      return matchingNotes.last.id;
    }

    return null;
  }

  // Вставка ссылки на заметку в текст
  void _insertNoteLinkInText(Note note) {
    // Сохраняем текущую позицию курсора
    final TextEditingValue value = widget.controller.value;
    final int start = value.selection.baseOffset;
    final int end = value.selection.extentOffset;

    if (start < 0) return; // Защита от некорректных значений

    // Создаем текст ссылки
    final preview = note.content.length > 20
        ? '${note.content.substring(0, 20).trim()}...'
        : note.content.trim();

    // Формат ссылки: [[ID заметки:Превью текста]]
    final linkText = '[[${note.id}:$preview]]';

    // Вставляем ссылку в текст
    final newText = value.text.replaceRange(start, end, linkText);

    // Устанавливаем новый текст и позицию курсора
    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + linkText.length),
    );

    // Вызываем колбэк, если он определен
    if (widget.onChanged != null) {
      widget.onChanged!(newText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final bool markdownEnabled = appProvider.enableMarkdownFormatting;

    return AnimatedBuilder(
      animation: _focusModeAnimation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.textBackground,
            borderRadius: BorderRadius.circular(AppDimens.buttonBorderRadius),
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
                        borderRadius:
                            BorderRadius.circular(AppDimens.buttonBorderRadius),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black
                                .withOpacity(0.7 * _focusModeAnimation.value),
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
                          // Панель инструментов форматирования
                          // Панель инструментов для работы с медиа (бывшая красная область)
                          if (!_isPreviewMode)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: [
                                    // Кнопки для работы с медиа
                                    IconButton(
                                      icon: const Icon(Icons.image),
                                      tooltip: 'Добавить изображение',
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Добавление изображений будет доступно в следующей версии'),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.mic),
                                      tooltip: 'Записать голосовое сообщение',
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Голосовые записи будут доступны в следующей версии'),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.attach_file),
                                      tooltip: 'Прикрепить файл',
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Прикрепление файлов будет доступно в следующей версии'),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.camera_alt),
                                      tooltip: 'Сделать фото',
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Съемка фото будет доступна в следующей версии'),
                                          ),
                                        );
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.videocam),
                                      tooltip: 'Записать видео',
                                      onPressed: () {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                                'Запись видео будет доступна в следующей версии'),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  // Содержимое вкладок
                  Container(
                    height: widget.height ?? 300,
                    constraints: BoxConstraints(
                      minHeight: 100,
                      maxHeight: widget.height ?? 500,
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
        );
      },
    );
  }

  // Построение редактора
  Widget _buildEditor() {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
          // Отключаем стандартное контекстное меню, чтобы использовать свое
          enableInteractiveSelection: true,
          contextMenuBuilder: (context, editableTextState) {
            // Возвращаем пустой контейнер, чтобы отключить стандартное меню
            return Container();
          },
        ),
      ),
    );
  }

  Widget _buildPreview() {
    // Получаем текст с заменой ссылок на заметки
    final processedText = _processNoteLinks(widget.controller.text);

    return Container(
      color: AppColors.textBackground,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: processedText.isEmpty
            ? Center(
                child: Text(
                  'Начните вводить текст для предпросмотра',
                  style: TextStyle(
                    color: AppColors.textOnLight.withOpacity(0.6),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              )
            : MarkdownBody(
                data: processedText,
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
                    if (href.startsWith('notelink:')) {
                      // Обработка ссылки на заметку
                      final noteId = href.substring(9); // Удаляем "notelink:"
                      _openNoteById(noteId);
                    } else {
                      // Обычная внешняя ссылка
                      launchUrl(Uri.parse(href));
                    }
                  }
                },
              ),
      ),
    );
  }

  // Обработка ссылок на заметки в тексте
  String _processNoteLinks(String text) {
    // Ищем все ссылки на заметки в формате [[ID:Превью]]
    final noteLinkRegex = RegExp(r'\[\[(.*?):(.*?)\]\]');

    // Заменяем их на Markdown-ссылки
    return text.replaceAllMapped(noteLinkRegex, (match) {
      final noteId = match.group(1);
      final preview = match.group(2);
      return '[$preview](notelink:$noteId)';
    });
  }

  // Открытие заметки по ID
  void _openNoteById(String noteId) {
    // Получаем провайдер заметок
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);

    // Ищем заметку по ID
    final note = notesProvider.notes.firstWhere(
      (note) => note.id == noteId,
      orElse: () => Note(
        id: '',
        content: 'Заметка не найдена',
        themeIds: [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        hasDeadline: false,
        hasDateLink: false,
        isCompleted: false,
        mediaUrls: [],
      ),
    );

    if (note.id.isEmpty) {
      // Если заметка не найдена, показываем сообщение
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заметка не найдена')),
      );
      return;
    }

    // Открываем заметку
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NoteDetailScreen(note: note),
      ),
    );
  }
}
