import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

import '../providers/app_provider.dart';
import '../services/media_service.dart';
import '../utils/constants.dart';
import 'voice_record_button.dart';

// Виджет-обёртка для Flutter Quill
class QuillEditorWrapper extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? placeholder;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final double? height;
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

  // Добавляем метод для получения доступа к контроллеру
  QuillController? getQuillController() {
    final state = currentState;
    if (state is _QuillEditorWrapperState) {
      return state._quillController;
    }
    return null;
  }

  // Получаем текущее состояние виджета
  _QuillEditorWrapperState? get currentState {
    return GlobalObjectKey(this).currentState as _QuillEditorWrapperState?;
  }

  @override
  State<QuillEditorWrapper> createState() => _QuillEditorWrapperState();
}

class _QuillEditorWrapperState extends State<QuillEditorWrapper>
    with TickerProviderStateMixin {
  // Объявляем _quillController как переменную экземпляра класса с инициализацией по умолчанию
  late QuillController _quillController = QuillController.basic();
  // Создаем getter для доступа к контроллеру извне
  QuillController? getQuillController() {
    return _quillController;
  }

  late FocusNode _focusNode;
  bool _isFocusMode = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  // Подписка на изменения документа
  StreamSubscription? _documentChangesSubscription;

  // Контроллер анимации для режима фокусировки
  late AnimationController _focusModeController;
  late Animation<double> _focusModeAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();

    // Добавляем слушатель фокуса для эффектов UI
    _focusNode.addListener(_handleFocusChange);

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

  Future<void> _initQuillEditor() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Получаем текст из контроллера
      final jsonText = widget.controller.text;

      if (jsonText.isNotEmpty) {
        try {
          // Создаем документ из JSON, как в примере
          final decodedJson = json.decode(jsonText);
          _quillController = QuillController(
            document: Document.fromJson(decodedJson),
            selection: const TextSelection.collapsed(offset: 0),
          );

          debugPrint('QuillController успешно инициализирован из JSON');
          debugPrint(
            'Содержимое: ${_quillController.document.toPlainText().substring(0, min(50, _quillController.document.toPlainText().length))}...',
          );

          setState(() {
            _isLoading = false;
            _isInitialized = true;
          });

          // Настраиваем слушатель изменений
          _setupDocumentListener();
          return;
        } catch (e) {
          debugPrint('Ошибка при создании документа из JSON: $e');

          // Если не удалось распарсить JSON, создаем пустой документ
          _quillController = QuillController.basic();

          // Пытаемся интерпретировать как текст, если не похож на JSON
          if (!jsonText.contains('{') && !jsonText.contains('[')) {
            _quillController.document.insert(0, jsonText);
            debugPrint('Создан документ из текста');
          }
        }
      } else {
        // Если текст пустой, используем пустой документ
        debugPrint('Инициализация пустого редактора, текст контроллера пуст');
        _quillController = QuillController.basic();
      }

      // Настраиваем слушатель изменений
      _setupDocumentListener();

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('Ошибка инициализации QuillEditor: $e');
      // В любом случае инициализируем базовый контроллер
      _quillController = QuillController.basic();
      _setupDocumentListener();

      setState(() {
        _isLoading = false;
        _isInitialized = true;
      });
    }
  }

  // Выносим настройку слушателя в отдельный метод для переиспользования
  void _setupDocumentListener() {
    // Отменяем предыдущую подписку, если она была
    _documentChangesSubscription?.cancel();

    // Слушаем изменения в документе и обновляем контроллер текста
    _documentChangesSubscription = _quillController.document.changes.listen((
      event,
    ) {
      try {
        // Сохраняем delta в формате JSON с ключом 'ops' по тому же принципу, как в примере
        final json = jsonEncode(_quillController.document.toDelta().toJson());

        // Отладочный вывод
        debugPrint(
          'Изменение в документе: ${_quillController.document.length} символов',
        );
        final plainText = _quillController.document.toPlainText();
        debugPrint(
          'Текущий текст: ${plainText.substring(0, min(50, plainText.length))}...',
        );

        // Обновляем текстовый контроллер JSON строкой
        if (widget.controller.text != json) {
          debugPrint('Обновление контроллера текста с JSON Delta');
          widget.controller.text = json;

          if (widget.onChanged != null) {
            widget.onChanged!(json);
          }
        }
      } catch (e) {
        debugPrint('Ошибка при сохранении delta: $e');

        // В случае ошибки создаем минимальную валидную Delta
        try {
          final plainText = _quillController.document.toPlainText();
          final json = jsonEncode([
            {"insert": plainText.isEmpty ? "\n" : plainText},
          ]);

          if (widget.controller.text != json) {
            widget.controller.text = json;

            if (widget.onChanged != null) {
              widget.onChanged!(json);
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
    _quillController?.removeListener(() {});
    _quillController?.dispose();
    _documentChangesSubscription?.cancel();
    _focusModeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(QuillEditorWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);

    print('didUpdateWidget вызван в QuillEditorWrapper');
    print('Содержимое виджета: ${widget.controller.text.length} символов');
    print('Содержимое редактора: ${_quillController.document.length} операций');

    // Обновляем фокус при изменении виджета
    if (widget.focusNode != oldWidget.focusNode) {
      print('Фокус узел изменился, обновляем...');
      _focusNode.removeListener(_handleFocusChange);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_handleFocusChange);
    }

    // Проверяем, изменился ли контент в TextEditingController
    if (_quillController != null && widget.controller.text.isNotEmpty) {
      try {
        // Пытаемся получить текущую дельту документа и сравнить с контроллером
        final delta = _quillController.document.toDelta();
        final currentJson = jsonEncode(delta.toJson());

        // Если JSON отличается, обновляем документ
        if (widget.controller.text != currentJson) {
          print('Контент изменился, обновляем редактор из контроллера');
          print(
            'Контроллер: ${widget.controller.text.substring(0, min(50, widget.controller.text.length))}...',
          );
          print(
            'Редактор: ${currentJson.substring(0, min(50, currentJson.length))}...',
          );
          _updateQuillFromController();
        } else {
          print('Контент не изменился, пропускаем обновление');
        }
      } catch (e) {
        print('Ошибка сравнения содержимого Quill: $e');
        // В случае ошибки обновляем содержимое
        _updateQuillFromController();
      }
    } else if (widget.controller.text.isEmpty &&
        _quillController.document.length > 0) {
      print(
        'ВНИМАНИЕ: Контроллер пуст, но документ не пуст - проверяем состояние',
      );
      // Проверить, был ли контроллер изначально пуст или его содержимое было стерто
      final isPreviousEmpty = oldWidget.controller.text.isEmpty;
      print('Предыдущее содержимое контроллера пусто: $isPreviousEmpty');

      if (isPreviousEmpty) {
        // Если контроллер был пуст изначально, то это нормальная ситуация - документ еще не синхронизирован
        print('Контроллер был пуст изначально, пропускаем очистку документа');

        // Вместо этого, сохраняем содержимое документа в контроллер
        try {
          final delta = _quillController.document.toDelta();
          final deltaJson = jsonEncode(delta.toJson());
          print(
            'Синхронизируем контроллер с документом: ${deltaJson.length} символов',
          );
          widget.controller.text = deltaJson;
        } catch (e) {
          print('Ошибка при сохранении документа в контроллер: $e');
        }
      } else {
        // Если контроллер не был пуст раньше, но стал пустым - что-то пошло не так
        // Например, могла произойти ошибка обновления контроллера или стирание текста при потере фокуса
        print('Контроллер внезапно стал пустым! Предотвращаем потерю данных.');

        // Сохраняем содержимое документа в контроллер вместо очистки документа
        try {
          final delta = _quillController.document.toDelta();
          final deltaJson = jsonEncode(delta.toJson());
          print(
            'Восстанавливаем контроллер из документа: ${deltaJson.length} символов',
          );
          widget.controller.text = deltaJson;
        } catch (e) {
          print('Ошибка при сохранении документа в контроллер: $e');
        }
      }
    }
  }

  // Метод для обновления содержимого Quill из TextEditingController
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
        final delta = Delta.fromJson(jsonData['ops'] as List);
        _quillController.document = Document.fromDelta(delta);
        debugPrint('Документ успешно обновлен из Delta (с ключом ops)');
      } else if (jsonData is List) {
        // Если это просто массив операций, обернем его в правильный формат с ключом 'ops'
        final delta = Delta.fromJson(jsonData);
        _quillController.document = Document.fromDelta(delta);

        // Преобразуем в правильный формат для следующего использования
        final correctedJson = {'ops': jsonData};
        widget.controller.text = jsonEncode(correctedJson);

        debugPrint(
          'Документ успешно обновлен из Delta (из списка операций) и формат исправлен',
        );
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
      debugPrint('Пытаемся вставить текст напрямую без разбора JSON');

      try {
        // В случае ошибки просто вставляем текст
        _quillController.document =
            Document()..insert(0, widget.controller.text);

        // Обновляем контроллер
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

  // Обновление при изменении документа
  void _updateControllerFromQuill() {
    try {
      final delta = _quillController.document.toDelta();
      final deltaJson = jsonEncode({'ops': delta.toJson()});

      debugPrint('Изменение в документе: ${delta.length} операций');
      final plainText = _quillController.document.toPlainText().trim();
      debugPrint(
        'Текущий текст: ${plainText.substring(0, min(50, plainText.length))}',
      );

      // Проверяем отличается ли текущий контент от сохраненного
      if (widget.controller.text != deltaJson) {
        debugPrint('Обновление контроллера текста с JSON Delta');

        // Обновляем контроллер с правильным форматом Delta JSON
        widget.controller.text = deltaJson;

        // Вызываем колбэк, если он предоставлен
        if (widget.onChanged != null) {
          widget.onChanged!(deltaJson);
        }
      }
    } catch (e) {
      debugPrint('Ошибка при обновлении контроллера: $e');

      try {
        // В случае ошибки создаем базовую Delta с текстом
        final plainText = _quillController.document.toPlainText();
        final ops = [
          {'insert': plainText},
        ];
        final basicDeltaJson = jsonEncode({'ops': ops});

        if (widget.controller.text != basicDeltaJson) {
          widget.controller.text = basicDeltaJson;

          if (widget.onChanged != null) {
            widget.onChanged!(basicDeltaJson);
          }
        }
      } catch (backupError) {
        debugPrint('Не удалось создать резервную копию Delta: $backupError');
      }
    }
  }

  // Обработчик изменения фокуса
  void _handleFocusChange() {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final hasFocus = _focusNode.hasFocus;

    // Когда редактор теряет фокус, принудительно синхронизируем состояние с контроллером
    if (!hasFocus && _quillController.document.length > 0) {
      try {
        final delta = _quillController.document.toDelta();
        final deltaJson = jsonEncode(delta.toJson());
        final plainText = _quillController.document.toPlainText();

        print('Потеря фокуса: документ длиной ${plainText.length} символов');

        // Обновляем контроллер только если он отличается от текущего содержимого
        if (widget.controller.text != deltaJson) {
          print('Синхронизация при потере фокуса: обновляем контроллер');
          widget.controller.text = deltaJson;

          if (widget.onChanged != null) {
            widget.onChanged!(deltaJson);
            print('Вызвано событие onChanged после синхронизации');
          }
        } else {
          print('Текст контроллера не изменился при потере фокуса');
        }
      } catch (e) {
        print('Ошибка синхронизации при потере фокуса: $e');
        // При ошибке декодирования JSON пытаемся сохранить хотя бы простой текст
        try {
          final plainText = _quillController.document.toPlainText();
          print(
            'Сохранение простого текста после ошибки: ${plainText.length} символов',
          );
          if (plainText.isNotEmpty && widget.controller.text != plainText) {
            widget.controller.text = plainText;

            if (widget.onChanged != null) {
              widget.onChanged!(plainText);
              print('Вызвано событие onChanged с обычным текстом');
            }
          }
        } catch (secondaryError) {
          print('Не удалось сохранить даже простой текст: $secondaryError');
        }
      }
    }

    setState(() {
      _isFocusMode = hasFocus;
    });

    // Активируем режим фокусировки только если фокус на редакторе и включена опция в настройках
    if (hasFocus && appProvider.enableFocusMode) {
      _focusModeController.forward();
    } else {
      _focusModeController.reverse();
    }
  }

  // Метод для вставки изображения в редактор
  void _insertImage(String path) {
    if (_quillController == null) return;

    // Получаем текущую позицию курсора
    final index = _quillController!.selection.baseOffset;
    final correctedIndex = index < 0 ? 0 : index;

    // Вставляем изображение как embedded объект
    _quillController!.document.insert(correctedIndex, BlockEmbed.image(path));

    // Уведомляем родительский виджет
    if (widget.onMediaAdded != null) {
      widget.onMediaAdded!(path);
    }
  }

  // Метод для обработки выбора медиа-файла
  Future<void> _onImageButtonPressed() async {
    // ... существующий код
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
                              // Иконка для прикрепления фото (без стиля кнопки)
                              InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => _onImageButtonPressed(),
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
                                onTap: () => _onImageButtonPressed(),
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
                                  // ... существующий код
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Редактор Quill
                      Container(
                        height: widget.height ?? 250, // Настраиваемая высота
                        constraints: BoxConstraints(
                          minHeight: 150,
                          maxHeight: widget.height ?? 400,
                        ),
                        padding: const EdgeInsets.all(16.0),
                        // Используем минимальный набор параметров
                        child: QuillEditor.basic(
                          controller: _quillController,
                          focusNode:
                              widget.readOnly
                                  ? FocusNode(
                                    canRequestFocus: false,
                                  ) // Для только чтения используем фокус, который не может быть запрошен
                                  : _focusNode,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Панель форматирования
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(
                  AppDimens.buttonBorderRadius,
                ),
                boxShadow: [AppShadows.small],
              ),
              child: _buildFormattingToolbarAsBlock(),
            ),
          ],
        );
      },
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

            // Кнопки для форматирования списков
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

            // Кнопки для заголовков и цитат
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

            // Кнопки для выравнивания
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

            // Меню дополнительных опций
            _buildDivider(),
            _buildOverflowMenu(),
          ],
        ),
      ),
    );
  }

  // Проверка активен ли какой-либо заголовок
  bool _isHeadingActive() {
    final style = _quillController.getSelectionStyle();
    return style.containsKey(Attribute.h1.key) ||
        style.containsKey(Attribute.h2.key) ||
        style.containsKey(Attribute.h3.key);
  }

  // Проверка активного выравнивания текста
  bool _isTextAlignmentActive(TextAlign align) {
    final attributes = _quillController.getSelectionStyle();
    if (!attributes.containsKey(Attribute.align.key)) {
      return align ==
          TextAlign.left; // По умолчанию текст выравнивается по левому краю
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

  // Установка выравнивания текста
  void _setTextAlignment(TextAlign align) {
    Attribute attribute;
    switch (align) {
      case TextAlign.left:
        attribute = Attribute.clone(
          Attribute.align,
          null,
        ); // Сброс на значение по умолчанию
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

  // Кнопка "Еще" с выпадающим меню дополнительных опций
  Widget _buildOverflowMenu() {
    return PopupMenuButton<Function>(
      icon: Icon(Icons.more_vert, size: 20, color: AppColors.textOnDark),
      tooltip: 'Дополнительно',
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
      ),
      itemBuilder:
          (BuildContext context) => [
            // Кнопка для вставки ссылки
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
            // Кнопка для кода
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
            // Кнопка для цвета текста
            PopupMenuItem<Function>(
              value: _showColorPicker,
              child: Row(
                children: [
                  Icon(
                    Icons.format_color_text,
                    size: 18,
                    color: AppColors.textOnLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Цвет текста',
                    style: TextStyle(color: AppColors.textOnLight),
                  ),
                ],
              ),
            ),
            // Кнопка для фона текста
            PopupMenuItem<Function>(
              value: _showBackgroundColorPicker,
              child: Row(
                children: [
                  Icon(
                    Icons.format_color_fill,
                    size: 18,
                    color: AppColors.textOnLight,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Цвет фона',
                    style: TextStyle(color: AppColors.textOnLight),
                  ),
                ],
              ),
            ),
            // Кнопка для очистки форматирования
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

  // Метод для вставки ссылки
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

  // Метод для выбора цвета текста
  void _showColorPicker() {
    final List<Color> colors = [
      Colors.black,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.blue,
      Colors.indigo,
      Colors.purple,
      Colors.pink,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выберите цвет текста'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                colors.map((color) {
                  return InkWell(
                    onTap: () {
                      // Применяем выбранный цвет к тексту
                      _quillController.formatSelection(
                        ColorAttribute(color.value.toString()),
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );
  }

  // Метод для выбора цвета фона текста
  void _showBackgroundColorPicker() {
    final List<Color> colors = [
      Colors.white,
      Colors.red.shade100,
      Colors.orange.shade100,
      Colors.yellow.shade100,
      Colors.green.shade100,
      Colors.blue.shade100,
      Colors.indigo.shade100,
      Colors.purple.shade100,
      Colors.pink.shade100,
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выберите цвет фона'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                colors.map((color) {
                  return InkWell(
                    onTap: () {
                      // Применяем выбранный цвет к фону текста
                      _quillController.formatSelection(
                        BackgroundAttribute(color.value.toString()),
                      );
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
          ],
        );
      },
    );
  }

  // Метод для очистки форматирования
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

  // Метод для переключения форматирования текста - упрощенная версия
  void _toggleFormat(Attribute attribute) {
    if (_quillController.selection.isCollapsed) {
      // Если нет выделения, просто изменяем атрибут текущей позиции
      _quillController.formatSelection(attribute);
    } else {
      // Если есть выделение, применяем форматирование
      final isSelected = _quillController.getSelectionStyle().containsKey(
        attribute.key,
      );

      if (isSelected) {
        // Если атрибут уже применен, удаляем его
        // Сначала создаем "стирающий" атрибут того же типа
        final clearAttribute = Attribute.clone(attribute, null);
        _quillController.formatSelection(clearAttribute);
      } else {
        // Иначе применяем его
        _quillController.formatSelection(attribute);
      }
    }
  }

  // Метод для циклического изменения заголовка
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
      _quillController.formatSelection(currentHeader);
    }
  }

  // Разделитель для панели инструментов
  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      width: 1,
      height: 20,
      color: AppColors.secondary.withOpacity(0.3),
    );
  }

  // Кнопка для панели инструментов форматирования
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
