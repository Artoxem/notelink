class ThemeClipper {
  final String id;
  final String imagePath;
  final String name;

  ThemeClipper({
    required this.id,
    required this.imagePath,
    required this.name,
  });
}

// Предопределенный список доступных клипперов
class ThemeClippers {
  static List<ThemeClipper> all = List.generate(
    18,
    (index) => ThemeClipper(
      id: 'aztec${(index + 1).toString().padLeft(2, '0')}',
      imagePath:
          'assets/images/aztec/aztec${(index + 1).toString().padLeft(2, '0')}.png',
      name: 'Aztec ${index + 1}',
    ),
  );

  // Получить клиппер по ID
  static ThemeClipper? getById(String id) {
    try {
      return all.firstWhere((clipper) => clipper.id == id);
    } catch (e) {
      return null;
    }
  }
}
