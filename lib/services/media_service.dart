import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';

class MediaService {
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;

  MediaService._internal();

  final _picker = ImagePicker();
  final _uuid = Uuid();

  // Получение директории для хранения медиафайлов
  Future<Directory> _getMediaDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${appDir.path}/media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }
    return mediaDir;
  }

  // Генерация уникального имени файла
  String _generateFileName(String originalName) {
    final extension = path.extension(originalName);
    return '${_uuid.v4()}$extension';
  }

  // Копирование файла в хранилище приложения
  Future<String?> _saveFileToAppStorage(File file, String newName) async {
    try {
      final mediaDir = await _getMediaDirectory();
      final newPath = path.join(mediaDir.path, newName);
      await file.copy(newPath);
      return newPath;
    } catch (e) {
      print('Ошибка при сохранении файла: $e');
      return null;
    }
  }

  // Метод получения картинки из камеры
  Future<String?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70, // Немного сжимаем для экономии места
      );

      // Проверка на null и существование файла
      if (image == null) {
        debugPrint('Изображение не выбрано (null)');
        return null;
      }

      final file = File(image.path);
      if (!await file.exists()) {
        debugPrint('Файл изображения не существует: ${image.path}');
        return null;
      }

      // Сохраняем файл в директорию приложения
      final newName = _generateFileName(image.name);
      final savedPath = await _saveFileToAppStorage(file, newName);
      debugPrint('Изображение с камеры сохранено: $savedPath');
      return savedPath;
    } catch (e) {
      debugPrint('Ошибка при получении изображения с камеры: $e');
      return null;
    }
  }

  // Метод получения картинки из галереи
  Future<String?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70, // Сжимаем для экономии места
      );

      // Проверка на null
      if (image == null) {
        debugPrint('Изображение из галереи не выбрано (null)');
        return null;
      }

      // Проверка существования файла
      final file = File(image.path);
      if (!await file.exists()) {
        debugPrint('Файл изображения не существует: ${image.path}');
        return null;
      }

      // Сохраняем файл в директорию приложения
      final newName = _generateFileName(image.name);
      final savedPath = await _saveFileToAppStorage(file, newName);
      debugPrint('Изображение из галереи сохранено: $savedPath');
      return savedPath;
    } catch (e) {
      debugPrint('Ошибка при получении изображения из галереи: $e');
      return null;
    }
  }

  /// Выбор изображения из галереи или камеры
  Future<String?> pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path;
      }
      return null;
    } catch (e) {
      debugPrint('Ошибка при выборе файла: $e');
      return null;
    }
  }

  /// Проверяет, является ли файл изображением по расширению
  bool isImage(String filePath) {
    final extension = filePath.toLowerCase();
    return extension.endsWith('.jpg') ||
        extension.endsWith('.jpeg') ||
        extension.endsWith('.png') ||
        extension.endsWith('.gif') ||
        extension.endsWith('.webp');
  }

  /// Возвращает имя файла из пути
  String getFileNameFromPath(String filePath) {
    return path.basename(filePath);
  }

  /// Возвращает расширение файла
  String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  // Удаление файла
  Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Ошибка при удалении файла: $e');
      return false;
    }
  }
}
