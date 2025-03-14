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
      return _buildImageWidget(file);
    } else {
      return _buildFileWidget(fileName, extension);
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

  Widget _buildImageWidget(File file) {
    return Stack(
      children: [
        Container(
          constraints: const BoxConstraints(
            maxHeight: 200,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.secondary.withOpacity(0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              file,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
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
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 16),
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                onPressed: onRemove,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileWidget(String fileName, String extension) {
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

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.textBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              fileIcon,
              color: iconColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName.length > 20
                      ? '${fileName.substring(0, 17)}...'
                      : fileName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
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
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
