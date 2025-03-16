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
  bool _showFormattingToolbar = true;

  // Контроллер анимации для режима фокусировки
  late AnimationController _focusModeController;
  late Animation<double> _focusModeAnimation;

  // Контроллер анимации для панели форматирования
  late AnimationController _toolbarController;
  late Animation<double> _toolbarAnimation;

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

    // Инициализация контроллера для панели форматирования
    _toolbarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _toolbarAnimation = CurvedAnimation(
      parent: _toolbarController,
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
  }

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    _focusNode.removeListener(_handleFocusChange);
    _tabController.dispose();
    _focusModeController.dispose();
    _toolbarController.dispose();
    super.dispose();
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

  // Переключение отображения панели форматирования
  void _toggleFormattingToolbar() {
    setState(() {
      _showFormattingToolbar = !_showFormattingToolbar;
      if (_showFormattingToolbar) {
        _toolbarController.forward();
      } else {
        _toolbarController.reverse();
      }
    });
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
                          // Обновленная панель инструментов для работы с медиа
                          if (!_isPreviewMode)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  // Кнопка для прикрепления изображений
                                  Material(
                                    color: Colors.transparent,
                                    child: Tooltip(
                                      message: 'Добавить изображение',
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          _showImagePickerOptions(context);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.add_photo_alternate_outlined,
                                            color: AppColors.textOnDark,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Кнопка для прикрепления файла
                                  Material(
                                    color: Colors.transparent,
                                    child: Tooltip(
                                      message: 'Добавить файл',
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: () {
                                          _pickFile();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            Icons.attachment_outlined,
                                            color: AppColors.textOnDark,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Кнопка для форматирования текста
                                  Material(
                                    color: Colors.transparent,
                                    child: Tooltip(
                                      message: _showFormattingToolbar
                                          ? 'Скрыть форматирование'
                                          : 'Показать форматирование',
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(8),
                                        onTap: _toggleFormattingToolbar,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8.0),
                                          child: Icon(
                                            _showFormattingToolbar
                                                ? Icons.text_format
                                                : Icons.text_format_outlined,
                                            color: AppColors.textOnDark,
                                            size: 22,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Расширитель для создания пространства между группами кнопок
                                  Expanded(child: Container()),

                                  // Кнопка голосовой записи
                                  VoiceRecordButton(
                                    size: 40,
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

              // Панель форматирования, которая появляется снизу редактора
              if (!_isPreviewMode && markdownEnabled && _showFormattingToolbar)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 1),
                      end: Offset.zero,
                    ).animate(_toolbarAnimation),
                    child: _buildBottomFormattingToolbar(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // Построение редактора
  Widget _buildEditor() {
    return Padding(
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

  // Обновленная панель форматирования, выезжающая снизу
  Widget _buildBottomFormattingToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppDimens.buttonBorderRadius),
          bottomRight: Radius.circular(AppDimens.buttonBorderRadius),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.2),
          width: 0.5,
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
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
              tooltip: 'Маркированный список',
              onPressed: () => _insertMarkdown(MarkdownSyntax.bulletList),
            ),
            _buildToolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: 'Нумерованный список',
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
      margin: const EdgeInsets.symmetric(horizontal: 8),
      width: 1,
      height: 24,
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
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              size: 22,
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

      // Добавляем виджет голосового сообщения
      final voiceNoteId = match.group(1);
      if (voiceNoteId != null) {
        contentWidgets.add(
          VoiceNotePlayer(
            audioPath: voiceNoteId,
            maxWidth: 280,
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
