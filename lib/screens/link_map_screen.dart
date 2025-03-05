import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import '../models/note.dart';
import '../models/note_link.dart';
import '../models/theme.dart';
import '../providers/notes_provider.dart';
import '../providers/themes_provider.dart';
import '../providers/note_links_provider.dart';
import '../utils/constants.dart';
import 'note_detail_screen.dart';

class LinkMapScreen extends StatefulWidget {
  const LinkMapScreen({super.key});

  @override
  State<LinkMapScreen> createState() => _LinkMapScreenState();
}

class _LinkMapScreenState extends State<LinkMapScreen> with SingleTickerProviderStateMixin {
  // Контроллер анимации
  late AnimationController _animationController;

  // Для масштабирования и перемещения
  double _scale = 0.5; // Начинаем с уменьшенного масштаба для обзора
  Offset _position = Offset.zero;
  Offset? _startingFocalPoint;
  Offset? _previousPosition;
  double? _previousScale;

  // Для фильтрации связей
  bool _showThemeLinks = true;
  bool _showDirectLinks = true;
  String? _selectedThemeId;

  // Карта позиций заметок
  final Map<String, Offset> _notePositions = {};

  // Выбранная заметка
  String? _selectedNoteId;

  @override
  void initState() {
    super.initState();

    // Инициализация контроллера анимации
    _animationController = AnimationController(
      duration: AppAnimations.longDuration,
      vsync: this,
    );

    // Загружаем данные
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
      _animationController.forward();

      // Принудительно создаем тематические связи для всех заметок
      _createThematicLinks();
    });
  }

  // Новый метод для создания тематических связей
  void _createThematicLinks() async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final linksProvider =
        Provider.of<NoteLinksProvider>(context, listen: false);

    // Ждем загрузки заметок
    await Future.delayed(const Duration(milliseconds: 500));

    // Для каждой заметки с темами создаем тематические связи
    for (final note in notesProvider.notes) {
      if (note.themeIds.isNotEmpty) {
        await linksProvider.createThemeLinksForNote(note.id, note.themeIds);
      }
    }

    setState(() {
      // Обновляем состояние для перерисовки
    });

    print('Тематические связи созданы');
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _loadData() async {
    final notesProvider = Provider.of<NotesProvider>(context, listen: false);
    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);
    final linksProvider =
        Provider.of<NoteLinksProvider>(context, listen: false);

    try {
      await notesProvider.loadNotes();
      await themesProvider.loadThemes();
      await linksProvider.loadLinks();

      if (mounted) {
        // Распределяем заметки по экрану
        _generateNodePositions(notesProvider.notes);

        // Добавляем отладочную информацию
        print('Загружено заметок: ${notesProvider.notes.length}');
        print('Загружено тем: ${themesProvider.themes.length}');
        print('Загружено связей: ${linksProvider.links.length}');

        // Фильтруем связи для отображения
        final filteredLinks = _filterLinks(linksProvider.links, themesProvider);
        print('Отфильтровано связей для отображения: ${filteredLinks.length}');

        // Проверяем, есть ли тематические связи
        final themeLinks = filteredLinks
            .where((link) => link.linkType == LinkType.theme)
            .toList();
        print('Тематических связей: ${themeLinks.length}');
      }
    } catch (e) {
      print('Ошибка при загрузке данных: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки данных: $e')),
        );
      }
    }
  }

  // Генерация позиций для заметок с группировкой по темам
  void _generateNodePositions(List<Note> notes) {
    if (notes.isEmpty) return;

    // Размеры экрана для позиционирования
    final screenWidth = MediaQuery.of(context).size.width * 3; // Увеличиваем область для масштабирования
    final screenHeight = MediaQuery.of(context).size.height * 3;
    
    // Получаем все темы
    final themesProvider = Provider.of<ThemesProvider>(context, listen: false);
    final themes = themesProvider.themes;
    
    // Создаем группировку заметок по темам
    final Map<String, List<String>> notesByTheme = {};
    final Map<String, List<String>> themesByNote = {};
    
    // Определяем, какие заметки к каким темам относятся
    for (var note in notes) {
      themesByNote[note.id] = [];
      
      if (note.themeIds.isEmpty) {
        // Заметки без темы помещаем в специальную группу
        if (!notesByTheme.containsKey('unthemed')) {
          notesByTheme['unthemed'] = [];
        }
        notesByTheme['unthemed']!.add(note.id);
      } else {
        // Добавляем заметку во все её темы
        for (var themeId in note.themeIds) {
          if (!notesByTheme.containsKey(themeId)) {
            notesByTheme[themeId] = [];
          }
          notesByTheme[themeId]!.add(note.id);
          themesByNote[note.id]!.add(themeId);
        }
      }
    }
    
    // Вычисляем позиции для каждой темы на экране (распределяем темы равномерно)
    final Map<String, Offset> themePositions = {};
    final themeKeys = notesByTheme.keys.toList();
    final centerX = screenWidth / 2;
    final centerY = screenHeight / 2;
    final radius = math.min(screenWidth, screenHeight) * 0.35;
    
    for (int i = 0; i < themeKeys.length; i++) {
      final angle = (i / themeKeys.length) * 2 * math.pi;
      final x = centerX + radius * math.cos(angle);
      final y = centerY + radius * math.sin(angle);
      themePositions[themeKeys[i]] = Offset(x, y);
    }
    
    // Теперь размещаем заметки вокруг своих тем
    final random = math.Random();
    _notePositions.clear();
    
    // Сначала размещаем заметки, которые принадлежат только одной теме
    for (var entry in notesByTheme.entries) {
      final themeId = entry.key;
      final noteIds = entry.value;
      final themePos = themePositions[themeId]!;
      
      // Вычисляем малый радиус для группировки заметок вокруг темы
      final smallRadius = radius * 0.2;
      final notesCount = noteIds.length;
      
      for (int i = 0; i < noteIds.length; i++) {
        final noteId = noteIds[i];
        
        // Пропускаем заметки, которые принадлежат нескольким темам
        if (themesByNote[noteId]!.length > 1) continue;
        
        // Равномерно распределяем заметки вокруг темы
        final noteAngle = (i / notesCount) * 2 * math.pi;
        // Добавляем небольшой случайный разброс для естественности
        final randomOffset = random.nextDouble() * 10;
        
        final x = themePos.dx + (smallRadius + randomOffset) * math.cos(noteAngle);
        final y = themePos.dy + (smallRadius + randomOffset) * math.sin(noteAngle);
        
        _notePositions[noteId] = Offset(x, y);
      }
    }
    
    // Теперь размещаем заметки, которые принадлежат нескольким темам
    // Они будут располагаться между своими темами
    for (var note in notes) {
      if (themesByNote[note.id]!.length <= 1) continue;
      
      // Вычисляем среднюю позицию между всеми темами заметки
      double sumX = 0;
      double sumY = 0;
      
      for (var themeId in themesByNote[note.id]!) {
        if (themePositions.containsKey(themeId)) {
          sumX += themePositions[themeId]!.dx;
          sumY += themePositions[themeId]!.dy;
        }
      }
      
      final count = themesByNote[note.id]!.length;
      // Добавляем небольшой случайный разброс для естественности
      final x = sumX / count + (random.nextDouble() - 0.5) * 30;
      final y = sumY / count + (random.nextDouble() - 0.5) * 30;
      
      _notePositions[note.id] = Offset(x, y);
    }
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer3<NotesProvider, ThemesProvider, NoteLinksProvider>(
        builder: (context, notesProvider, themesProvider, linksProvider, _) {
          final notes = notesProvider.notes;
          final links = _filterLinks(linksProvider.links, themesProvider);

          if (notes.isEmpty) {
            return const Center(
              child: Text('Нет заметок для отображения'),
            );
          }

          return Stack(
            children: [
              // Фон с сеткой
              _buildGridBackground(),

              // Основное содержимое с масштабированием
              GestureDetector(
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, _) {
                    return Transform.scale(
                      scale: _scale,
                      child: Transform.translate(
                        offset: _position,
                        child: CustomPaint(
                          painter: LinkMapPainter(
                            notes: notes,
                            links: links,
                            notePositions: _notePositions,
                            animationValue: _animationController.value,
                            selectedNoteId: _selectedNoteId,
                            themes: themesProvider.themes,
                          ),
                          child: Container(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Узлы заметок с возможностью перетаскивания
              ...notes.map((note) {
                final position = _notePositions[note.id] ?? Offset.zero;
                return _buildDraggableNode(note, position);
              }).toList(),

              // Информация о выбранной заметке
              if (_selectedNoteId != null)
                _buildSelectedNoteInfo(
                  notesProvider.notes
                      .firstWhere((n) => n.id == _selectedNoteId),
                  themesProvider,
                ),

              // Легенда
              Positioned(
                bottom: 16,
                right: 16,
                child: _buildLegend(themesProvider),
              ),
              
              // Кнопки управления масштабом
              Positioned(
                bottom: 80,
                right: 16,
                child: Column(
                  children: [
                    FloatingActionButton(
                      mini: true,
                      onPressed: _zoomIn,
                      child: const Icon(Icons.add),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: _zoomOut,
                      child: const Icon(Icons.remove),
                    ),
                    const SizedBox(height: 8),
                    FloatingActionButton(
                      mini: true,
                      onPressed: _resetView,
                      child: const Icon(Icons.center_focus_strong),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Фильтрация связей по настройкам
  List<NoteLink> _filterLinks(
      List<NoteLink> allLinks, ThemesProvider themesProvider) {
    return allLinks.where((link) {
      // Исключаем связи дедлайнов полностью
      if (link.linkType == LinkType.deadline) {
        return false;
      }

      // Фильтрация по типу связи
      if (link.linkType == LinkType.theme && !_showThemeLinks) {
        return false;
      }
      if (link.linkType == LinkType.direct && !_showDirectLinks) {
        return false;
      }

      // Фильтрация по выбранной теме
      if (_selectedThemeId != null) {
        if (link.themeId == null) {
          return false;
        }
        return link.themeId == _selectedThemeId;
      }

      return true;
    }).toList();
  }

  // Обработка начала масштабирования
  void _handleScaleStart(ScaleStartDetails details) {
    _startingFocalPoint = details.focalPoint;
    _previousPosition = _position;
    _previousScale = _scale;
  }

  // Обработка изменения масштаба
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (_startingFocalPoint == null) return;

    setState(() {
      // Масштабирование
      if (details.scale != 1.0) {
        _scale = (_previousScale! * details.scale).clamp(0.2, 2.0);
      }

      // Перемещение с учётом масштаба
      final delta = details.focalPoint - _startingFocalPoint!;
      _position = _previousPosition! + delta / _scale;
    });
  }

  // Увеличение масштаба
  void _zoomIn() {
    setState(() {
      _scale = (_scale * 1.2).clamp(0.2, 2.0);
    });
  }

  // Уменьшение масштаба
  void _zoomOut() {
    setState(() {
      _scale = (_scale / 1.2).clamp(0.2, 2.0);
    });
  }

  // Сброс масштаба и позиции
  void _resetView() {
    setState(() {
      _scale = 0.5;
      _position = Offset.zero;
      _selectedNoteId = null;
    });
  }

  // Показать диалог фильтрации
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Фильтр связей'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Типы связей
                CheckboxListTile(
                  title: const Text('Тематические связи'),
                  value: _showThemeLinks,
                  onChanged: (value) {
                    setState(() {
                      _showThemeLinks = value ?? true;
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Прямые связи'),
                  value: _showDirectLinks,
                  onChanged: (value) {
                    setState(() {
                      _showDirectLinks = value ?? true;
                    });
                  },
                ),

                const Divider(),

                // Фильтр по теме
                Consumer<ThemesProvider>(
                  builder: (context, themesProvider, _) {
                    return DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: 'Фильтр по теме',
                      ),
                      value: _selectedThemeId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Все темы'),
                        ),
                        ...themesProvider.themes.map((theme) {
                          return DropdownMenuItem<String?>(
                            value: theme.id,
                            child: Text(theme.name),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedThemeId = value;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  this.setState(() {});
                },
                child: const Text('Применить'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Фон с сеткой
  Widget _buildGridBackground() {
    return Container(
      color: AppColors.primary,
      child: CustomPaint(
        painter: GridPainter(),
        child: Container(),
      ),
    );
  }

  // Построение узла заметки с возможностью перетаскивания
  Widget _buildDraggableNode(Note note, Offset position) {
    final nodeSize = 60.0;
    final isSelected = _selectedNoteId == note.id;

    // Определяем цвет узла
    Color nodeColor = AppColors.cardBackground;
    if (note.themeIds.isNotEmpty) {
      // Используем цвет первой темы
      final themesProvider =
          Provider.of<ThemesProvider>(context, listen: false);
      final theme = themesProvider.themes.firstWhere(
        (t) => t.id == note.themeIds.first,
        orElse: () => NoteTheme(
          id: '',
          name: '',
          color: AppColors.themeColors[0].value.toString(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          noteIds: [],
        ),
      );

      try {
        nodeColor = Color(int.parse(theme.color));
      } catch (e) {
        // Используем дефолтный цвет, если не удалось распарсить
      }
    }

    return Positioned(
      // Учитываем масштаб и позицию для корректного отображения
      left: (position.dx * _scale + _position.dx) - nodeSize / 2,
      top: (position.dy * _scale + _position.dy) - nodeSize / 2,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _notePositions[note.id] = Offset(
              position.dx + details.delta.dx / _scale,
              position.dy + details.delta.dy / _scale,
            );
          });
        },
        onTap: () {
          setState(() {
            _selectedNoteId = isSelected ? null : note.id;
          });
        },
        child: AnimatedScale(
          scale: isSelected ? 1.2 : 1.0,
          duration: AppAnimations.shortDuration,
          child: Container(
            width: nodeSize,
            height: nodeSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: nodeColor.withOpacity(0.8),
              border: Border.all(
                color: isSelected ? AppColors.accentSecondary : Colors.white,
                width: isSelected ? 3.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Text(
                  note.content.length > 30
                      ? '${note.content.substring(0, 30).trim()}...'
                      : note.content.trim(),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Информация о выбранной заметке
  Widget _buildSelectedNoteInfo(Note note, ThemesProvider themesProvider) {
    return Positioned(
      bottom: 16,
      left: 16,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardBackground.withOpacity(0.9),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.content.length > 50
                        ? '${note.content.substring(0, 50).trim()}...'
                        : note.content.trim(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedNoteId = null;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (note.hasDeadline && note.deadlineDate != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.timer, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Дедлайн: ${note.deadlineDate.toString().substring(0, 10)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: note.themeIds.map((themeId) {
                final theme = themesProvider.themes.firstWhere(
                  (t) => t.id == themeId,
                  orElse: () => NoteTheme(
                    id: '',
                    name: 'Unknown',
                    color: AppColors.themeColors[0].value.toString(),
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                    noteIds: [],
                  ),
                );

                Color themeColor;
                try {
                  themeColor = Color(int.parse(theme.color));
                } catch (e) {
                  themeColor = AppColors.themeColors[0];
                }

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: themeColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    theme.name,
                    style: TextStyle(
                      fontSize: 12,
                      color: themeColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => NoteDetailScreen(note: note),
                  ),
                );
              },
              child: const Text('Открыть заметку'),
            ),
          ],
        ),
      ),
    );
  }

  // Легенда для типов связей
  Widget _buildLegend(ThemesProvider themesProvider) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Легенда:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          _buildLegendItem(
            AppColors.accentPrimary,
            'Прямая связь',
            [2, 2], // Пунктирная линия
          ),
          const SizedBox(height: 4),
          _buildLegendItem(
            AppColors.themeColors[0],
            'Связь по теме',
            null, // Сплошная линия
          ),
        ],
      ),
    );
  }

  // Элемент легенды
  Widget _buildLegendItem(Color color, String text, List<double>? dashPattern) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
          ),
          child: dashPattern != null
              ? CustomPaint(
                  painter: DashLinePainter(
                    color: color,
                    dashPattern: dashPattern,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }
}

// Художник для рисования пунктирной линии в легенде
class DashLinePainter extends CustomPainter {
  final Color color;
  final List<double> dashPattern;

  DashLinePainter({
    required this.color,
    required this.dashPattern,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    double dashLength = dashPattern[0];
    double gapLength = dashPattern[1];
    double currentPosition = 0;

    while (currentPosition < size.width) {
      // Рисуем штрих
      canvas.drawLine(
        Offset(currentPosition, size.height / 2),
        Offset(currentPosition + dashLength, size.height / 2),
        paint,
      );
      // Переходим к следующему штриху
      currentPosition += dashLength + gapLength;
    }
  }

  @override
  bool shouldRepaint(DashLinePainter oldDelegate) => false;
}

// Художник для отрисовки карты связей
class LinkMapPainter extends CustomPainter {
  final List<Note> notes;
  final List<NoteLink> links;
  final Map<String, Offset> notePositions;
  final double animationValue;
  final String? selectedNoteId;
  final List<NoteTheme> themes;

  LinkMapPainter({
    required this.notes,
    required this.links,
    required this.notePositions,
    required this.animationValue,
    this.selectedNoteId,
    required this.themes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Создаем HashSet для отслеживания уже нарисованных связей
    final drawnConnectionPairs = <String>{};

    // Группируем связи по темам
    final Map<String?, List<NoteLink>> linksByTheme = {};
    for (final link in links) {
      if (!linksByTheme.containsKey(link.themeId)) {
        linksByTheme[link.themeId] = [];
      }
      linksByTheme[link.themeId]!.add(link);
    }

    // Рисуем связи по темам
    linksByTheme.forEach((themeId, themeLinks) {
      // Создаем временный граф для хранения связей
      final Map<String, Set<String>> graph = {};

      // Заполняем граф
      for (final link in themeLinks) {
        // Добавляем узлы в граф, если их еще нет
        if (!graph.containsKey(link.sourceNoteId)) {
          graph[link.sourceNoteId] = {};
        }
        if (!graph.containsKey(link.targetNoteId)) {
          graph[link.targetNoteId] = {};
        }

        // Добавляем связи между узлами
        graph[link.sourceNoteId]!.add(link.targetNoteId);
        graph[link.targetNoteId]!.add(link.sourceNoteId);
      }

      // Создаем минимальное остовное дерево для оптимизации связей
      final mst = _createMinimumSpanningTree(graph, notePositions);

      // Рисуем связи на основе минимального остовного дерева
      for (final entry in mst.entries) {
        final sourceId = entry.key;
        for (final targetId in entry.value) {
          // Создаем уникальный идентификатор для пары узлов
          final pairId = [sourceId, targetId]..sort();
          final connectionId = pairId.join('-');

          // Проверяем, не рисовали ли мы уже эту связь
          if (!drawnConnectionPairs.contains(connectionId)) {
            drawnConnectionPairs.add(connectionId);

            // Определяем является ли это тематической или прямой связью
            final isThemeLink = themeId != null;

            // Рисуем соединение
            _drawConnection(canvas, sourceId, targetId, isThemeLink, themeId);
          }
        }
      }
    });

    // Рисуем прямые связи, отдельно от тематических
    for (final link in links) {
      if (link.linkType == LinkType.direct) {
        // Создаем уникальный идентификатор для пары узлов
        final pairId = [link.sourceNoteId, link.targetNoteId]..sort();
        final connectionId = pairId.join('-');

        // Проверяем, не рисовали ли мы уже эту связь
        if (!drawnConnectionPairs.contains(connectionId)) {
          drawnConnectionPairs.add(connectionId);
          _drawConnection(
              canvas, link.sourceNoteId, link.targetNoteId, false, null);
        }
      }
    }
  }

  // Метод для создания минимального остовного дерева
  Map<String, Set<String>> _createMinimumSpanningTree(
      Map<String, Set<String>> graph, Map<String, Offset> positions) {
    // Если граф пустой, возвращаем пустой результат
    if (graph.isEmpty) return {};

    final result = <String, Set<String>>{};
    final visited = <String>{};

    // Начинаем с первого узла в графе
    final startNode = graph.keys.first;
    visited.add(startNode);

    // Продолжаем, пока не посетим все узлы
    while (visited.length < graph.length) {
      double minDistance = double.infinity;
      String? nextSource;
      String? nextTarget;

      // Для каждого посещенного узла
      for (final source in visited) {
        // Проверяем все соседние узлы
        for (final target in graph[source]!) {
          // Если соседний узел еще не посещен
          if (!visited.contains(target)) {
            // Вычисляем расстояние между узлами
            final sourcePos = positions[source];
            final targetPos = positions[target];

            if (sourcePos != null && targetPos != null) {
              final distance = (sourcePos - targetPos).distance;

              // Если это расстояние меньше текущего минимального
              if (distance < minDistance) {
                minDistance = distance;
                nextSource = source;
                nextTarget = target;
              }
            }
          }
        }
      }

      // Если нашли ближайший узел, добавляем его в результат
      if (nextSource != null && nextTarget != null) {
        if (!result.containsKey(nextSource)) {
          result[nextSource] = {};
        }
        if (!result.containsKey(nextTarget)) {
          result[nextTarget] = {};
        }

        result[nextSource]!.add(nextTarget);
        result[nextTarget]!.add(nextSource);
        visited.add(nextTarget);
      } else {
        // Если не можем найти следующий узел, возможно, граф несвязный
        // Находим непосещенный узел и начинаем новое дерево
        final unvisited = graph.keys.where((k) => !visited.contains(k));
        if (unvisited.isNotEmpty) {
          visited.add(unvisited.first);
        } else {
          break; // Все узлы посещены
        }
      }
    }

    return result;
  }

  // Метод для рисования соединения между заметками
  void _drawConnection(Canvas canvas, String sourceId, String targetId,
      bool isThemeLink, String? themeId) {
    final sourcePosition = notePositions[sourceId];
    final targetPosition = notePositions[targetId];

    if (sourcePosition == null || targetPosition == null) return;

    // Анимируем появление линии
    final animatedEndPos = Offset(
      sourcePosition.dx +
          (targetPosition.dx - sourcePosition.dx) * animationValue,
      sourcePosition.dy +
          (targetPosition.dy - sourcePosition.dy) * animationValue,
    );

    // Выбираем цвет и стиль линии
    Paint paint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    if (isThemeLink) {
      // Цветная линия для тематических связей
      if (themeId != null) {
        final theme = themes.firstWhere(
          (t) => t.id == themeId,
          orElse: () => themes.isNotEmpty
              ? themes.first
              : NoteTheme(
                  id: '',
                  name: '',
                  color: AppColors.themeColors[0].value.toString(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  noteIds: [],
                ),
        );

        try {
          paint.color = Color(int.parse(theme.color));
        } catch (e) {
          paint.color = AppColors.themeColors[0];
        }
      } else {
        paint.color = AppColors.themeColors[0];
      }

      canvas.drawLine(sourcePosition, animatedEndPos, paint);
    } else {
      // Пунктирная линия для прямых связей
      paint.color = AppColors.accentPrimary;
      _drawDashedLine(canvas, sourcePosition, animatedEndPos, paint);
    }
  }

  // Рисование пунктирной линии (оставляем как есть)
  void _drawDashedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(end.dx, end.dy);

    const dashWidth = 3;
    const dashSpace = 3;

    final Distance = _distance(start, end);
    final count = (Distance / (dashWidth + dashSpace)).floor();

    for (int i = 0; i < count; i++) {
      final t1 = i / count;
      final t2 = (i + 0.5) / count;

      final p1 = Offset(
        start.dx + (end.dx - start.dx) * t1,
        start.dy + (end.dy - start.dy) * t1,
      );

      final p2 = Offset(
        start.dx + (end.dx - start.dx) * t2,
        start.dy + (end.dy - start.dy) * t2,
      );

      canvas.drawLine(p1, p2, paint);
    }
  }

  // Вычисление расстояния между точками
  double _distance(Offset p1, Offset p2) {
    return math.sqrt(math.pow(p2.dx - p1.dx, 2) + math.pow(p2.dy - p1.dy, 2));
  }

  @override
  bool shouldRepaint(LinkMapPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.selectedNoteId != selectedNoteId ||
        oldDelegate.notePositions != notePositions ||
        oldDelegate.links != links;
  }
}

// Художник для отрисовки фоновой сетки
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1.0;

    const double spacing = 30.0;

    // Вертикальные линии
    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Горизонтальные линии
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) => false;
}
