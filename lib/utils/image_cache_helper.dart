// lib/utils/image_cache_helper.dart

import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'dart:typed_data';
import 'dart:async';
import 'dart:convert';

/// Класс для управления кэшированием миниатюр изображений
class ImageCacheHelper {
  // Синглтон для глобального доступа
  static final ImageCacheHelper _instance = ImageCacheHelper._internal();
  factory ImageCacheHelper() => _instance;
  ImageCacheHelper._internal();

  // Кэш изображений в памяти
  final Map<String, ui.Image?> _memoryCache = {};
  final Map<String, ImageProvider> _imageProviderCache = {};

  // Директория кэша на диске
  Directory? _cacheDir;
  bool _initialized = false;

  /// Инициализация кэша
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _cacheDir = await getTemporaryDirectory();
      final cacheSubDir = Directory('${_cacheDir!.path}/image_thumbnails');
      if (!cacheSubDir.existsSync()) {
        cacheSubDir.createSync();
      }
      _cacheDir = cacheSubDir;
      _initialized = true;
    } catch (e) {
      debugPrint('Ошибка инициализации кэша: $e');
    }
  }

  /// Получить миниатюру изображения из кэша или создать новую
  Future<ImageProvider?> getThumbnail(
    String imagePath, {
    int width = 100,
    int height = 100,
    bool useMemoryCache = true,
    bool useDiskCache = true,
  }) async {
    if (!_initialized) await initialize();

    // Создаем уникальный ключ для изображения с учетом размеров
    final cacheKey = _generateCacheKey(imagePath, width, height);

    // Проверяем кэш в памяти
    if (useMemoryCache && _imageProviderCache.containsKey(cacheKey)) {
      return _imageProviderCache[cacheKey];
    }

    try {
      // Проверяем файл на диске
      if (useDiskCache) {
        final cachedFile = await _getCachedFileIfExists(cacheKey);
        if (cachedFile != null) {
          final provider = FileImage(cachedFile);
          if (useMemoryCache) {
            _imageProviderCache[cacheKey] = provider;
          }
          return provider;
        }
      }

      // Проверяем, существует ли исходный файл
      final file = File(imagePath);
      if (!file.existsSync()) {
        return null;
      }

      // Генерируем миниатюру
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: width,
        targetHeight: height,
      );
      final frame = await codec.getNextFrame();

      // Сохраняем в память, если нужно
      if (useMemoryCache) {
        _memoryCache[cacheKey] = frame.image;
      }

      // Сохраняем на диск, если нужно
      if (useDiskCache) {
        await _saveThumbnailToDisk(frame.image, cacheKey);
      }

      // Создаем провайдер и возвращаем
      final provider = MemoryImage(bytes);
      _imageProviderCache[cacheKey] = provider;
      return provider;
    } catch (e) {
      debugPrint('Ошибка создания миниатюры: $e');
      return null;
    }
  }

  /// Генерирует уникальный ключ для кэширования
  String _generateCacheKey(String path, int width, int height) {
    final bytes = utf8.encode('$path-$width-$height');
    final digest = md5.convert(bytes);
    return digest.toString();
  }

  /// Проверяет наличие файла в кэше на диске
  Future<File?> _getCachedFileIfExists(String cacheKey) async {
    if (_cacheDir == null) return null;

    final file = File('${_cacheDir!.path}/$cacheKey.png');
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  /// Сохраняет миниатюру на диск
  Future<void> _saveThumbnailToDisk(ui.Image image, String cacheKey) async {
    if (_cacheDir == null) return;

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final data = byteData.buffer.asUint8List();
      final file = File('${_cacheDir!.path}/$cacheKey.png');
      await file.writeAsBytes(data);
    } catch (e) {
      debugPrint('Ошибка сохранения миниатюры: $e');
    }
  }

  /// Очистка кэша (в памяти и/или на диске)
  Future<void> clearCache({bool memory = true, bool disk = false}) async {
    if (memory) {
      _memoryCache.clear();
      _imageProviderCache.clear();
    }

    if (disk && _cacheDir != null && _cacheDir!.existsSync()) {
      try {
        final files = _cacheDir!.listSync();
        for (final file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      } catch (e) {
        debugPrint('Ошибка очистки кэша: $e');
      }
    }
  }
}
