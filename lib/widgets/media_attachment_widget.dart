// lib/widgets/media_attachment_widget.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/constants.dart';
import '../services/media_service.dart';
import 'package:path/path.dart' as path;

class MediaAttachmentWidget extends StatelessWidget {
  final String mediaPath;
  final VoidCallback onRemove;
  final bool isEditing;

  const MediaAttachmentWidget({
    Key? key,
    required this.mediaPath,
    required this.onRemove,
    this.isEditing = true,
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
      return _buildErrorWidget();
    }

    if (isImage) {
      return _buildImageWidget(file, context);
    } else {
      return _buildFileWidget(fileName, extension, context);
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 24),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Файл не найден',
              style: TextStyle(color: Colors.red),
            ),
          ),
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: Colors.red),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }

  Widget _buildImageWidget(File file, BuildContext context) {
    return GestureDetector(
      onTap: () => _showImagePreview(context, file),
      onLongPress: isEditing ? () => _showFileOptions(context) : null,
      child: Stack(
        children: [
          Container(
            constraints: const BoxConstraints(
              maxHeight: 200,
              maxWidth: double.infinity,
            ),
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
              child: Image.file(
                file,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 100,
                    color: Colors.grey[300],
                    alignment: Alignment.center,
                    child: const Text('Ошибка загрузки'),
                  );
                },
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
                  icon: const Icon(Icons.close, color: Colors.white, size: 16),
                  padding: const EdgeInsets.all(4),
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
      onTap: () => _showFilePreview(context, fileName, extension),
      onLongPress: () => _showFileOptions(context),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Иконка файла с фоном
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  fileIcon,
                  color: iconColor,
                  size: 28,
                ),
              ),

              const SizedBox(width: 16),

              // Информация о файле
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName.length > 30
                          ? '${fileName.substring(0, 27)}...'
                          : fileName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      extension.toUpperCase().substring(1),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textOnLight.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              // Кнопка удаления (если в режиме редактирования)
              if (isEditing)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
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

  // Метод для показа предпросмотра изображения
  void _showImagePreview(BuildContext context, File file) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 3.0,
              child: Image.file(file),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Метод для показа предпросмотра файла
  void _showFilePreview(
      BuildContext context, String fileName, String extension) {
    final MediaService mediaService = MediaService();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(fileName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тип файла: ${extension.toUpperCase().substring(1)}'),
            const SizedBox(height: 8),
            const Text('Предпросмотр недоступен для этого типа файла.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  // Метод для показа опций файла
  void _showFileOptions(BuildContext context) {
    final MediaService mediaService = MediaService();
    final fileName = mediaService.getFileNameFromPath(mediaPath);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                fileName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('Открыть'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Реализовать открытие файла
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Скачать'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Реализовать скачивание файла
              },
            ),
            if (isEditing)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Переименовать'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Реализовать переименование файла
                },
              ),
            if (isEditing)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title:
                    const Text('Удалить', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDelete(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Отмена'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // Метод для подтверждения удаления
  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить файл'),
        content: const Text('Вы уверены, что хотите удалить этот файл?'),
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

// Виджет для отображения сетки изображений
class MediaGrid extends StatelessWidget {
  final List<String> imagePaths;
  final Function(int index) onRemove;
  final bool isEditing;

  const MediaGrid({
    Key? key,
    required this.imagePaths,
    required this.onRemove,
    this.isEditing = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final MediaService mediaService = MediaService();

    // Фильтруем только изображения
    final images =
        imagePaths.where((path) => mediaService.isImage(path)).toList();

    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return MediaAttachmentWidget(
          mediaPath: images[index],
          onRemove: () => onRemove(imagePaths.indexOf(images[index])),
          isEditing: isEditing,
        );
      },
    );
  }
}

// Виджет для отображения списка файлов (не изображений)
class FilesList extends StatelessWidget {
  final List<String> filePaths;
  final Function(int index) onRemove;
  final bool isEditing;

  const FilesList({
    Key? key,
    required this.filePaths,
    required this.onRemove,
    this.isEditing = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final MediaService mediaService = MediaService();

    // Фильтруем только не-изображения
    final files =
        filePaths.where((path) => !mediaService.isImage(path)).toList();

    if (files.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: files.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return MediaAttachmentWidget(
          mediaPath: files[index],
          onRemove: () => onRemove(filePaths.indexOf(files[index])),
          isEditing: isEditing,
        );
      },
    );
  }
}
