import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:note_link/utils/delta_utils.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

void main() {
  group('DeltaUtils', () {
    test('standardizeDeltaJson - пустая строка', () {
      final result = DeltaUtils.standardizeDeltaJson('');
      expect(result, '{"ops":[{"insert":"\\n"}]}');
    });

    test('standardizeDeltaJson - стандартный формат', () {
      final input = '{"ops":[{"insert":"Hello world"}]}';
      final result = DeltaUtils.standardizeDeltaJson(input);
      expect(result, input);
    });

    test('standardizeDeltaJson - список операций без ops', () {
      final input = '[{"insert":"Hello world"}]';
      final result = DeltaUtils.standardizeDeltaJson(input);
      final expected = '{"ops":[{"insert":"Hello world"}]}';
      expect(result, expected);
    });

    test('standardizeDeltaJson - простой текст', () {
      final input = 'Hello world';
      final result = DeltaUtils.standardizeDeltaJson(input);
      final decoded = json.decode(result);
      expect(decoded['ops'][0]['insert'], 'Hello world');
    });

    test('isValidDeltaJson - валидный JSON с ops', () {
      final input = '{"ops":[{"insert":"Hello world"}]}';
      expect(DeltaUtils.isValidDeltaJson(input), true);
    });

    test('isValidDeltaJson - валидный JSON без ops', () {
      final input = '[{"insert":"Hello world"}]';
      expect(DeltaUtils.isValidDeltaJson(input), true);
    });

    test('isValidDeltaJson - невалидный JSON', () {
      final input = '{broken json}';
      expect(DeltaUtils.isValidDeltaJson(input), false);
    });

    test('extractPlainText - стандартный формат', () {
      final input = '{"ops":[{"insert":"Hello world\\n"}]}';
      expect(DeltaUtils.extractPlainText(input), 'Hello world');
    });

    test('extractPlainText - список операций без ops', () {
      final input = '[{"insert":"Hello world\\n"}]';
      expect(DeltaUtils.extractPlainText(input), 'Hello world');
    });

    test('extractPlainText - с форматированием', () {
      final input =
          '{"ops":[{"insert":"Hello "},{"attributes":{"bold":true},"insert":"bold"},{"insert":" world\\n"}]}';
      expect(DeltaUtils.extractPlainText(input), 'Hello bold world');
    });

    test('createTextOnlyDelta - пустая строка', () {
      final result = DeltaUtils.createTextOnlyDelta('');
      expect(result, '{"ops":[{"insert":"\\n"}]}');
    });

    test('createTextOnlyDelta - с текстом', () {
      final result = DeltaUtils.createTextOnlyDelta('Hello world');
      final decoded = json.decode(result);
      expect(decoded['ops'][0]['insert'], 'Hello world');
    });

    test('createQuillController - создает не-null контроллер', () {
      final input = '{"ops":[{"insert":"Hello world"}]}';
      final controller = DeltaUtils.createQuillController(input);
      expect(controller, isA<quill.QuillController>());
      expect(controller.document.toPlainText().trim(), 'Hello world');
    });

    test('createQuillController - с невалидным JSON', () {
      final input = '{broken json}';
      final controller = DeltaUtils.createQuillController(input);
      expect(controller, isA<quill.QuillController>());
      // Проверяем, что создан пустой контроллер
      expect(controller.document.toPlainText().trim(), '');
    });
  });
}
