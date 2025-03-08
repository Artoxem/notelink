import 'package:uuid/uuid.dart';
import '../models/note.dart';
import '../services/database_service.dart';

class NoteLinksService {
  final DatabaseService _databaseService = DatabaseService();

  // Получение всех связей для заметки
  Future<List<Map<String, dynamic>>> getLinksForNote(String noteId) async {
    try {
      return await _databaseService.getLinksForNote(noteId);
    } catch (e) {
      print('Ошибка при получении связей заметки: $e');
      return [];
    }
  }

  // Создание связи между заметками
  Future<String?> createNoteLink(String sourceNoteId, String targetNoteId,
      {String? themeId}) async {
    try {
      final linkId = const Uuid().v4();
      await _databaseService.insertNoteLink(
          linkId, sourceNoteId, targetNoteId, themeId);
      return linkId;
    } catch (e) {
      print('Ошибка при создании связи между заметками: $e');
      return null;
    }
  }

  // Удаление связи между заметками
  Future<bool> deleteNoteLink(String linkId) async {
    try {
      final result = await _databaseService.deleteNoteLink(linkId);
      return result > 0;
    } catch (e) {
      print('Ошибка при удалении связи: $e');
      return false;
    }
  }

  // Получение связанных заметок
  Future<List<Note>> getLinkedNotes(String noteId) async {
    try {
      final links = await _databaseService.getLinksForNote(noteId);

      // Извлекаем ID связанных заметок
      final linkedNoteIds = <String>[];
      for (final link in links) {
        final sourceId = link['sourceNoteId'] as String;
        final targetId = link['targetNoteId'] as String;

        // Добавляем связанную заметку (не текущую)
        if (sourceId == noteId && !linkedNoteIds.contains(targetId)) {
          linkedNoteIds.add(targetId);
        } else if (targetId == noteId && !linkedNoteIds.contains(sourceId)) {
          linkedNoteIds.add(sourceId);
        }
      }

      // Получаем полные данные заметок по ID
      final notes = <Note>[];
      for (final id in linkedNoteIds) {
        final note = await _databaseService.getNote(id);
        if (note != null) {
          notes.add(note);
        }
      }

      return notes;
    } catch (e) {
      print('Ошибка при получении связанных заметок: $e');
      return [];
    }
  }
}
