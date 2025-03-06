import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/themes_provider.dart';
import 'providers/note_links_provider.dart';
import 'screens/main_screen.dart';
import 'utils/constants.dart';
import 'utils/sample_data.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // Инициализируем Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем данные форматирования даты
  await initializeDateFormatting('ru', null);

  // Проверяем, был ли уже первый запуск
  final prefs = await SharedPreferences.getInstance();

  // Получаем текущее значение флага
  bool isFirstRun = prefs.getBool('isFirstRun') ?? true;

  // Если нужно принудительно сбросить данные и создать новые тестовые данные,
  // раскомментируйте следующую строку и запустите приложение один раз, затем снова закомментируйте
  // isFirstRun = true;

  // Запускаем приложение
  runApp(MyApp(isFirstRun: isFirstRun));
}

class MyApp extends StatefulWidget {
  final bool isFirstRun;

  const MyApp({super.key, required this.isFirstRun});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Храним Future для инициализации как состояние
  late Future<void> _initializationFuture;

  @override
  void initState() {
    super.initState();
    // Создаем Future только один раз при инициализации состояния
    _initializationFuture = _initializeApp();
  }

  // Метод инициализации приложения теперь не принимает контекст
  Future<void> _initializeApp() async {
    if (widget.isFirstRun) {
      // Создаем примеры данных при первом запуске
      print('Первый запуск: создаем примеры данных...');
      await _createSampleData();

      // Отмечаем, что первый запуск уже был
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isFirstRun', false);
    } else {
      // Загружаем данные из базы данных
      print('Не первый запуск: загружаем существующие данные...');
      await _loadData();
    }
  }

  // Изменяем _createSampleData чтобы он не требовал контекст
  Future<void> _createSampleData() async {
    print('Создание примеров данных при первом запуске...');

    // Использование BuildContext через глобальный ключ или другой механизм
    // Лучше инициализировать провайдеры напрямую
    try {
      // Создаем экземпляры провайдеров напрямую
      final themesProvider = ThemesProvider();
      final notesProvider = NotesProvider();
      final linksProvider = NoteLinksProvider();

      // Генерируем примеры тем
      final themes = SampleData.generateThemes();
      for (var theme in themes) {
        await themesProvider.createTheme(
          theme.name,
          theme.description,
          theme.color,
          theme.noteIds,
        );
      }

      // Загружаем только что созданные темы, чтобы получить их реальные ID
      await themesProvider.loadThemes();
      final createdThemes = themesProvider.themes;

      // Генерируем примеры заметок
      final notes = SampleData.generateNotes(createdThemes);
      for (var note in notes) {
        await notesProvider.createNote(
          content: note.content,
          themeIds: note.themeIds,
          hasDeadline: note.hasDeadline,
          deadlineDate: note.deadlineDate,
          hasDateLink: note.hasDateLink,
          linkedDate: note.linkedDate,
          emoji: note.emoji,
        );
      }

      // Загружаем заметки
      await notesProvider.loadNotes();
      final createdNotes = notesProvider.notes;

      // Генерируем связи между заметками
      final links = SampleData.generateLinks(createdNotes);
      for (var link in links) {
        await linksProvider.createLink(
          sourceNoteId: link.sourceNoteId,
          targetNoteId: link.targetNoteId,
          themeId: link.themeId,
          linkType: link.linkType,
          description: link.description,
        );
      }

      print('Примеры данных успешно созданы');
    } catch (e) {
      print('Ошибка при создании примеров данных: $e');
    }
  }

  // Изменяем _loadData чтобы он не требовал контекст
  Future<void> _loadData() async {
    print('Загрузка данных из базы...');
    // Данная функция не нуждается в контексте, она нужна для логики инициализации
    // Реальная загрузка данных будет происходить через провайдеры после построения UI
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => NotesProvider()),
        ChangeNotifierProvider(create: (_) => ThemesProvider()),
        ChangeNotifierProvider(create: (_) => NoteLinksProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return MaterialApp(
            title: 'NoteLink',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: AppColors.primary,
              brightness: Brightness.dark,
              useMaterial3: true,
              cardTheme: CardTheme(
                color: AppColors.cardBackground, // White Asparagus
                elevation: AppDimens.cardElevation,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.cardBorderRadius),
                ),
                shadowColor: Colors.black.withOpacity(0.3),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnDark,
                elevation: 0,
                centerTitle: false,
                titleTextStyle: AppTextStyles.heading2,
                iconTheme: IconThemeData(color: AppColors.textOnDark),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: AppColors.textOnDark,
                  elevation: 3,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.buttonBorderRadius),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.smallPadding,
                    horizontal: AppDimens.mediumPadding,
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.textBackground,
                contentPadding: const EdgeInsets.all(AppDimens.mediumPadding),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.buttonBorderRadius),
                  borderSide: BorderSide.none,
                ),
                hintStyle: AppTextStyles.bodyMediumLight.copyWith(
                  color: AppColors.textOnLight.withOpacity(0.5),
                ),
                labelStyle: AppTextStyles.bodyMediumLight,
              ),
              colorScheme: ColorScheme.dark(
                primary: AppColors.accentPrimary,
                secondary: AppColors.accentSecondary,
                surface: AppColors.cardBackground,
                background: AppColors.primary,
                error: AppColors.error,
                onSurface: AppColors.textOnLight, // Важно: текст на карточках
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: AppColors.primary.withOpacity(0.95),
                selectedItemColor: AppColors.navSelectedItem,
                unselectedItemColor:
                    AppColors.navUnselectedItem.withOpacity(0.6),
                showSelectedLabels: true,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                elevation: 8,
              ),
              checkboxTheme: CheckboxThemeData(
                fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.accentPrimary;
                  }
                  return AppColors.secondary;
                }),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.accentPrimary;
                  }
                  return AppColors.textOnDark;
                }),
                trackColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.accentPrimary.withOpacity(0.5);
                  }
                  return AppColors.textOnDark.withOpacity(0.3);
                }),
              ),
              floatingActionButtonTheme: FloatingActionButtonThemeData(
                backgroundColor: AppColors.fabBackground,
                foregroundColor: AppColors.fabIcon,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              textTheme: TextTheme(
                displayLarge: AppTextStyles.heading1,
                displayMedium: AppTextStyles.heading2,
                displaySmall: AppTextStyles.heading3,
                bodyLarge: AppTextStyles.bodyLarge,
                bodyMedium: AppTextStyles.bodyMedium,
                bodySmall: AppTextStyles.bodySmall,
                // Темный текст на светлых карточках
                headlineLarge: AppTextStyles.heading1Light,
                headlineMedium: AppTextStyles.heading2Light,
                headlineSmall: AppTextStyles.heading3Light,
                titleLarge: AppTextStyles.bodyLargeLight,
                titleMedium: AppTextStyles.bodyMediumLight,
                titleSmall: AppTextStyles.bodySmallLight,
              ),
              cardColor: AppColors.cardBackground,
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppColors
                      .textOnLight, // Темный цвет для текстовых кнопок на карточках
                ),
              ),
            ),
            darkTheme: ThemeData(
              primaryColor: AppColors.primary,
              scaffoldBackgroundColor: AppColors.primary,
              brightness: Brightness.dark,
              useMaterial3: true,
              cardTheme: CardTheme(
                color: AppColors.cardBackground,
                elevation: AppDimens.cardElevation,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.cardBorderRadius),
                ),
                shadowColor: Colors.black.withOpacity(0.3),
              ),
              appBarTheme: AppBarTheme(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnDark,
                elevation: 0,
                centerTitle: false,
                titleTextStyle: AppTextStyles.heading2,
                iconTheme: IconThemeData(color: AppColors.textOnDark),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: AppColors.textOnDark,
                  elevation: 3,
                  shadowColor: Colors.black.withOpacity(0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimens.buttonBorderRadius),
                  ),
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimens.smallPadding,
                    horizontal: AppDimens.mediumPadding,
                  ),
                ),
              ),
              inputDecorationTheme: InputDecorationTheme(
                filled: true,
                fillColor: AppColors.textBackground,
                contentPadding: const EdgeInsets.all(AppDimens.mediumPadding),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(AppDimens.buttonBorderRadius),
                  borderSide: BorderSide.none,
                ),
                hintStyle: AppTextStyles.bodyMediumLight.copyWith(
                  color: AppColors.textOnLight.withOpacity(0.5),
                ),
                labelStyle: AppTextStyles.bodyMediumLight,
              ),
              colorScheme: ColorScheme.dark(
                primary: AppColors.accentPrimary,
                secondary: AppColors.accentSecondary,
                surface: AppColors.cardBackground,
                background: AppColors.primary,
                error: AppColors.error,
              ),
              bottomNavigationBarTheme: BottomNavigationBarThemeData(
                backgroundColor: AppColors.primary.withOpacity(0.95),
                selectedItemColor: AppColors.accentSecondary,
                unselectedItemColor: AppColors.textOnDark.withOpacity(0.6),
                showSelectedLabels: true,
                showUnselectedLabels: true,
                type: BottomNavigationBarType.fixed,
                elevation: 8,
              ),
              checkboxTheme: CheckboxThemeData(
                fillColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.accentPrimary;
                  }
                  return AppColors.secondary;
                }),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              switchTheme: SwitchThemeData(
                thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.accentSecondary;
                  }
                  return AppColors.textOnDark;
                }),
                trackColor: MaterialStateProperty.resolveWith<Color>((states) {
                  if (states.contains(MaterialState.selected)) {
                    return AppColors.accentSecondary.withOpacity(0.5);
                  }
                  return AppColors.textOnDark.withOpacity(0.3);
                }),
              ),
              fontFamily: 'Roboto',
              textTheme: TextTheme(
                displayLarge: AppTextStyles.heading1,
                displayMedium: AppTextStyles.heading2,
                displaySmall: AppTextStyles.heading3,
                bodyLarge: AppTextStyles.bodyLarge,
                bodyMedium: AppTextStyles.bodyMedium,
                bodySmall: AppTextStyles.bodySmall,
              ),
            ),
            themeMode: appProvider.themeMode == AppThemeMode.light
                ? ThemeMode.light
                : appProvider.themeMode == AppThemeMode.dark
                    ? ThemeMode.dark
                    : ThemeMode.system,
            home: FutureBuilder(
              // Используем сохраненный Future, который не пересоздается при перестроении
              future: _initializationFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                // Используем GlobalKey для сохранения состояния MainScreen
                return const MainScreen(key: PageStorageKey('main_screen'));
              },
            ),
          );
        },
      ),
    );
  }
}
