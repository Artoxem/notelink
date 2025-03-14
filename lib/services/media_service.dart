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

  // Получение изображения с камеры
  Future<String?> pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final newName = _generateFileName(pickedFile.name);
      return await _saveFileToAppStorage(file, newName);
    } catch (e) {
      print('Ошибка при получении изображения с камеры: $e');
      return null;
    }
  }

  // Получение изображения из галереи
  Future<String?> pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      final file = File(pickedFile.path);
      final newName = _generateFileName(pickedFile.name);
      return await _saveFileToAppStorage(file, newName);
    } catch (e) {
      print('Ошибка при получении изображения из галереи: $e');
      return null;
    }
  }

  // Выбор файла
  Future<String?> pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();

      if (result == null || result.files.single.path == null) return null;

      final file = File(result.files.single.path!);
      final newName = _generateFileName(result.files.single.name);
      return await _saveFileToAppStorage(file, newName);
    } catch (e) {
      print('Ошибка при выборе файла: $e');
      return null;
    }
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

  // Получение имени файла из пути
  String getFileNameFromPath(String filePath) {
    return path.basename(filePath);
  }

  // Получение расширения файла
  String getFileExtension(String filePath) {
    return path.extension(filePath).toLowerCase();
  }

  // Проверка, является ли файл изображением
  bool isImage(String filePath) {
    final ext = getFileExtension(filePath);
    return ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.gif';
  }
}
