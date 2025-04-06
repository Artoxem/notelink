import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Виджет для выбора эмодзи
class EmojiSelector extends StatefulWidget {
  /// Текущий выбранный эмодзи
  final String? selectedEmoji;

  /// Callback при выборе эмодзи
  final ValueChanged<String>? onEmojiSelected;

  /// Показывать ли кнопку очистки
  final bool showClearButton;

  const EmojiSelector({
    Key? key,
    this.selectedEmoji,
    this.onEmojiSelected,
    this.showClearButton = true,
  }) : super(key: key);

  @override
  State<EmojiSelector> createState() => _EmojiSelectorState();
}

class _EmojiSelectorState extends State<EmojiSelector> {
  // Наиболее распространенные категории эмодзи с популярными эмодзи
  final List<EmojiCategory> _categories = [
    EmojiCategory(
      name: 'Частые',
      icon: Icons.access_time,
      emojis: ['😀', '👍', '❤️', '🔥', '⭐', '🎉', '✅', '🚀', '💯', '🙏'],
    ),
    EmojiCategory(
      name: 'Смайлы',
      icon: Icons.emoji_emotions,
      emojis: [
        '😀',
        '😃',
        '😄',
        '😁',
        '😆',
        '😅',
        '🤣',
        '😂',
        '🙂',
        '🙃',
        '😉',
        '😊',
        '😇',
        '🥰',
        '😍',
        '🤩',
        '😘',
        '😗',
        '☺️',
        '😚',
        '😙',
        '🥲',
        '😋',
        '😛',
        '😜',
        '🤪',
        '😝',
        '🤑',
        '🤗',
        '🤭',
      ],
    ),
    EmojiCategory(
      name: 'Жесты',
      icon: Icons.back_hand,
      emojis: [
        '👍',
        '👎',
        '👌',
        '🤌',
        '🤏',
        '✌️',
        '🤞',
        '🤟',
        '🤘',
        '🤙',
        '👈',
        '👉',
        '👆',
        '🖕',
        '👇',
        '☝️',
        '👋',
        '🤚',
        '🖐️',
        '✋',
        '🖖',
        '👏',
        '🙌',
        '👐',
        '🤲',
        '🤝',
        '🙏',
        '✍️',
        '💅',
        '🤳',
      ],
    ),
    EmojiCategory(
      name: 'Символы',
      icon: Icons.emoji_symbols,
      emojis: [
        '❤️',
        '🧡',
        '💛',
        '💚',
        '💙',
        '💜',
        '🖤',
        '🤍',
        '🤎',
        '💔',
        '❣️',
        '💕',
        '💞',
        '💓',
        '💗',
        '💖',
        '💘',
        '💝',
        '💟',
        '☮️',
        '✝️',
        '☪️',
        '🕉️',
        '☸️',
        '✡️',
        '🔯',
        '🕎',
        '☯️',
        '☦️',
        '🛐',
      ],
    ),
    EmojiCategory(
      name: 'Объекты',
      icon: Icons.emoji_objects,
      emojis: [
        '🔥',
        '💧',
        '🌊',
        '⭐',
        '🌟',
        '💫',
        '✨',
        '⚡',
        '☄️',
        '💥',
        '🌈',
        '💠',
        '⚜️',
        '🔱',
        '📱',
        '💻',
        '⌨️',
        '🖥️',
        '🖨️',
        '💿',
        '💾',
        '💽',
        '🎮',
        '🕹️',
        '🎲',
        '🎭',
        '🎨',
        '🎤',
        '🎧',
        '🎵',
      ],
    ),
  ];

  int _selectedCategoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
        boxShadow: [AppShadows.small],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Заголовок с текущим выбранным эмодзи
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Выберите эмодзи',
                  style: AppTextStyles.bodyMedium,
                ),
                if (widget.showClearButton && widget.selectedEmoji != null)
                  IconButton(
                    onPressed: () {
                      if (widget.onEmojiSelected != null) {
                        widget.onEmojiSelected!('');
                      }
                    },
                    icon: const Icon(Icons.clear, size: 18),
                    tooltip: 'Очистить',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
              ],
            ),
          ),

          // Вкладки для категорий
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategoryIndex == index;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategoryIndex = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isSelected
                              ? AppColors.accentPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category.icon,
                          color: isSelected
                              ? AppColors.accentPrimary
                              : AppColors.textOnLight.withOpacity(0.7),
                          size: 20,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.name,
                          style: TextStyle(
                            fontSize: 12,
                            color: isSelected
                                ? AppColors.accentPrimary
                                : AppColors.textOnLight.withOpacity(0.7),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Сетка эмодзи
          Container(
            constraints: const BoxConstraints(
              maxHeight: 240,
            ),
            padding: const EdgeInsets.all(8.0),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                childAspectRatio: 1.0,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: _categories[_selectedCategoryIndex].emojis.length,
              itemBuilder: (context, index) {
                final emoji = _categories[_selectedCategoryIndex].emojis[index];
                final isSelected = widget.selectedEmoji == emoji;

                return InkWell(
                  onTap: () {
                    if (widget.onEmojiSelected != null) {
                      widget.onEmojiSelected!(emoji);
                    }
                  },
                  borderRadius:
                      BorderRadius.circular(AppDimens.smallBorderRadius),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentPrimary.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(AppDimens.smallBorderRadius),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.accentPrimary
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Класс категории эмодзи
class EmojiCategory {
  /// Название категории
  final String name;

  /// Иконка категории
  final IconData icon;

  /// Список эмодзи в категории
  final List<String> emojis;

  EmojiCategory({
    required this.name,
    required this.icon,
    required this.emojis,
  });
}

/// Диалог выбора эмодзи
class EmojiPickerDialog {
  /// Показывает диалог выбора эмодзи
  static Future<String?> show({
    required BuildContext context,
    String? initialEmoji,
  }) async {
    return await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
          ),
          child: StatefulBuilder(
            builder: (context, setState) {
              String? selectedEmoji = initialEmoji;

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  EmojiSelector(
                    selectedEmoji: selectedEmoji,
                    onEmojiSelected: (emoji) {
                      selectedEmoji = emoji.isEmpty ? null : emoji;
                      setState(() {});
                    },
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          child: const Text('Отмена'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop(selectedEmoji);
                          },
                          child: const Text('Выбрать'),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
