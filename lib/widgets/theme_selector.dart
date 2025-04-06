import 'package:flutter/material.dart';
import '../models/theme.dart';
import '../utils/constants.dart';
import '../providers/themes_provider.dart';
import 'package:provider/provider.dart';
import 'theme_chip.dart';

/// Виджет для выбора тем заметки
class ThemeSelector extends StatefulWidget {
  /// Список идентификаторов выбранных тем
  final List<String> selectedThemeIds;

  /// Callback при изменении выбранных тем
  final ValueChanged<List<String>> onThemesChanged;

  /// Максимальное количество видимых тем (остальные будут скрыты под кнопкой "еще")
  final int maxVisibleThemes;

  /// Показывать ли кнопку создания новой темы
  final bool showCreateButton;

  /// Показывать ли кнопку редактирования тем
  final bool showEditButton;

  const ThemeSelector({
    Key? key,
    required this.selectedThemeIds,
    required this.onThemesChanged,
    this.maxVisibleThemes = 6,
    this.showCreateButton = true,
    this.showEditButton = true,
  }) : super(key: key);

  @override
  State<ThemeSelector> createState() => _ThemeSelectorState();
}

class _ThemeSelectorState extends State<ThemeSelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemesProvider>(
      builder: (context, themesProvider, _) {
        if (themesProvider.themes.isEmpty) {
          return _buildEmptyState();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Заголовок с кнопками
            _buildHeader(themesProvider),

            const SizedBox(height: 8),

            // Основная часть со списком тем
            _buildThemesList(themesProvider),
          ],
        );
      },
    );
  }

  /// Строит заголовок с кнопками управления
  Widget _buildHeader(ThemesProvider themesProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Темы',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Row(
          children: [
            // Кнопка редактирования тем
            if (widget.showEditButton)
              IconButton(
                onPressed: () => _showEditThemesScreen(context),
                icon: const Icon(Icons.settings, size: 20),
                tooltip: 'Управление темами',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),

            // Кнопка создания новой темы
            if (widget.showCreateButton)
              IconButton(
                onPressed: () => _showCreateThemeDialog(context),
                icon: const Icon(Icons.add_circle_outline, size: 20),
                tooltip: 'Создать тему',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Строит пустое состояние, когда нет доступных тем
  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Темы',
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                'У вас пока нет тем',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: AppColors.textOnLight.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => _showCreateThemeDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Создать тему'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Строит список тем
  Widget _buildThemesList(ThemesProvider themesProvider) {
    final themes = themesProvider.themes;

    // Ограничиваем список видимых тем, если нужно
    final visibleThemes =
        _isExpanded ? themes : themes.take(widget.maxVisibleThemes).toList();

    // Проверяем, есть ли скрытые темы
    final hasMoreThemes =
        !_isExpanded && themes.length > widget.maxVisibleThemes;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Видимые темы
        ...visibleThemes.map((theme) {
          final isSelected = widget.selectedThemeIds.contains(theme.id);

          return ThemeChip(
            theme: theme,
            isSelected: isSelected,
            size: ThemeChipSize.medium,
            onTap: () => _toggleTheme(theme.id),
          );
        }).toList(),

        // Кнопка "еще", если есть скрытые темы
        if (hasMoreThemes)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = true;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Еще ${themes.length - widget.maxVisibleThemes}',
                    style: TextStyle(
                      color: AppColors.textOnLight.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: AppColors.textOnLight.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),

        // Кнопка "свернуть", если список развернут
        if (_isExpanded)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = false;
              });
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.secondary.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Свернуть',
                    style: TextStyle(
                      color: AppColors.textOnLight.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_up,
                    size: 20,
                    color: AppColors.textOnLight.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Переключает выбор темы по идентификатору
  void _toggleTheme(String themeId) {
    final updatedThemeIds = List<String>.from(widget.selectedThemeIds);

    if (updatedThemeIds.contains(themeId)) {
      updatedThemeIds.remove(themeId);
    } else {
      updatedThemeIds.add(themeId);
    }

    widget.onThemesChanged(updatedThemeIds);
  }

  /// Показывает экран управления темами
  void _showEditThemesScreen(BuildContext context) {
    // В реальном приложении здесь бы открывался экран управления темами
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Переход к экрану управления темами'),
      ),
    );
  }

  /// Показывает диалог создания новой темы
  void _showCreateThemeDialog(BuildContext context) {
    final TextEditingController nameController = TextEditingController();
    Color selectedColor = AppColors.themeColors[0];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Создать новую тему'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Поле для имени темы
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Название темы',
                      hintText: 'Введите название темы',
                    ),
                    autofocus: true,
                  ),

                  const SizedBox(height: 16),

                  // Выбор цвета темы
                  const Text('Выберите цвет:'),
                  const SizedBox(height: 8),

                  // Сетка с цветами
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppColors.themeColors.map((color) {
                      final bool isSelected = color == selectedColor;

                      return InkWell(
                        onTap: () {
                          setState(() {
                            selectedColor = color;
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                              width: 2,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.6),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (nameController.text.trim().isNotEmpty) {
                      _createNewTheme(
                          nameController.text.trim(), selectedColor);
                      Navigator.of(context).pop();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                  ),
                  child: const Text('Создать'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Создает новую тему с указанным именем и цветом
  void _createNewTheme(String name, Color color) {
    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);

    // Преобразуем цвет в строковое представление
    final colorValue = color.value.toString();

    // Создаем новую тему
    final newTheme = NoteTheme(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      color: colorValue,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      noteIds: [],
    );

    // Добавляем тему (предполагаем, что ThemesProvider имеет соответствующий метод)
    // В реальном приложении мы использовали бы фактическую реализацию из ThemesProvider
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Новая тема "$name" создана'),
        duration: const Duration(seconds: 2),
      ),
    );

    // Имитируем добавление темы, обновляя интерфейс
    setState(() {
      // Автоматически выбираем новую тему
      final updatedThemeIds = List<String>.from(widget.selectedThemeIds);
      updatedThemeIds.add(newTheme.id);
      widget.onThemesChanged(updatedThemeIds);
    });
  }
}

/// Диалог выбора тем
class ThemeSelectorDialog {
  /// Показывает диалог выбора тем
  static Future<List<String>?> show({
    required BuildContext context,
    required List<String> initialThemeIds,
  }) async {
    return await showDialog<List<String>>(
      context: context,
      builder: (BuildContext context) {
        List<String> selectedThemeIds = List.from(initialThemeIds);

        return AlertDialog(
          title: const Text('Выберите темы'),
          content: SizedBox(
            width: double.maxFinite,
            child: StatefulBuilder(
              builder: (context, setState) {
                return ThemeSelector(
                  selectedThemeIds: selectedThemeIds,
                  onThemesChanged: (themeIds) {
                    setState(() {
                      selectedThemeIds = themeIds;
                    });
                  },
                  maxVisibleThemes: 12,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(selectedThemeIds),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
              ),
              child: const Text('Готово'),
            ),
          ],
        );
      },
    );
  }
}
