import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill/quill_delta.dart';

/// Утилитный класс для работы с Delta JSON
class DeltaUtils {
  /// Преобразует различные форматы Delta JSON к стандартному формату с ключом 'ops'
  static String standardizeDeltaJson(String jsonText) {
    if (jsonText.isEmpty) {
      // Возвращаем пустую Delta
      return '{"ops":[{"insert":"\\n"}]}';
    }

    try {
      final dynamic decoded = json.decode(jsonText);

      if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('ops')) {
          // Уже стандартный формат - возвращаем как есть
          return jsonText;
        } else {
          // Map без 'ops' - не можем интерпретировать как Delta
          // Преобразуем в текст
          return createTextOnlyDelta(decoded.toString());
        }
      } else if (decoded is List) {
        // Список операций без обертки 'ops'
        return json.encode({'ops': decoded});
      } else if (decoded is String) {
        // Строка - создаем Delta с текстовым содержимым
        return createTextOnlyDelta(decoded);
      } else {
        // Неизвестный формат - создаем пустую Delta
        return '{"ops":[{"insert":"\\n"}]}';
      }
    } catch (e) {
      debugPrint('Ошибка при стандартизации Delta JSON: $e');

      // Если не удалось декодировать JSON, пробуем интерпретировать как текст
      if (!jsonText.contains('{') && !jsonText.contains('[')) {
        return createTextOnlyDelta(jsonText);
      }

      // Иначе возвращаем пустую Delta
      return '{"ops":[{"insert":"\\n"}]}';
    }
  }

  /// Создает Delta JSON только с текстовым содержимым
  static String createTextOnlyDelta(String text) {
    final String sanitizedText = text.isEmpty ? '\n' : text;
    return json.encode({
      'ops': [
        {'insert': sanitizedText},
      ],
    });
  }

  /// Проверяет валидность Delta JSON
  static bool isValidDeltaJson(String jsonText) {
    try {
      final dynamic decoded = json.decode(jsonText);

      // Проверяем, что это правильная структура Delta
      if (decoded is Map<String, dynamic> && decoded.containsKey('ops')) {
        final ops = decoded['ops'];
        return ops is List;
      } else if (decoded is List) {
        // Список операций тоже считаем валидным
        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Извлекает простой текст из Delta JSON
  static String extractPlainText(String jsonText) {
    if (jsonText.isEmpty) {
      return '';
    }

    try {
      // Стандартизируем формат
      final standardJson = standardizeDeltaJson(jsonText);
      final decoded = json.decode(standardJson);

      // Получаем операции
      List? ops;
      if (decoded is Map && decoded.containsKey('ops')) {
        ops = decoded['ops'] as List?;
      }

      if (ops == null) {
        return '';
      }

      // Создаем Delta и извлекаем текст
      try {
        final delta = Delta.fromJson(ops);
        final doc = quill.Document.fromDelta(delta);
        final plainText = doc.toPlainText().trim();
        return plainText;
      } catch (e) {
        // Если не удалось создать Delta, извлекаем текст вручную
        return ops.fold<String>('', (text, op) {
          if (op is Map && op.containsKey('insert') && op['insert'] is String) {
            return text + op['insert'];
          }
          return text;
        }).trim();
      }
    } catch (e) {
      debugPrint('Ошибка при извлечении текста из Delta JSON: $e');
      return '';
    }
  }

  /// Создает QuillController из Delta JSON
  static quill.QuillController createQuillController(String jsonText) {
    try {
      // Стандартизируем формат
      final standardJson = standardizeDeltaJson(jsonText);
      final decoded = json.decode(standardJson);

      return quill.QuillController(
        document: quill.Document.fromJson(decoded),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      debugPrint('Ошибка при создании QuillController: $e');
      // Возвращаем пустой контроллер в случае ошибки
      return quill.QuillController.basic();
    }
  }
}
