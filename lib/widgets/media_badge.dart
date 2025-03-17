import 'package:flutter/material.dart';
import '../utils/constants.dart';

enum MediaBadgeType { image, audio, file, voice, all }

class MediaBadge extends StatelessWidget {
  final MediaBadgeType type;
  final int count;
  final double size;
  final bool showCount;
  final VoidCallback? onTap;

  const MediaBadge({
    Key? key,
    required this.type,
    required this.count,
    this.size = 24.0,
    this.showCount = true,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Определяем цвет и иконку в зависимости от типа
    final IconData iconData;
    final Color badgeColor;

    switch (type) {
      case MediaBadgeType.image:
        iconData = Icons.photo;
        badgeColor = Colors.teal; // Бирюзовый для фото
        break;
      case MediaBadgeType.audio:
        iconData = Icons.audiotrack;
        badgeColor = Colors.purple; // Пурпурный для аудио
        break;
      case MediaBadgeType.voice:
        iconData = Icons.mic;
        badgeColor = Colors.deepPurple; // Тёмно-пурпурный для голосовых
        break;
      case MediaBadgeType.file:
        iconData = Icons.attach_file;
        badgeColor = Colors.blue; // Синий для файлов
        break;
      case MediaBadgeType.all:
        iconData = Icons.apps;
        badgeColor = Colors.grey;
        break;
    }

    // Создаем базовый контейнер с эффектом нажатия
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(size),
        child: Ink(
          decoration: BoxDecoration(
            color: badgeColor.withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: badgeColor.withOpacity(0.5),
              width: 1.0,
            ),
          ),
          child: Stack(
            children: [
              // Основная иконка
              Container(
                width: size,
                height: size,
                padding: EdgeInsets.all(size * 0.2),
                child: Icon(
                  iconData,
                  color: badgeColor,
                  size: size * 0.6,
                ),
              ),

              // Счетчик (если нужен и больше 0)
              if (showCount && count > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      shape: BoxShape.circle,
                    ),
                    constraints: BoxConstraints(
                      minWidth: size * 0.5,
                      minHeight: size * 0.5,
                    ),
                    child: Center(
                      child: Text(
                        count <= 99 ? count.toString() : '99+',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: size * 0.3,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Виджет для отображения группы бейджей
class MediaBadgeGroup extends StatelessWidget {
  final int imagesCount;
  final int audioCount;
  final int voiceCount;
  final int filesCount;
  final double badgeSize;
  final double spacing;
  final bool showEmptyBadges;
  final Function(MediaBadgeType type)? onBadgeTap;

  const MediaBadgeGroup({
    Key? key,
    this.imagesCount = 0,
    this.audioCount = 0,
    this.voiceCount = 0,
    this.filesCount = 0,
    this.badgeSize = 24.0,
    this.spacing = 4.0,
    this.showEmptyBadges = false,
    this.onBadgeTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Widget> badges = [];

    // Аудио и голосовые заметки в один значок (без счетчика)
    if (voiceCount > 0 || audioCount > 0 || showEmptyBadges) {
      badges.add(
        MediaBadge(
          type: MediaBadgeType.voice,
          count: voiceCount + audioCount,
          size: badgeSize,
          showCount: false, // Не показываем счетчик для аудио
          onTap: onBadgeTap != null
              ? () => onBadgeTap!(MediaBadgeType.voice)
              : null,
        ),
      );
    }

    // Для изображений с счетчиком
    if (imagesCount > 0 || showEmptyBadges) {
      badges.add(
        MediaBadge(
          type: MediaBadgeType.image,
          count: imagesCount,
          size: badgeSize,
          showCount: false, // Не показываем счетчик
          onTap: onBadgeTap != null
              ? () => onBadgeTap!(MediaBadgeType.image)
              : null,
        ),
      );
    }

    // Для файлов с счетчиком
    if (filesCount > 0 || showEmptyBadges) {
      badges.add(
        MediaBadge(
          type: MediaBadgeType.file,
          count: filesCount,
          size: badgeSize,
          showCount: false, // Не показываем счетчик
          onTap: onBadgeTap != null
              ? () => onBadgeTap!(MediaBadgeType.file)
              : null,
        ),
      );
    }

    // Отображаем бейджи в ряд с заданным отступом
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: badges.isEmpty
          ? []
          : List.generate(badges.length * 2 - 1, (index) {
              if (index.isEven) {
                return badges[index ~/ 2];
              } else {
                return SizedBox(width: spacing);
              }
            }),
    );
  }
}
