import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../providers/app_provider.dart';
import '../utils/constants.dart';
import 'notes_screen.dart';
import 'calendar_screen.dart';
import 'themes_screen.dart';
import 'search_screen.dart';
import 'note_detail_screen.dart';
import 'favorite_screen.dart';
import 'dart:math' as math;
import '../models/note.dart';
import '../providers/notes_provider.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  // Изменяем стартовый индекс на 2 (экран с темами)
  int _currentIndex = 2;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _fabRotateAnimation;

  final List<Widget> _screens = [
    const NotesScreen(),
    const CalendarScreen(),
    const ThemesScreen(),
  ];

  final List<String> _titles = [
    'Заметки',
    'Календарь',
    'Темы',
  ];

  @override
  void initState() {
    super.initState();

    // Инициализируем анимацию для FAB
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: AppAnimations.mediumDuration,
    );

    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _fabRotateAnimation = Tween<double>(begin: 0.0, end: math.pi / 12).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentIndex]),
        actions: [
          // Кнопка поиска
          IconButton(
            icon: const Icon(AppIcons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),

          // Кнопка избранного
          IconButton(
            icon: const Icon(Icons.star),
            tooltip: 'Избранное',
            onPressed: () {
              print('📌 Нажата кнопка Избранное');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FavoriteScreen(),
                ),
              );
            },
          ),

          // Переключатель режима просмотра для экрана заметок
          if (_currentIndex == 0)
            Consumer<AppProvider>(
              builder: (context, appProvider, _) {
                return IconButton(
                  icon: Icon(
                    appProvider.noteViewMode == NoteViewMode.card
                        ? AppIcons.list
                        : AppIcons.grid,
                  ),
                  tooltip: appProvider.noteViewMode == NoteViewMode.card
                      ? 'Список'
                      : 'Карточки',
                  onPressed: () {
                    Provider.of<AppProvider>(context, listen: false)
                        .toggleNoteViewMode();
                  },
                );
              },
            ),
        ],
      ),
      body: IndexedStack(
        key: const ValueKey('main_screen_stack'),
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [AppShadows.medium],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              // Проверим, что index отличается от текущего
              if (_currentIndex != index) {
                setState(() {
                  _currentIndex = index;
                });
              }
            },
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.note),
                label: 'Заметки',
              ),
              BottomNavigationBarItem(
                icon: Icon(AppIcons.calendar),
                label: 'Календарь',
              ),
              BottomNavigationBarItem(
                icon: Icon(AppIcons.themes),
                label: 'Темы',
              ),
            ],
          ),
        ),
      ),

      floatingActionButton: _currentIndex != 1
          ? MouseRegion(
              onEnter: (_) => _fabAnimationController.forward(),
              onExit: (_) => _fabAnimationController.reverse(),
              child: GestureDetector(
                onTapDown: (_) => _fabAnimationController.forward(),
                onTapUp: (_) => _fabAnimationController.reverse(),
                onTapCancel: () => _fabAnimationController.reverse(),
                child: AnimatedBuilder(
                  animation: _fabAnimationController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _fabScaleAnimation.value,
                      child: Transform.rotate(
                        angle: _fabRotateAnimation.value,
                        child: FloatingActionButton(
                          onPressed: () {
                            switch (_currentIndex) {
                              case 0: // Notes
                                _showAddNoteDialog();
                                break;
                              case 2: // Themes
                                _showAddThemeDialog();
                                break;
                            }
                          },
                          backgroundColor: AppColors.accentSecondary,
                          foregroundColor: AppColors.textOnDark,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.add, size: 28),
                        ),
                      ),
                    );
                  },
                ),
              ),
            )
          : null, // null для экрана календаря,
    );
  }

  void _showAddNoteDialog() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const NoteDetailScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(0.0, 1.0);
          var end = Offset.zero;
          var curve = Curves.easeOutQuint;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: AppAnimations.mediumDuration,
      ),
    );
  }

  void _showAddThemeDialog() {
    ThemesScreen.showAddThemeDialog(context);
  }

  // Обработка добавления/удаления заметки в избранное
}
