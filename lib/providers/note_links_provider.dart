import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/note_link.dart';
import '../services/database_service.dart';

class NoteLinksProvider with ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  List<NoteLink> _links = [];
  bool _isLoading = false;

  List<NoteLink> get links => _links;
  bool get isLoading => _isLoading;

  // Получение всех связей
  Future<void> loadLinks() async {
    _isLoading = true;
    notifyListeners();

    try {
      _links = await _databaseService.getNoteLinks();
      print('Загружено ${_links.length} связей между заметками');
    } catch (e) {
      print('Ошибка при загрузке связей: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Создание новой связи
  Future<NoteLink> createLink({
    required String sourceNoteId,
    required String targetNoteId,
    String? themeId,
    required LinkType linkType,
    String? description,
  }) async {
    final link = NoteLink(
      id: const Uuid().v4(),
      sourceNoteId: sourceNoteId,
      targetNoteId: targetNoteId,
      themeId: themeId,
      linkType: linkType,
      createdAt: DateTime.now(),
      description: description,
    );

    try {
      await _databaseService.insertNoteLink(link);
      _links.add(link);
      print('Связь успешно создана: ${link.id}');
      notifyListeners();
    } catch (e) {
      print('Ошибка при создании связи: $e');
    }

    return link;
  }

  // Обновление существующей связи
  Future<void> updateLink(NoteLink link) async {
    try {
      await _databaseService.updateNoteLink(link);
      final index = _links.indexWhere((l) => l.id == link.id);
      if (index != -1) {
        _links[index] = link;
        notifyListeners();
      }
    } catch (e) {
      print('Ошибка при обновлении связи: $e');
    }
  }

  // Удаление связи
  Future<void> deleteLink(String id) async {
    try {
      await _databaseService.deleteNoteLink(id);
      _links.removeWhere((l) => l.id == id);
      notifyListeners();
    } catch (e) {
      print('Ошибка при удалении связи: $e');
    }
  }

  // Удаление всех связей для заметки
  Future<void> deleteLinksForNote(String noteId) async {
    try {
      await _databaseService.deleteNoteLinksByNoteId(noteId);
      _links.removeWhere(
          (l) => l.sourceNoteId == noteId || l.targetNoteId == noteId);
      notifyListeners();
    } catch (e) {
      print('Ошибка при удалении связей для заметки: $e');
    }
  }

  // Получение связей для конкретной заметки
  List<NoteLink> getLinksForNote(String noteId) {
    return _links
        .where((link) =>
            link.sourceNoteId == noteId || link.targetNoteId == noteId)
        .toList();
  }

  // Получение заметок, связанных с заданной заметкой
  List<String> getLinkedNoteIds(String noteId) {
    final Set<String> linkedIds = {};

    for (var link in _links) {
      if (link.sourceNoteId == noteId) {
        linkedIds.add(link.targetNoteId);
      } else if (link.targetNoteId == noteId) {
        linkedIds.add(link.sourceNoteId);
      }
    }

    return linkedIds.toList();
  }

  // Получение прямых связей (созданных пользователем)
  List<NoteLink> getDirectLinks() {
    return _links.where((link) => link.linkType == LinkType.direct).toList();
  }

  // Получение тематических связей
  List<NoteLink> getThemeLinks() {
    return _links.where((link) => link.linkType == LinkType.theme).toList();
  }

  // Получение связей по дедлайну
  List<NoteLink> getDeadlineLinks() {
    return _links.where((link) => link.linkType == LinkType.deadline).toList();
  }

  // Проверка существования связи между заметками
  bool hasLink(String sourceNoteId, String targetNoteId) {
    return _links.any((link) =>
        (link.sourceNoteId == sourceNoteId &&
            link.targetNoteId == targetNoteId) ||
        (link.sourceNoteId == targetNoteId &&
            link.targetNoteId == sourceNoteId));
  }

  // Создание тематических связей для заметки
  Future<void> createThemeLinksForNote(
      String noteId, List<String> themeIds) async {
    // Сначала удаляем все существующие тематические связи для этой заметки
    final existingThemeLinks = _links
        .where((link) =>
            (link.sourceNoteId == noteId || link.targetNoteId == noteId) &&
            link.linkType == LinkType.theme)
        .toList();

    for (var link in existingThemeLinks) {
      await deleteLink(link.id);
    }

    // Теперь создаем новые связи для каждой темы
    for (var themeId in themeIds) {
      // Получаем все заметки этой темы
      final noteIds = await _databaseService.getNoteIdsForTheme(themeId);

      // Создаем связи между текущей заметкой и всеми заметками этой темы
      for (var otherNoteId in noteIds) {
        if (otherNoteId != noteId && !hasLink(noteId, otherNoteId)) {
          await createLink(
            sourceNoteId: noteId,
            targetNoteId: otherNoteId,
            themeId: themeId,
            linkType: LinkType.theme,
          );
        }
      }
    }
  }

  // Автоматическое создание связей при упоминании в тексте
  Future<List<NoteLink>> createReferenceLinks(
      String noteId, String content) async {
    // Здесь можно добавить логику для поиска упоминаний других заметок в тексте
    // Например, через регулярные выражения или другой механизм

    // Пример: распознавание формата [[Название заметки]] или #ID
    // Этот функционал может быть расширен в будущем

    List<NoteLink> createdLinks = [];
    return createdLinks;
  }
}
