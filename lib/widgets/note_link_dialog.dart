import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../utils/constants.dart';
import 'package:intl/intl.dart';

/// Диалог для выбора заметки и создания связи
class NoteLinkDialog extends StatefulWidget {
  final String sourceNoteId; // ID текущей заметки
  final Function(Note selectedNote) onNoteSelected; // Коллбэк при выборе заметки
  
  const NoteLinkDialog({
    Key? key, 
    required this.sourceNoteId, 
    required this.onNoteSelected,
  }) : super(key: key);

  @override
  State<NoteLinkDialog> createState() => _NoteLinkDialogState();
  
  /// Показать диалог выбора заметки
  static Future<Note?> show(BuildContext context, String sourceNoteId) async {
    return showDialog<Note>(
      context: context,
      builder: (context) => NoteLinkDialog(
        sourceNoteId: sourceNoteId,
        onNoteSelected: (note) {
          Navigator.pop(context, note);
        },
      ),
    );
  }
}

class _NoteLinkDialogState extends State<NoteLinkDialog> {
  String _searchQuery = '';
  int _selectedTabIndex = 0;
  String? _selectedThemeId;
  
  // Контроллер для анимации вкладок
  final PageController _pageController = PageController();
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
      ),
      backgroundColor: AppColors.cardBackground,
      elevation: AppDimens.cardElevation,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(AppDimens.mediumPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок диалога
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Выбор заметки для связи',
                  style: AppTextStyles.heading3,
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            
            // Поле поиска
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppDimens.smallPadding),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Поиск...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.textBackground,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppDimens.buttonBorderRadius),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Вкладки для фильтрации
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: AppDimens.smallPadding),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppDimens.buttonBorderRadius),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTabButton(0, 'Все'),
                  ),
                  Expanded(
                    child: _buildTabButton(1, 'По темам'),
                  ),
                  Expanded(
                    child: _buildTabButton(2, 'Недавние'),
                  ),
                ],
              ),
            ),
            
            // Содержимое вкладок
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedTabIndex = index;
                  });
                },
                children: [
                  // Вкладка "Все заметки"
                  _buildAllNotesTab(),
                  
                  // Вкладка "По темам"
                  _buildThemesTab(),
                  
                  // Вкладка "Недавние"
                  _buildRecentNotesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Кнопка вкладки
  Widget _buildTabButton(int index, String title) {
    final isSelected = _selectedTabIndex == index;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
          _pageController.animateToPage(
            index,
            duration: AppAnimations.shortDuration,
            curve: Curves.easeInOut,
          );
        });
      },
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentSecondary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.buttonBorderRadius),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
  
  // Вкладка "Все заметки"
  Widget _buildAllNotesTab() {
    return Consumer<NotesProvider>(
      builder: (context, notesProvider, _) {
        // Фильтруем заметки
        final filteredNotes = notesProvider.notes
            .where((note) => 
                note.id != widget.sourceNoteId && // Исключаем текущую заметку
                (note.content.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                 _searchQuery.isEmpty)) // Фильтр по поиску
            .toList();
        
        // Сортируем от новых к старым
        filteredNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        return filteredNotes.isEmpty
            ? const Center(
                child: Text('Нет доступных заметок'),
              )
            : ListView.builder(
                itemCount: filteredNotes.length,
                itemBuilder: (context, index) {
                  return _buildNoteItem(filteredNotes[index]);
                },
              );
      },
    );
  }
  
  // Вкладка "По темам"
  Widget _buildThemesTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Выбор темы
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppDimens.smallPadding),
          child: Consumer<ThemesProvider>(
            builder: (context, themesProvider, _) {
              return Wrap(
                spacing: 8.0,
                runSpacing: 4.0,
                children: themesProvider.themes.map((theme) {
                  final isSelected = _selectedThemeId == theme.id;
                  
                  // Парсим цвет из строки
                  Color themeColor;
                  try {
                    themeColor = Color(int.parse(theme.color));
                  } catch (e) {
                    themeColor = Colors.blue; // Дефолтный цвет в случае ошибки
                  }
                  
                  return ActionChip(
                    label: Text(theme.name),
                    backgroundColor: isSelected 
                        ? themeColor.withOpacity(0.7) 
                        : themeColor.withOpacity(0.3),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                    ),
                    onPressed: () {
                      setState(() {
                        if (_selectedThemeId == theme.id) {
                          _selectedThemeId = null; // Отменяем выбор
                        } else {
                          _selectedThemeId = theme.id; // Выбираем тему
                        }
                      });
                    },
                  );
                }).toList(),
              );
            },
          ),
        ),
        
        // Список заметок выбранной темы
        Expanded(
          child: _selectedThemeId == null
              ? const Center(
                  child: Text('Выберите тему для отображения заметок'),
                )
              : Consumer2<NotesProvider, ThemesProvider>(
                  builder: (context, notesProvider, themesProvider, _) {
                    // Получаем тему
                    final theme = themesProvider.themes.firstWhere(
                      (t) => t.id == _selectedThemeId,
                      orElse: () => NoteTheme(
                        id: '',
                        name: '',
                        color: '0xFF000000',
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                        noteIds: [],
                      ),
                    );
                    
                    if (theme.id.isEmpty) {
                      return const Center(
                        child: Text('Тема не найдена'),
                      );
                    }
                    
                    // Получаем заметки этой темы
                    final themeNotes = notesProvider.notes
                        .where((note) => 
                            note.id != widget.sourceNoteId && // Исключаем текущую заметку
                            note.themeIds.contains(theme.id) && // Заметки выбранной темы
                            (note.content.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                             _searchQuery.isEmpty)) // Фильтр по поиску
                        .toList();
                    
                    // Сортируем от новых к старым
                    themeNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
                    
                    return themeNotes.isEmpty
                        ? Center(
                            child: Text('Нет заметок по теме "${theme.name}"'),
                          )
                        : ListView.builder(
                            itemCount: themeNotes.length,
                            itemBuilder: (context, index) {
                              return _buildNoteItem(themeNotes[index]);
                            },
                          );
                  },
                ),
        ),
      ],
    );
  }
  
  // Вкладка "Недавние заметки"
  Widget _buildRecentNotesTab() {
    return Consumer<NotesProvider>(
      builder: (context, notesProvider, _) {
        // Берем 10 последних заметок
        final recentNotes = notesProvider.notes
            .where((note) => 
                note.id != widget.sourceNoteId && // Исключаем текущую заметку
                (note.content.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                 _searchQuery.isEmpty)) // Фильтр по поиску
            .toList();
        
        // Сортируем от новых к старым
        recentNotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        
        // Берем только первые 10
        final limitedNotes = recentNotes.take(10).toList();
        
        return limitedNotes.isEmpty
            ? const Center(
                child: Text('Нет недавних заметок'),
              )
            : ListView.builder(
                itemCount: limitedNotes.length,
                itemBuilder: (context, index) {
                  return _buildNoteItem(limitedNotes[index]);
                },
              );
      },
    );
  }
  
  // Элемент заметки в списке
  Widget _buildNoteItem(Note note) {
    // Определяем цвет бордюра в зависимости от статуса
    final borderColor = _getNoteStatusColor(note);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.cardBackground.withOpacity(0.7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
        side: BorderSide(
          color: borderColor,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          widget.onNoteSelected(note);
        },
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Верхняя часть с датой
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat('d MMMM yyyy').format(note.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textOnDark.withOpacity(0.7),
                    ),
                  ),
                  if (note.hasDeadline && note.deadlineDate != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: borderColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        note.isCompleted
                            ? 'Выполнено'
                            : 'до ${DateFormat('d MMM').format(note.deadlineDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: borderColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              
              // Содержимое заметки
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  note.content,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium,
                ),
              ),
              
              // Темы заметки
              if (note.themeIds.isNotEmpty)
                Consumer<ThemesProvider>(
                  builder: (context, themesProvider, _) {
                    final themes = note.themeIds
                        .map((id) => themesProvider.themes.firstWhere(
                              (t) => t.id == id,
                              orElse: () => NoteTheme(
                                id: '',
                                name: 'Unknown',
                                color: AppColors.themeColors[0].value.toString(),
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                                noteIds: [],
                              ),
                            ))
                        .where((t) => t.id.isNotEmpty)
                        .take(3) // Показываем только первые 3 темы
                        .toList();

                    return Row(
                      children: [
                        ...themes.map((theme) {
                          Color themeColor;
                          try {
                            themeColor = Color(int.parse(theme.color));
                          } catch (e) {
                            themeColor = AppColors.themeColors[0];
                          }

                          return Container(
                            margin: const EdgeInsets.only(right: 4),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: themeColor.withOpacity(0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              theme.name,
                              style: TextStyle(
                                fontSize: 10,
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                        
                        // Индикатор дополнительных тем
                        if (note.themeIds.length > 3)
                          Container(
                            margin: const EdgeInsets.only(left: 2),
                            child: Text(
                              '+${note.themeIds.length - 3}',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textOnDark.withOpacity(0.7),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Определение цвета статуса заметки (такой же как в NotesScreen)
  Color _getNoteStatusColor(Note note) {
    if (note.isCompleted) {
      return AppColors.completed;
    }
    
    if (!note.hasDeadline || note.deadlineDate == null) {
      return AppColors.secondary; // Обычный цвет для заметок без дедлайна
    }
    
    final now = DateTime.now();
    final daysUntilDeadline = note.deadlineDate!.difference(now).inDays;
    
    if (daysUntilDeadline < 0) {
      return AppColors.deadlineUrgent; // Просрочено
    } else if (daysUntilDeadline <= 2) {
      return AppColors.deadlineUrgent; // Срочно (красный)
    } else if (daysUntilDeadline <= 7) {
      return AppColors.deadlineNear; // Скоро (оранжевый)
    } else {
      return AppColors.deadlineFar; // Не срочно (желтый)
    }
  }
}
