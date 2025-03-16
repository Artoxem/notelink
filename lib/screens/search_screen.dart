import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/theme.dart'; // Добавьте этот импорт
import '../providers/notes_provider.dart';
import '../providers/app_provider.dart';
import '../providers/themes_provider.dart'; // Убедитесь, что этот импорт тоже есть
import '../utils/constants.dart';
import 'note_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Note> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      if (_searchQuery.trim().isEmpty) {
        _searchResults = [];
        _isSearching = false;
      } else {
        _isSearching = true;
        _performSearch();
      }
    });
  }

// Добавление метода для обработки Markdown в класс _SearchScreenState
// Скопируем регулярные выражения и метод из notes_screen.dart

// Регулярные выражения для обработки Markdown
  final RegExp _headingsRegex = RegExp(r'#{1,6}\s+');
  final RegExp _boldRegex = RegExp(r'\*\*|__');
  final RegExp _italicRegex = RegExp(r'\*|_(?!\*)');
  final RegExp _linksRegex = RegExp(r'\[([^\]]+)\]\([^)]+\)');
  final RegExp _codeRegex = RegExp(r'`[^`]+`');
  final RegExp _voiceRegex = RegExp(r'!\[voice\]\(voice:[^)]+\)');

// Улучшенное создание превью из Markdown-текста
  String _createPreviewFromMarkdown(String markdown, int maxLength) {
    if (markdown.isEmpty) {
      return '';
    }

    // Предварительная проверка наличия разметки для оптимизации производительности
    bool hasMarkdown = _headingsRegex.hasMatch(markdown) ||
        _boldRegex.hasMatch(markdown) ||
        _italicRegex.hasMatch(markdown) ||
        _linksRegex.hasMatch(markdown) ||
        _codeRegex.hasMatch(markdown);

    if (!hasMarkdown) {
      // Если разметки нет, просто обрезаем текст,
      // но сначала удаляем ссылки на голосовые заметки
      String cleanText = markdown.replaceAll(_voiceRegex, '');
      return cleanText.length > maxLength
          ? '${cleanText.substring(0, maxLength)}...'
          : cleanText;
    }

    // Последовательно удаляем разметку
    String text = markdown;

    // Удаляем голосовые заметки полностью
    text = text.replaceAll(_voiceRegex, '');

    // Заменяем ссылки их текстовым представлением
    text = text.replaceAllMapped(_linksRegex, (match) => match.group(1) ?? '');

    // Удаляем заголовки
    text = text.replaceAll(_headingsRegex, '');

    // Удаляем разметку жирного и курсивного текста
    text = text.replaceAll(_boldRegex, '');
    text = text.replaceAll(_italicRegex, '');

    // Удаляем разметку кода
    text = text.replaceAllMapped(_codeRegex, (match) {
      final code = match.group(0) ?? '';
      return code.length > 2 ? code.substring(1, code.length - 1) : '';
    });

    // Обрезаем по максимальной длине
    if (text.length > maxLength) {
      text = '${text.substring(0, maxLength)}...';
    }

    return text;
  }

// Обновлённый метод построения для результатов поиска
  Widget _buildSearchResultCard(Note note) {
    // Определяем цвет индикатора в зависимости от статуса и темы
    Color indicatorColor;
    if (note.isCompleted) {
      indicatorColor = AppColors.completed;
    } else if (note.hasDeadline && note.deadlineDate != null) {
      final now = DateTime.now();
      final daysUntilDeadline = note.deadlineDate!.difference(now).inDays;

      if (daysUntilDeadline < 0) {
        indicatorColor = AppColors.deadlineUrgent; // Просрочено
      } else if (daysUntilDeadline <= 2) {
        indicatorColor = AppColors.deadlineUrgent; // Срочно
      } else if (daysUntilDeadline <= 7) {
        indicatorColor = AppColors.deadlineNear; // Скоро
      } else {
        indicatorColor = AppColors.deadlineFar; // Не срочно
      }
    } else if (note.themeIds.isNotEmpty) {
      // Используем цвет первой темы заметки
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      final themeId = note.themeIds.first;
      final theme = themesProvider.themes.firstWhere(
        (t) => t.id == themeId,
        orElse: () => NoteTheme(
          id: '',
          name: 'Без темы',
          color: AppColors.themeColors[0].value.toString(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteIds: [],
        ),
      );
      try {
        indicatorColor = Color(int.parse(theme.color));
      } catch (e) {
        indicatorColor = AppColors.themeColors[0];
      }
    } else {
      indicatorColor = AppColors.secondary; // Обычный цвет
    }

    // Преобразуем контент с учётом markdown форматирования
    final String formattedContent =
        _createPreviewFromMarkdown(note.content, 250);

    // Ищем совпадения для подсветки
    final List<TextSpan> highlightedContent = _highlightOccurrences(
      formattedContent,
      _searchQuery,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: AppDimens.mediumPadding),
      elevation: AppDimens.cardElevation,
      color: AppColors.cardBackground, // White Asparagus
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoteDetailScreen(note: note),
            ),
          ).then((_) {
            // Обновляем результаты поиска после возврата с экрана редактирования
            if (_isSearching) {
              _performSearch();
            }
          });
        },
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
        child: Row(
          children: [
            // Цветной индикатор слева
            Container(
              width: 6,
              height: double.infinity,
              decoration: BoxDecoration(
                color: indicatorColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppDimens.cardBorderRadius),
                  bottomLeft: Radius.circular(AppDimens.cardBorderRadius),
                ),
              ),
            ),
            // Основное содержимое
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppDimens.mediumPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Информация о дате
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          note.createdAt.toString().substring(0, 10),
                          style: AppTextStyles.bodySmallLight,
                        ),
                        if (note.hasDeadline && note.deadlineDate != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: note.isCompleted
                                  ? AppColors.deadlineBgGray
                                  : AppColors.deadlineBgGreen,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Дедлайн: ${note.deadlineDate.toString().substring(0, 10)}',
                              style: AppTextStyles.deadlineText,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: AppDimens.smallPadding),

                    // Подсвеченное содержимое
                    RichText(
                      text: TextSpan(
                        children: highlightedContent,
                      ),
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: AppDimens.smallPadding),

                    // Индикаторы медиаконтента, тегов и т.д.
                    if (note.mediaUrls.isNotEmpty || note.themeIds.isNotEmpty)
                      Row(
                        children: [
                          if (note.hasImages)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.photo,
                                  size: 16, color: AppColors.textOnLight),
                            ),
                          if (note.hasAudio)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.mic,
                                  size: 16, color: AppColors.textOnLight),
                            ),
                          if (note.hasFiles)
                            const Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.attach_file,
                                  size: 16, color: AppColors.textOnLight),
                            ),
                          if (note.themeIds.isNotEmpty)
                            Expanded(
                              child: FutureBuilder(
                                future: _getThemeNames(note.themeIds),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return const SizedBox();
                                  }

                                  List<String> themeNames = snapshot.data!;
                                  return Text(
                                    'Темы: ${themeNames.join(", ")}',
                                    style: AppTextStyles.bodySmallLight,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _performSearch() {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final query = _searchQuery.toLowerCase();

    setState(() {
      _searchResults = notesProvider.notes.where((note) {
        // Поиск в содержимом заметки
        return note.content.toLowerCase().contains(query);
      }).toList();
    });

    // Добавляем запрос в историю поиска (если не пустой)
    if (query.isNotEmpty) {
      Provider.of<AppProvider>(context, listen: false)
          .addToSearchHistory(query);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _selectHistoryItem(String query) {
    _searchController.text = query;
    // Установка курсора в конец текста
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: query.length),
    );
    _performSearch();
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Поиск'),
        actions: [
          if (_isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: _clearSearch,
            ),
        ],
      ),
      body: Column(
        children: [
          // Поле поиска
          Padding(
            padding: const EdgeInsets.all(AppDimens.mediumPadding),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
                boxShadow: [AppShadows.small],
              ),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: AppTextStyles.bodyMediumLight,
                decoration: InputDecoration(
                  hintText: 'Поиск по заметкам...',
                  prefixIcon:
                      const Icon(Icons.search, color: AppColors.accentPrimary),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.mediumPadding,
                    vertical: AppDimens.smallPadding,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  // Дополнительные действия при отправке поискового запроса
                },
              ),
            ),
          ),

          // История поиска
          if (_searchQuery.isEmpty &&
              appProvider.showSearchHistory &&
              appProvider.searchHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.mediumPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'История поиска',
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          appProvider.clearSearchHistory();
                        },
                        child: const Text('Очистить'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimens.smallPadding),
                  Wrap(
                    spacing: AppDimens.smallPadding,
                    runSpacing: AppDimens.smallPadding,
                    children: appProvider.searchHistory.map((query) {
                      return Chip(
                        backgroundColor: AppColors.secondary.withOpacity(0.7),
                        label: Text(query, style: AppTextStyles.bodySmall),
                        onDeleted: () {
                          appProvider.removeFromSearchHistory(query);
                        },
                        deleteIcon: const Icon(Icons.clear, size: 16),
                        padding: const EdgeInsets.all(4),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ).paddedChip(
                        onTap: () => _selectHistoryItem(query),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // Индикатор загрузки или результаты поиска
          Expanded(
            child: _isSearching
                ? _searchResults.isEmpty
                    ? const Center(
                        child: Text('Ничего не найдено',
                            style: AppTextStyles.bodyLarge),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(AppDimens.mediumPadding),
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final note = _searchResults[index];
                          return _buildSearchResultCard(note);
                        },
                      )
                : const Center(
                    child: Text('Введите текст для поиска',
                        style: AppTextStyles.bodyLarge),
                  ),
          ),
        ],
      ),
    );
  }

  List<TextSpan> _highlightOccurrences(String text, String query) {
    if (query.isEmpty) {
      return [
        TextSpan(text: text, style: AppTextStyles.bodyMediumLight)
      ]; // Темный текст
    }

    final List<TextSpan> spans = [];
    final String lowercaseText = text.toLowerCase();
    final String lowercaseQuery = query.toLowerCase();

    int lastIndex = 0;
    int currentIndex = lowercaseText.indexOf(lowercaseQuery, lastIndex);

    while (currentIndex != -1) {
      // Добавляем текст до совпадения
      if (currentIndex > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, currentIndex),
          style: AppTextStyles.bodyMediumLight, // Темный текст
        ));
      }

      // Добавляем подсвеченное совпадение
      spans.add(TextSpan(
        text: text.substring(currentIndex, currentIndex + query.length),
        style: AppTextStyles.bodyMediumLight.copyWith(
          backgroundColor: AppColors.accentSecondary.withOpacity(0.3),
          fontWeight: FontWeight.bold,
        ),
      ));

      // Обновляем индексы
      lastIndex = currentIndex + query.length;
      currentIndex = lowercaseText.indexOf(lowercaseQuery, lastIndex);
    }

    // Добавляем оставшийся текст
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: AppTextStyles.bodyMediumLight, // Темный текст
      ));
    }

    return spans;
  }

  Future<List<String>> _getThemeNames(List<String> themeIds) async {
    // Здесь можно было бы получить имена тем из ThemesProvider,
    // но для упрощения просто возвращаем список идентификаторов
    // В реальном приложении этот метод должен быть реализован
    return themeIds;
  }
}

// Расширение для Chip, чтобы сделать его кликабельным
extension ChipExtension on Chip {
  Widget paddedChip({required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimens.chipBorderRadius),
      child: this,
    );
  }
}
