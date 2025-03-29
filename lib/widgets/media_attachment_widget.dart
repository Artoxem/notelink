// Изменения в файле lib/widgets/media_attachment_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/constants.dart';
import '../services/media_service.dart';
import 'package:path/path.dart' as path;

// Обновляем класс MediaAttachmentWidget для добавления колбэка на нажатие
class MediaAttachmentWidget extends StatelessWidget {
  final String mediaPath;
  final VoidCallback onRemove;
  final bool isEditing;
  final VoidCallback? onTap; // Новый колбэк для обработки нажатия

  const MediaAttachmentWidget({
    Key? key,
    required this.mediaPath,
    required this.onRemove,
    this.isEditing = true,
    this.onTap, // Добавляем новый параметр
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mediaService = MediaService();
    final bool isImage = mediaService.isImage(mediaPath);
    final fileName = mediaService.getFileNameFromPath(mediaPath);
    final extension = mediaService.getFileExtension(mediaPath);

    // Проверяем существование файла
    final file = File(mediaPath);
    final bool fileExists = file.existsSync();

    if (!fileExists) {
      return _buildErrorWidget(context);
    }

    if (isImage) {
      return _buildImageWidget(file, context);
    } else {
      return _buildFileWidget(fileName, extension, context);
    }
  }

  Widget _buildErrorWidget(BuildContext context) {
    return GestureDetector(
      onTap: onTap, // Используем переданный колбэк
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(6), // Уменьшен отступ с 8 до 6
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: Colors.red, size: 20), // Уменьшен размер с 24 до 20
            const SizedBox(width: 6), // Уменьшен отступ с 8 до 6
            const Expanded(
              child: Text(
                'Файл не найден',
                style: TextStyle(
                    color: Colors.red, fontSize: 12), // Уменьшен размер шрифта
              ),
            ),
            if (isEditing)
              IconButton(
                icon: const Icon(Icons.close,
                    size: 16, color: Colors.red), // Уменьшен размер с 20 до 16
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageWidget(File file, BuildContext context) {
    return GestureDetector(
      onTap: onTap ??
          () => _showImagePreview(
              context, file), // Используем колбэк или показываем превью
      onLongPress: isEditing ? () => _showFileOptions(context) : null,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 1.0, // Всегда квадратное соотношение сторон
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[300],
                      alignment: Alignment.center,
                      child: const Text('Ошибка загрузки',
                          style: TextStyle(fontSize: 12)),
                    );
                  },
                ),
              ),
            ),
          ),
          if (isEditing)
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.white,
                      size: 14), // Уменьшен размер с 16 до 14
                  padding: const EdgeInsets.all(2), // Уменьшен отступ с 4 до 2
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFileWidget(
      String fileName, String extension, BuildContext context) {
    Color iconColor;
    IconData fileIcon;

    // Определяем иконку в зависимости от типа файла
    switch (extension) {
      case '.pdf':
        iconColor = Colors.red;
        fileIcon = Icons.picture_as_pdf;
        break;
      case '.doc':
      case '.docx':
        iconColor = Colors.blue;
        fileIcon = Icons.description;
        break;
      case '.xls':
      case '.xlsx':
        iconColor = Colors.green;
        fileIcon = Icons.table_chart;
        break;
      case '.mp3':
      case '.wav':
      case '.m4a':
        iconColor = Colors.purple;
        fileIcon = Icons.music_note;
        break;
      case '.mp4':
      case '.mov':
      case '.avi':
        iconColor = Colors.orange;
        fileIcon = Icons.video_file;
        break;
      default:
        iconColor = Colors.grey;
        fileIcon = Icons.insert_drive_file;
    }

    return GestureDetector(
      onTap: onTap ??
          () => _showFilePreview(context, fileName,
              extension), // Используем колбэк или показываем превью
      onLongPress: () => _showFileOptions(context),
      child: Card(
        elevation: 1, // Уменьшена тень
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        margin: EdgeInsets.zero, // Убраны внешние отступы
        child: Padding(
          padding: const EdgeInsets.all(8.0), // Уменьшены отступы с 12 до 8
          child: Row(
            children: [
              // Иконка файла с фоном
              Container(
                padding: const EdgeInsets.all(6), // Уменьшены отступы с 10 до 6
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  fileIcon,
                  color: iconColor,
                  size: 20, // Уменьшен размер с 28 до 20
                ),
              ),

              const SizedBox(width: 8), // Уменьшен отступ с 16 до 8

              // Информация о файле
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fileName.length > 20
                          ? '${fileName.substring(0, 17)}...' // Ещё более компактное имя файла
                          : fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // Уменьшен шрифт с 14 до 12
                      ),
                    ),
                    const SizedBox(height: 2), // Уменьшен отступ с 4 до 2
                    Text(
                      extension.toUpperCase().substring(1),
                      style: TextStyle(
                        fontSize: 10, // Уменьшен шрифт с 12 до 10
                        color: AppColors.textOnLight.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Кнопка удаления (если в режиме редактирования)
              if (isEditing)
                IconButton(
                  icon: const Icon(Icons.close,
                      size: 16), // Уменьшен размер с 20 до 16
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Улучшенный метод для показа предпросмотра изображения
  void _showImagePreview(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Изображение с InteractiveViewer для зума
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  alignment: Alignment.center,
                  child: Image.file(
                    file,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(Icons.broken_image,
                            size: 48, color: Colors.white),
                      );
                    },
                  ),
                ),
              ),
            ),
            // Кнопки управления
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 20,
              child: FloatingActionButton(
                heroTag: 'openImageExternalFAB',
                backgroundColor: AppColors.accentSecondary,
                mini: true,
                child: const Icon(Icons.open_in_new, color: Colors.white),
                onPressed: () async {
                  Navigator.of(context).pop();
                  await _openFileExternally(context, mediaPath);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Улучшенный метод для показа предпросмотра файла
  void _showFilePreview(
      BuildContext context, String fileName, String extension) {
    final mediaService = MediaService();

    // Определяем иконку и цвет на основе расширения
    IconData fileIcon;
    Color iconColor;

    switch (extension) {
      case '.pdf':
        fileIcon = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case '.doc':
      case '.docx':
        fileIcon = Icons.description;
        iconColor = Colors.blue;
        break;
      case '.xls':
      case '.xlsx':
        fileIcon = Icons.table_chart;
        iconColor = Colors.green;
        break;
      case '.mp3':
      case '.wav':
      case '.m4a':
        fileIcon = Icons.music_note;
        iconColor = Colors.purple;
        break;
      case '.mp4':
      case '.mov':
      case '.avi':
        fileIcon = Icons.video_file;
        iconColor = Colors.orange;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        iconColor = Colors.grey;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileName,
            style: const TextStyle(fontSize: 16)), // Уменьшен размер шрифта
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Иконка файла с фоном
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                fileIcon,
                size: 48,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 16),
            Text('Тип файла: ${extension.toUpperCase().substring(1)}',
                style: const TextStyle(fontSize: 14)), // Уменьшен размер шрифта
            const SizedBox(height: 8),
            const Text('Предпросмотр недоступен для этого типа файла.',
                style: TextStyle(fontSize: 14)), // Уменьшен размер шрифта
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _openFileExternally(context, mediaPath);
            },
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }

  // Метод для показа опций файла с улучшенным интерфейсом
  void _showFileOptions(BuildContext context) {
    final mediaService = MediaService();
    final fileName = mediaService.getFileNameFromPath(mediaPath);
    final extension = mediaService.getFileExtension(mediaPath);

    // Определяем тип файла для заголовка
    String fileType;
    switch (extension) {
      case '.jpg':
      case '.jpeg':
      case '.png':
      case '.gif':
        fileType = 'Изображение';
        break;
      case '.pdf':
        fileType = 'PDF документ';
        break;
      case '.doc':
      case '.docx':
        fileType = 'Word документ';
        break;
      case '.xls':
      case '.xlsx':
        fileType = 'Excel таблица';
        break;
      case '.mp3':
      case '.wav':
      case '.m4a':
        fileType = 'Аудиофайл';
        break;
      case '.mp4':
      case '.mov':
      case '.avi':
        fileType = 'Видеофайл';
        break;
      default:
        fileType = 'Файл';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileType,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fileName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new,
                  size: 20), // Уменьшен размер иконки
              title: const Text('Открыть',
                  style: TextStyle(fontSize: 14)), // Уменьшен шрифт
              dense: true, // Компактный вид
              onTap: () {
                Navigator.pop(context);
                _openFileExternally(context, mediaPath);
              },
            ),
            if (isEditing)
              ListTile(
                leading: const Icon(Icons.delete,
                    color: Colors.red, size: 20), // Уменьшен размер иконки
                title: const Text('Удалить',
                    style: TextStyle(
                        color: Colors.red, fontSize: 14)), // Уменьшен шрифт
                dense: true, // Компактный вид
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
            ListTile(
              leading:
                  const Icon(Icons.close, size: 20), // Уменьшен размер иконки
              title: const Text('Отмена',
                  style: TextStyle(fontSize: 14)), // Уменьшен шрифт
              dense: true, // Компактный вид
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Метод для открытия файла во внешнем приложении
  Future<void> _openFileExternally(
      BuildContext context, String filePath) async {
    final file = File(filePath);

    if (await file.exists()) {
      try {
        final uri = Uri.file(filePath);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Не удалось открыть файл во внешнем приложении'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при открытии файла: $e'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Файл не существует или был удален'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Метод для подтверждения удаления с улучшенным дизайном
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл',
            style: TextStyle(fontSize: 16)), // Уменьшен шрифт
        content: const Text('Вы уверены, что хотите удалить этот файл?',
            style: TextStyle(fontSize: 14)), // Уменьшен шрифт
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRemove();
            },
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
