import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/themes_provider.dart';
import 'theme_detail_screen.dart';
import '../models/note.dart';
import '../utils/constants.dart';

class ThemesScreen extends StatefulWidget {
  const ThemesScreen({super.key});

  static void showAddThemeDialog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ThemeDetailScreen(),
      ),
    );
  }

  @override
  State<ThemesScreen> createState() => _ThemesScreenState();
}

class _ThemesScreenState extends State<ThemesScreen> {
  @override
  void initState() {
    super.initState();
    // Загружаем темы при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ThemesProvider>(context, listen: false).loadThemes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        if (themesProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (themesProvider.themes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.link_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No themes yet',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create your first theme to link notes',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ThemeDetailScreen(),
                      ),
                    ).then((_) {
                      // Перезагружаем темы после возврата
                      if (mounted) {
                        themesProvider.loadThemes();
                      }
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Create Theme'),
                ),
              ],
            ),
          );
        }

        // Предварительно загружаем заметки для каждой темы
        // для улучшения отзывчивости интерфейса
        final Map<String, Future<List<Note>>> themeNotesFutures = {};
        for (final theme in themesProvider.themes) {
          themeNotesFutures[theme.id] =
              themesProvider.getNotesForTheme(theme.id);
        }

        // Отображаем список тем
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: themesProvider.themes.length,
          itemBuilder: (context, index) {
            final theme = themesProvider.themes[index];

            // Парсим цвет из строки
            Color themeColor;
            try {
              themeColor = Color(int.parse(theme.color));
            } catch (e) {
              themeColor = Colors.blue; // Дефолтный цвет в случае ошибки
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 2,
              color: AppColors.cardBackground, // White Asparagus
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: themeColor.withOpacity(0.6),
                  width: 2,
                ),
              ),
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ThemeDetailScreen(theme: theme),
                    ),
                  ).then((_) {
                    // Перезагружаем темы после возврата
                    if (mounted) {
                      themesProvider.loadThemes();
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize
                        .min, // Добавлено, чтобы колонка брала минимальную высоту
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: themeColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.link,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min, // Добавлено
                              children: [
                                Text(
                                  theme.name,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        AppColors.textOnLight, // Зеленый текст
                                  ),
                                ),
                                if (theme.description != null &&
                                    theme.description!.isNotEmpty)
                                  Text(
                                    theme.description!,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textOnLight
                                          .withOpacity(0.8),
                                      fontWeight: FontWeight.normal,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${theme.noteIds.length} notes',
                              style: TextStyle(
                                color: themeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (theme.noteIds.isNotEmpty)
                        FutureBuilder<List<Note>>(
                          future: themeNotesFutures[theme.id],
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const SizedBox(
                                height: 40,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }

                            if (!snapshot.hasData || snapshot.data!.isEmpty) {
                              return const SizedBox();
                            }

                            final notes = snapshot.data!;
                            final previewNotes = notes.take(3).toList();

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min, // Добавлено
                              children: [
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                Text(
                                  'Linked Notes:',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textOnLight,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...previewNotes
                                    .map((note) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 4),
                                          child: Row(
                                            mainAxisSize:
                                                MainAxisSize.min, // Добавлено
                                            children: [
                                              Icon(Icons.note,
                                                  size: 14, color: themeColor),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  note.previewText,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color:
                                                        AppColors.textOnLight,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                                if (notes.length > 3)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      '+ ${notes.length - 3} more',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textOnLight
                                            .withOpacity(0.7),
                                        fontStyle: FontStyle.italic,
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
          },
        );
      },
    );
  }
}
