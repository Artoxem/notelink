import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart' as quill_delta;
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';
import '../services/media_service.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'voice_record_button.dart';
import 'package:provider/provider.dart';

/// Виджет-обёртка для Flutter Quill с расширенным функционалом
class QuillEditorWrapper extends StatefulWidget {
  /// Контроллер текста для синхронизации с внешним состоянием
  final TextEditingController controller;

  /// Узел фокуса для редактора
  final FocusNode? focusNode;

  /// Текст-заполнитель при пустом редакторе
  final String? placeholder;

  /// Автоматическая фокусировка при создании
  final bool autofocus;

  /// Обратный вызов при изменении содержимого
  final ValueChanged<String>? onChanged;

  /// Режим только для чтения
  final bool readOnly;

  /// Высота редактора
  final double? height;

  /// Обратный вызов при добавлении медиафайла
  final Function(String mediaPath)? onMediaAdded;

  const QuillEditorWrapper({
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
  State<QuillEditorWrapper> createState() => QuillEditorWrapperState();
}

class QuillEditorWrapperState extends State<QuillEditorWrapper>
    with TickerProviderStateMixin {
  /// Контроллер Quill для управления редактором
  late QuillController _quillController;

  /// Узел фокуса
  late FocusNode _focusNode;

  /// Флаг режима фокусировки
  bool _isFocusMode = false;

  /// Флаг загрузки
  bool _isLoading = false;

  /// Флаг инициализации
  bool _isInitialized = false;

  /// Подписка на изменения документа
  StreamSubscription? _documentChangesSubscription;

  /// Контроллер анимации для режима фокусировки
  late AnimationController _focusModeController;

  /// Анимация режима фокусировки
  late Animation<double> _focusModeAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();

    // Инициализируем контроллер Quill с базовым документом
    _quillController = QuillController.basic();

    // Добавляем слушатель фокуса для эффектов UI
    _focusNode.addListener(_handleFocusChange);

    // Инициализируем редактор с данными из контроллера
    _initQuillEditor();

    // Инициализация контроллера анимации
    _focusModeController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _focusModeAnimation = CurvedAnimation(
      parent: _focusModeController,
      curve: Curves.easeInOut,
    );
  }

  /// Метод для доступа к контроллеру извне
  QuillController getQuillController() {
    return _quillController;
  }

  /// Инициализация редактора с данными из TextEditingController
  Future<void> _initQuillEditor() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final jsonText = widget.controller.text;

      if (jsonText.isNotEmpty) {
        try {
          // Попытка декодировать JSON
          final dynamic decodedJson = json.decode(jsonText);

          // Обработка разных форматов Delta JSON
          if (decodedJson is Map<String, dynamic> &&
              decodedJson.containsKey('ops')) {
            // Стандартный формат с 'ops'
            final deltaJson = decodedJson['ops'] as List;
            final delta = Delta.fromJson(deltaJson);
            _quillController = QuillController(
              document: Document.fromDelta(delta),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } else if (decodedJson is List) {
            // Список операций без обертки 'ops'
            final delta = Delta.fromJson(decodedJson as List);
            _quillController = QuillController(
              document: Document.fromDelta(delta),
              selection: const TextSelection.collapsed(offset: 0),
            );
          } else {
            // Неизвестный формат - оставляем пустой контроллер
            if (decodedJson is String) {
              _quillController.document.insert(0, decodedJson);
            }
          }
        } catch (e) {
          debugPrint('Ошибка при создании документа из JSON: $e');

          // Пытаемся интерпретировать как текст, если не похож на JSON
          if (!jsonText.contains('{') && !jsonText.contains('[')) {
            _quillController.document.insert(0, jsonText);
            debugPrint('Создан документ из текста');
          }
        }
      } else {
        // Если текст пустой, оставляем пустой документ
        debugPrint('Инициализация пустого редактора, текст контроллера пуст');
      }

      // Настраиваем слушатель изменений
      _setupDocumentListener();

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Ошибка инициализации QuillEditor: $e');
      _setupDocumentListener();

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    }
  }

  /// Настройка слушателя изменений документа
  void _setupDocumentListener() {
    // Отменяем предыдущую подписку, если она была
    _documentChangesSubscription?.cancel();

    // Слушаем изменения в документе и обновляем контроллер текста
    _documentChangesSubscription = _quillController.document.changes.listen((
      event,
    ) {
      try {
        // Получаем Delta в формате JSON
        final delta = _quillController.document.toDelta();

        // Преобразуем в JSON строку
        final deltaJson = jsonEncode({'ops': delta.toJson()});

        // Обновляем текстовый контроллер только если изменилось содержимое
        if (widget.controller.text != deltaJson) {
          debugPrint('Обновление контроллера текста с JSON Delta');
          widget.controller.text = deltaJson;

          if (widget.onChanged != null) {
            widget.onChanged!(deltaJson);
          }
        }
      } catch (e) {
        debugPrint('Ошибка при сохранении delta: $e');

        // В случае ошибки создаем минимальную валидную Delta
        try {
          final plainText = _quillController.document.toPlainText();
          final ops = [
            {'insert': plainText.isEmpty ? '\n' : plainText},
          ];
          final safeJson = jsonEncode({'ops': ops});

          if (widget.controller.text != safeJson) {
            widget.controller.text = safeJson;

            if (widget.onChanged != null) {
              widget.onChanged!(safeJson);
            }
          }
        } catch (backupError) {
          debugPrint('Не удалось создать резервную delta: $backupError');
        }
      }
    });
  }

  @override
  void dispose() {
    // Очищаем ресурсы
    if (widget.focusNode == null) {
      _focusNode.dispose();
    } else {
      _focusNode.removeListener(_handleFocusChange);
    }
    _documentChangesSubscription?.cancel();
    _quillController.dispose();
    _focusModeController.dispose();
    super.dispose();
  }

  /// Выбор изображения из галереи
  Future<void> _onImageButtonPressed() async {
    final ImagePicker picker = ImagePicker();

    try {
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        _insertImage(pickedFile.path);
      }
    } catch (e) {
      debugPrint('Ошибка при выборе изображения: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось выбрать изображение'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Обновление редактора при изменении внешнего контроллера
  @override
  void didUpdateWidget(QuillEditorWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Обновляем фокус при изменении виджета
    if (widget.focusNode != oldWidget.focusNode) {
      _focusNode.removeListener(_handleFocusChange);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChange);
    }

    // Проверяем, изменился ли контент в TextEditingController
    if (widget.controller.text.isNotEmpty &&
        widget.controller.text != oldWidget.controller.text) {
      _updateQuillFromController();
    }
  }

  /// Выбор и вставка файла
  Future<void> _onFileButtonPressed() async {
    final MediaService mediaService = MediaService();

    try {
      // Использование MediaService для выбора файла
      final filePath = await mediaService.pickFile();

      if (filePath != null && filePath.isNotEmpty) {
        // Вставляем файл как изображение, если это изображение
        if (mediaService.isImage(filePath)) {
          _insertImage(filePath);
        } else {
          // Для других типов файлов вставляем специальный блок
          _insertCustomFile(filePath);
        }

        // Уведомляем родительский виджет
        if (widget.onMediaAdded != null) {
          widget.onMediaAdded!(filePath);
        }
      }
    } catch (e) {
      debugPrint('Ошибка при выборе файла: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось выбрать файл'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Вставка изображения в редактор
  void _insertImage(String imagePath) {
    final index = _quillController.selection.baseOffset;
    final correctedIndex = index < 0 ? 0 : index;

    // Вставляем изображение как embedded объект
    _quillController.document.insert(
      correctedIndex,
      BlockEmbed.image(imagePath),
    );

    // Добавляем перевод строки после изображения
    _quillController.document.insert(correctedIndex + 1, '\n');

    // Уведомляем родительский виджет
    if (widget.onMediaAdded != null) {
      widget.onMediaAdded!(imagePath);
    }
  }

  /// Вставка файла (не изображения) в редактор
  void _insertCustomFile(String filePath) {
    final index = _quillController.selection.baseOffset;
    final correctedIndex = index < 0 ? 0 : index;

    // Вставляем описание файла с ссылкой
    final fileName = path.basename(filePath);

    // Создаем форматированный текст для ссылки на файл
    _quillController.document.insert(correctedIndex, '[Файл: $fileName]');

    // Форматируем как ссылку
    _quillController.formatText(
      correctedIndex,
      fileName.length + 8, // длина текста [Файл: $fileName]
      LinkAttribute(filePath),
    );

    // Добавляем перевод строки
    _quillController.document.insert(
      correctedIndex + fileName.length + 8,
      '\n',
    );
  }

  /// Открытие файла во внешнем приложении
  Future<void> _openFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        final uri = Uri.file(filePath);
        if (await url_launcher.canLaunchUrl(uri)) {
          await url_launcher.launchUrl(uri);
        } else {
          _showErrorMessage('Не удалось открыть файл');
        }
      } else {
        _showErrorMessage('Файл не существует');
      }
    } catch (e) {
      debugPrint('Ошибка при открытии файла: $e');
      _showErrorMessage('Ошибка при открытии файла');
    }
  }

  /// Отображение сообщения об ошибке
  void _showErrorMessage(String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
    }
  }

  /// Обновление содержимого Quill из TextEditingController
  Future<void> _updateQuillFromController() async {
    try {
      final content = widget.controller.text;
      if (content.isEmpty) {
        // Если контент пустой, создаем пустой документ
        _quillController.document = Document();
        return;
      }

      // Проверяем формат JSON и преобразуем при необходимости
      dynamic jsonData;
      try {
        jsonData = json.decode(content);
      } catch (e) {
        debugPrint('Ошибка при разборе JSON: $e');
        // Создаем документ с текстом
        _quillController.document = Document()..insert(0, content);
        return;
      }

      // Проверяем, правильный ли это формат Delta JSON
      if (jsonData is Map<String, dynamic> && jsonData.containsKey('ops')) {
        // Если это корректный формат с ключом 'ops'
        final delta = quill_delta.Delta.fromJson(jsonData['ops'] as List);
        _quillController.document = Document.fromDelta(delta);
        debugPrint('Документ успешно обновлен из Delta (с ключом ops)');
      } else if (jsonData is List) {
        // Если это просто массив операций
        final delta = quill_delta.Delta.fromJson(jsonData);
        _quillController.document = Document.fromDelta(delta);

        // Преобразуем в правильный формат для следующего использования
        final correctedJson = {'ops': jsonData};
        widget.controller.text = jsonEncode(correctedJson);

        debugPrint('Документ успешно обновлен из Delta (из списка операций)');
      } else {
        // Если это неизвестный формат, создаем документ с текстом
        debugPrint('Неподдерживаемый формат JSON, вставляем как текст');
        _quillController.document = Document()..insert(0, content);

        // Обновляем контроллер с правильным форматом
        final plainText = _quillController.document.toPlainText();
        final ops = [
          {'insert': plainText},
        ];
        widget.controller.text = jsonEncode({'ops': ops});
      }

      // Сбрасываем позицию курсора в начало
      _quillController.updateSelection(
        TextSelection.collapsed(offset: 0),
        ChangeSource.remote,
      );
    } catch (e) {
      debugPrint('Ошибка при обновлении Quill из контроллера: $e');

      try {
        // В случае ошибки просто вставляем текст
        _quillController.document =
            Document()..insert(0, widget.controller.text);

        // Обновляем контроллер с правильным форматом
        final plainText = _quillController.document.toPlainText();
        final ops = [
          {'insert': plainText},
        ];
        widget.controller.text = jsonEncode({'ops': ops});
      } catch (textError) {
        debugPrint('Ошибка при вставке текста: $textError');
        _quillController.document = Document();
      }
    }
  }

  /// Обработчик изменения фокуса
  void _handleFocusChange() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final hasFocus = _focusNode.hasFocus;

    // Когда редактор теряет фокус, принудительно синхронизируем состояние
    if (!hasFocus && _quillController.document.length > 0) {
      try {
        final delta = _quillController.document.toDelta();
        final deltaJson = jsonEncode({'ops': delta.toJson()});

        // Обновляем контроллер только если он отличается от текущего содержимого
        if (widget.controller.text != deltaJson) {
          widget.controller.text = deltaJson;

          if (widget.onChanged != null) {
            widget.onChanged!(deltaJson);
          }
        }
      } catch (e) {
        debugPrint('Ошибка синхронизации при потере фокуса: $e');

        // При ошибке пытаемся сохранить хотя бы простой текст
        try {
          final plainText = _quillController.document.toPlainText();
          if (plainText.isNotEmpty && widget.controller.text != plainText) {
            widget.controller.text = plainText;

            if (widget.onChanged != null) {
              widget.onChanged!(plainText);
            }
          }
        } catch (secondaryError) {
          debugPrint(
            'Не удалось сохранить даже простой текст: $secondaryError',
          );
        }
      }
    }

    setState(() {
      _isFocusMode = hasFocus;
    });

    // Активируем режим фокусировки только если фокус на редакторе
    if (hasFocus && appProvider.enableFocusMode) {
      _focusModeController.forward();
    } else {
      _focusModeController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final isDarkMode = appProvider.isDarkMode(context);

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
                borderRadius: BorderRadius.circular(
                  AppDimens.buttonBorderRadius,
                ),
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
                              AppDimens.buttonBorderRadius,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  0.7 * _focusModeAnimation.value,
                                ),
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
                      // Панель для кнопок прикрепления файлов
                      if (!widget.readOnly)
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(
                                AppDimens.buttonBorderRadius,
                              ),
                              topRight: Radius.circular(
                                AppDimens.buttonBorderRadius,
                              ),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12.0,
                              vertical: 8.0,
                            ),
                            child: Row(
                              children: [
                                // Кнопка прикрепления фото
                                InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: _onImageButtonPressed,
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

                                // Кнопка прикрепления файла
                                InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: _onFileButtonPressed,
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
                                  size: 36,
                                  onRecordComplete: (audioPath) {
                                    if (audioPath.isNotEmpty &&
                                        widget.onMediaAdded != null) {
                                      widget.onMediaAdded!(audioPath);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Редактор Quill
                      Container(
                        height: widget.height ?? 250,
                        constraints: BoxConstraints(
                          minHeight: 150,
                          maxHeight: widget.height ?? 400,
                        ),
                        padding: const EdgeInsets.all(16.0),
                        child:
                            _isLoading
                                ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                                : QuillEditor(
                                  controller: _quillController,
                                  focusNode:
                                      widget.readOnly
                                          ? FocusNode(canRequestFocus: false)
                                          : _focusNode,
                                  scrollController: ScrollController(),
                                  configurations: QuillEditorConfigurations(
                                    readOnly: widget.readOnly,
                                    placeholder: widget.placeholder ?? '',
                                    autoFocus: widget.autofocus,
                                    expands: false,
                                    padding: EdgeInsets.zero,
                                    scrollable: true,
                                    enableSelectionToolbar: true,
                                    showCursor: !widget.readOnly,
                                  ),
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Панель форматирования (только в режиме редактирования)
            if (!widget.readOnly) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(
                    AppDimens.buttonBorderRadius,
                  ),
                  boxShadow: [AppShadows.small],
                ),
                child: _buildFormattingToolbar(),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Построение панели инструментов форматирования
  Widget _buildFormattingToolbar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 12.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Основные кнопки форматирования текста
            _buildToolbarButton(
              icon: Icons.format_bold,
              tooltip: 'Жирный',
              onPressed: () => _toggleFormat(Attribute.bold),
              isActive: _quillController.getSelectionStyle().containsKey(
                Attribute.bold.key,
              ),
            ),
            _buildToolbarButton(
              icon: Icons.format_italic,
              tooltip: 'Курсив',
              onPressed: () => _toggleFormat(Attribute.italic),
              isActive: _quillController.getSelectionStyle().containsKey(
                Attribute.italic.key,
              ),
            ),
            _buildToolbarButton(
              icon: Icons.format_underline,
              tooltip: 'Подчеркнутый',
              onPressed: () => _toggleFormat(Attribute.underline),
              isActive: _quillController.getSelectionStyle().containsKey(
                Attribute.underline.key,
              ),
            ),
            _buildDivider(),

            // Кнопки для списков
            _buildToolbarButton(
              icon: Icons.format_list_bulleted,
              tooltip: 'Маркированный список',
              onPressed: () => _toggleFormat(Attribute.ul),
              isActive: _quillController.getSelectionStyle().containsKey(
                Attribute.ul.key,
              ),
            ),
            _buildToolbarButton(
              icon: Icons.format_list_numbered,
              tooltip: 'Нумерованный список',
              onPressed: () => _toggleFormat(Attribute.ol),
              isActive: _quillController.getSelectionStyle().containsKey(
                Attribute.ol.key,
              ),
            ),
            _buildDivider(),

            // Заголовки и цитаты
            _buildToolbarButton(
              icon: Icons.title,
              tooltip: 'Заголовок',
              onPressed: () => _cycleHeaderFormat(),
              isActive: _isHeadingActive(),
            ),
            _buildToolbarButton(
              icon: Icons.format_quote,
              tooltip: 'Цитата',
              onPressed: () => _toggleFormat(Attribute.blockQuote),
              isActive: _quillController.getSelectionStyle().containsKey(
                Attribute.blockQuote.key,
              ),
            ),

            // Выравнивание текста
            _buildDivider(),
            _buildToolbarButton(
              icon: Icons.format_align_left,
              tooltip: 'По левому краю',
              onPressed: () => _setTextAlignment(TextAlign.left),
              isActive: _isTextAlignmentActive(TextAlign.left),
            ),
            _buildToolbarButton(
              icon: Icons.format_align_center,
              tooltip: 'По центру',
              onPressed: () => _setTextAlignment(TextAlign.center),
              isActive: _isTextAlignmentActive(TextAlign.center),
            ),
            _buildToolbarButton(
              icon: Icons.format_align_right,
              tooltip: 'По правому краю',
              onPressed: () => _setTextAlignment(TextAlign.right),
              isActive: _isTextAlignmentActive(TextAlign.right),
            ),

            // Дополнительные опции
            _buildDivider(),
            _buildOverflowMenu(),
          ],
        ),
      ),
    );
  }

  /// Проверка активности заголовка
  bool _isHeadingActive() {
    final style = _quillController.getSelectionStyle();
    return style.containsKey(Attribute.h1.key) ||
        style.containsKey(Attribute.h2.key) ||
        style.containsKey(Attribute.h3.key);
  }

  /// Проверка активного выравнивания текста
  bool _isTextAlignmentActive(TextAlign align) {
    final attributes = _quillController.getSelectionStyle();
    if (!attributes.containsKey(Attribute.align.key)) {
      return align == TextAlign.left; // По умолчанию
    }

    String? currentAlign;
    try {
      final attribute = attributes.attributes[Attribute.align.key];
      currentAlign = attribute?.value;
    } catch (e) {
      return align == TextAlign.left;
    }

    switch (align) {
      case TextAlign.left:
        return currentAlign == null || currentAlign == 'left';
      case TextAlign.center:
        return currentAlign == 'center';
      case TextAlign.right:
        return currentAlign == 'right';
      case TextAlign.justify:
        return currentAlign == 'justify';
      default:
        return false;
    }
  }

  /// Установка выравнивания текста
  void _setTextAlignment(TextAlign align) {
    Attribute attribute;
    switch (align) {
      case TextAlign.left:
        attribute = Attribute.clone(Attribute.align, null);
        break;
      case TextAlign.center:
        attribute = Attribute.clone(Attribute.align, 'center');
        break;
      case TextAlign.right:
        attribute = Attribute.clone(Attribute.align, 'right');
        break;
      case TextAlign.justify:
        attribute = Attribute.clone(Attribute.align, 'justify');
        break;
      default:
        attribute = Attribute.clone(Attribute.align, null);
        break;
    }

    _quillController.formatSelection(attribute);
  }

  /// Меню дополнительных опций форматирования
  Widget _buildOverflowMenu() {
    return PopupMenuButton<Function>(
      icon: Icon(Icons.more_vert, size: 20, color: AppColors.textOnDark),
      tooltip: 'Дополнительно',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
      ),
      itemBuilder:
          (BuildContext context) => [
            PopupMenuItem<Function>(
              value: _insertLink,
              child: Row(
                children: [
                  Icon(Icons.link, size: 18, color: AppColors.textOnLight),
                  const SizedBox(width: 10),
                  Text(
                    'Вставить ссылку',
                    style: TextStyle(color: AppColors.textOnLight),
                  ),
                ],
              ),
            ),
            PopupMenuItem<Function>(
              value: () => _toggleFormat(Attribute.inlineCode),
              child: Row(
                children: [
                  Icon(Icons.code, size: 18, color: AppColors.textOnLight),
                  const SizedBox(width: 10),
                  Text('Код', style: TextStyle(color: AppColors.textOnLight)),
                ],
              ),
            ),
            PopupMenuItem<Function>(
              value: _clearFormatting,
              child: Row(
                children: [
                  Icon(
                    Icons.format_clear,
                    size: 18,
                    color: AppColors.textOnLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Очистить форматирование',
                    style: TextStyle(color: AppColors.textOnLight),
                  ),
                ],
              ),
            ),
          ],
      onSelected: (Function action) {
        action();
      },
    );
  }

  /// Метод для вставки ссылки
  void _insertLink() {
    final selection = _quillController.selection;
    String selectedText = '';

    if (!selection.isCollapsed) {
      final offset = selection.baseOffset;
      final length = selection.extentOffset - selection.baseOffset;
      selectedText = _quillController.document.getPlainText(offset, length);
    }

    showDialog(
      context: context,
      builder: (context) {
        String text = selectedText;
        String link = '';

        return AlertDialog(
          title: const Text('Вставить ссылку'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Текст',
                  hintText: 'Введите текст ссылки',
                ),
                controller: TextEditingController(text: text),
                onChanged: (value) => text = value,
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Ссылка',
                  hintText: 'https://...',
                ),
                controller: TextEditingController(text: link),
                onChanged: (value) => link = value,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                if (text.isNotEmpty && link.isNotEmpty) {
                  // Если есть выделенный текст, заменяем его
                  if (!selection.isCollapsed) {
                    final offset = selection.baseOffset;
                    final length =
                        selection.extentOffset - selection.baseOffset;

                    // Удаляем выделенный текст
                    _quillController.replaceText(offset, length, text, null);

                    // Применяем форматирование ссылки
                    _quillController.formatText(
                      offset,
                      text.length,
                      LinkAttribute(link),
                    );
                  } else {
                    // Вставляем новый текст и применяем ссылку
                    final index = selection.baseOffset;
                    _quillController.replaceText(index, 0, text, null);
                    _quillController.formatText(
                      index,
                      text.length,
                      LinkAttribute(link),
                    );
                  }
                }
                Navigator.pop(context);
              },
              child: const Text('Вставить'),
            ),
          ],
        );
      },
    );
  }

  /// Метод для очистки форматирования
  void _clearFormatting() {
    if (_quillController.selection.isCollapsed) return;

    // Получаем выделение
    final offset = _quillController.selection.baseOffset;
    final length = _quillController.selection.extentOffset - offset;

    // Получаем текст без форматирования
    final text = _quillController.document.getPlainText(offset, length);

    // Заменяем выделенный текст на тот же текст, но без форматирования
    _quillController.replaceText(offset, length, text, null);
  }

  /// Метод для переключения форматирования текста
  void _toggleFormat(Attribute attribute) {
    _quillController.formatSelection(attribute);
  }

  /// Метод для циклического изменения заголовка
  void _cycleHeaderFormat() {
    final attributes = _quillController.getSelectionStyle();

    // Проверяем текущий формат на наличие заголовка
    Attribute? currentHeader;
    if (attributes.containsKey(Attribute.h1.key)) {
      currentHeader = Attribute.h1;
    } else if (attributes.containsKey(Attribute.h2.key)) {
      currentHeader = Attribute.h2;
    } else if (attributes.containsKey(Attribute.h3.key)) {
      currentHeader = Attribute.h3;
    }

    // Циклически переключаем: h1 -> h2 -> h3 -> обычный текст -> h1
    if (currentHeader == null) {
      _quillController.formatSelection(Attribute.h1);
    } else if (currentHeader.key == Attribute.h1.key) {
      _quillController.formatSelection(Attribute.h1); // Сначала снимаем h1
      _quillController.formatSelection(Attribute.h2); // Затем ставим h2
    } else if (currentHeader.key == Attribute.h2.key) {
      _quillController.formatSelection(Attribute.h2); // Сначала снимаем h2
      _quillController.formatSelection(Attribute.h3); // Затем ставим h3
    } else {
      // Если h3, то удаляем все заголовки
      _quillController.formatSelection(Attribute.h3);
    }
  }

  /// Разделитель для панели инструментов
  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 1,
      height: 20,
      color: AppColors.secondary.withOpacity(0.3),
    );
  }

  /// Кнопка для панели инструментов форматирования
  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color:
            isActive
                ? AppColors.accentPrimary.withOpacity(0.3)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(6.0),
            child: Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.accentPrimary : AppColors.textOnDark,
            ),
          ),
        ),
      ),
    );
  }
}
