import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // Добавляем импорт
import 'providers/app_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/themes_provider.dart';
import 'screens/main_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart'; // Добавляем импорт сервиса уведомлений
import 'utils/constants.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  // Инициализируем Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализируем данные форматирования даты
  await initializeDateFormatting('ru', null);

  // Инициализация базы данных
  final databaseService = DatabaseService();
  await databaseService.database;

  // Инициализация сервиса уведомлений
  final notificationService = NotificationService();
  await notificationService.init();

  // Создаем провайдеры заранее
  final appProvider = AppProvider();
  final notesProvider = NotesProvider();
  final themesProvider = ThemesProvider();

  // Инициализируем настройки
  await appProvider.initSettings();

  // Настраиваем синхронизацию между провайдерами
  themesProvider.initSync(notesProvider);

  // Загружаем существующие данные
  print('Загружаем существующие данные...');
  await notesProvider.loadNotes(force: true);
  await themesProvider.loadThemes();

  print('Количество существующих заметок: ${notesProvider.notes.length}');
  print('Количество существующих тем: ${themesProvider.themes.length}');

  // Запускаем приложение с готовыми провайдерами
  runApp(MyApp(
    appProvider: appProvider,
    notesProvider: notesProvider,
    themesProvider: themesProvider,
  ));
}

class MyApp extends StatelessWidget {
  final AppProvider appProvider;
  final NotesProvider notesProvider;
  final ThemesProvider themesProvider;

  const MyApp({
    super.key,
    required this.appProvider,
    required this.notesProvider,
    required this.themesProvider,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appProvider),
        ChangeNotifierProvider.value(value: notesProvider),
        ChangeNotifierProvider.value(value: themesProvider),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, _) {
          return MaterialApp(
            title: 'NoteLink',
            debugShowCheckedModeBanner: false,
            // Добавляем настройки локализации
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ru', 'RU'), // Russian
              Locale('en', 'US'), // English
            ],
            locale: const Locale(
                'ru', 'RU'), // Установка русской локализации по умолчанию
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
            home: const MainScreen(key: PageStorageKey('main_screen')),
          );
        },
      ),
    );
  }
}
