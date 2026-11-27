import 'package:flutter/material.dart';

class IconGroup {
  const IconGroup({
    required this.id,
    required this.nameFa,
    required this.nameEn,
    required this.keys,
  });

  final String id;
  final String nameFa;
  final String nameEn;
  final List<String> keys;
}

class ColorToneGroup {
  const ColorToneGroup({
    required this.id,
    required this.colors,
  });

  final String id;
  final List<Color> colors;
}

class HabitPalette {
  HabitPalette._();

  /// Exact 2-row horizontal color columns (32 pairs = 64 signature tones).
  static const List<List<Color>> paletteColumns = [
    [Color(0xFF76B900), Color(0xFF93C427)],
    [Color(0xFFFFFDF0), Color(0xFFFDF28A)],
    [Color(0xFFFFE135), Color(0xFFFFD600)],
    [Color(0xFFFFC436), Color(0xFFD49B00)],
    [Color(0xFFD9A026), Color(0xFFC98200)],
    [Color(0xFFFDE1B6), Color(0xFFFBB040)],
    [Color(0xFFFFA500), Color(0xFFFF7A00)],
    [Color(0xFFFF6B00), Color(0xFFFF5722)],
    [Color(0xFFF07C65), Color(0xFFE6735C)],
    [Color(0xFFFF4C4C), Color(0xFFB71C1C)],
    [Color(0xFFFF4D5A), Color(0xFFE54B5D)],
    [Color(0xFFE4746B), Color(0xFFD46078)],
    [Color(0xFFFFD2D6), Color(0xFFE61E63)],
    [Color(0xFFF23B7D), Color(0xFFB01256)],
    [Color(0xFFF46B9C), Color(0xFFF8BBD0)],
    [Color(0xFFF9C5D5), Color(0xFFBA68C8)],
    [Color(0xFFE1BEE7), Color(0xFF9C27B0)],
    [Color(0xFFB938FF), Color(0xFF6A1B9A)],
    [Color(0xFF6C5CE7), Color(0xFF64B5F6)],
    [Color(0xFFD6E8FA), Color(0xFF2B80B8)],
    [Color(0xFF00C4E0), Color(0xFF4DB6DC)],
    [Color(0xFFECFAFC), Color(0xFF4DD0E1)],
    [Color(0xFF21B08E), Color(0xFF00796B)],
    [Color(0xFF4CAF7A), Color(0xFF00A86B)],
    [Color(0xFFC8E6C9), Color(0xFF81C784)],
    [Color(0xFF43A047), Color(0xFF2E7D32)],
    [Color(0xFF795548), Color(0xFF4E342E)],
    [Color(0xFFA1887F), Color(0xFF607D8B)],
    [Color(0xFFF5F5F5), Color(0xFFE0E0E0)],
    [Color(0xFFEFEBE9), Color(0xFFD7CCC8)],
    [Color(0xFF9E9E9E), Color(0xFF757575)],
    [Color(0xFF616161), Color(0xFF424242)],
  ];

  static const List<ColorToneGroup> colorTones = [
    ColorToneGroup(
      id: 'bright',
      colors: [
        Color(0xFFFFD600),
        Color(0xFFFF5722),
        Color(0xFFFF4D5A),
        Color(0xFFE61E63),
        Color(0xFFB938FF),
        Color(0xFF2B80B8),
        Color(0xFF00C4E0),
        Color(0xFF21B08E),
      ],
    ),
    ColorToneGroup(
      id: 'pastel',
      colors: [
        Color(0xFFFFFDF0),
        Color(0xFFFDE1B6),
        Color(0xFFFFD2D6),
        Color(0xFFF9C5D5),
        Color(0xFFE1BEE7),
        Color(0xFFD6E8FA),
        Color(0xFFECFAFC),
        Color(0xFFC8E6C9),
      ],
    ),
    ColorToneGroup(
      id: 'vivid',
      colors: [
        Color(0xFFD49B00),
        Color(0xFFB71C1C),
        Color(0xFFB01256),
        Color(0xFF6A1B9A),
        Color(0xFF00796B),
        Color(0xFF2E7D32),
        Color(0xFF795548),
        Color(0xFF607D8B),
      ],
    ),
    ColorToneGroup(
      id: 'deep',
      colors: [
        Color(0xFFF5F5F5),
        Color(0xFFD7CCC8),
        Color(0xFF9E9E9E),
        Color(0xFF424242),
      ],
    ),
  ];

  static const List<Color> colors = [
    Color(0xFF00C48C),
    Color(0xFF84CC16),
    Color(0xFFFFD426),
    Color(0xFF3898FF),
    Color(0xFFFF5C6C),
    Color(0xFFB06CFF),
    Color(0xFFFF8F3F),
    Color(0xFF21B08E),
    Color(0xFF607D8B),
    Color(0xFFE61E63),
    Color(0xFFEF4444),
    Color(0xFF6C5CE7),
    Color(0xFF00C4E0),
    Color(0xFFFFA500),
    Color(0xFF43A047),
    Color(0xFFBA68C8),
  ];

  static Color contrastFg(Color bg) {
    return bg.computeLuminance() > 0.179 ? Colors.black : Colors.white;
  }

  static const Map<String, IconData> icons = {
    // Health & Fitness
    'directions_run': Icons.directions_run_rounded,
    'fitness_center': Icons.fitness_center_rounded,
    'self_improvement': Icons.self_improvement_rounded,
    'directions_walk': Icons.directions_walk_rounded,
    'directions_bike': Icons.directions_bike_rounded,
    'pool': Icons.pool_rounded,
    'hiking': Icons.hiking_rounded,
    'sports_martial_arts': Icons.sports_martial_arts_rounded,
    'sports_basketball': Icons.sports_basketball_rounded,
    'sports_soccer': Icons.sports_soccer_rounded,
    'monitor_heart': Icons.monitor_heart_rounded,
    'medication': Icons.medication_rounded,
    'bedtime': Icons.bedtime_rounded,
    'wb_sunny': Icons.wb_sunny_rounded,
    'favorite': Icons.favorite_rounded,
    'air': Icons.air_rounded,
    // Work & Study
    'code': Icons.code_rounded,
    'terminal': Icons.terminal_rounded,
    'menu_book': Icons.menu_book_rounded,
    'auto_stories': Icons.auto_stories_rounded,
    'edit_note': Icons.edit_note_rounded,
    'work': Icons.work_rounded,
    'laptop_mac': Icons.laptop_mac_rounded,
    'calculate': Icons.calculate_rounded,
    'science': Icons.science_rounded,
    'translate': Icons.translate_rounded,
    'school': Icons.school_rounded,
    'psychology': Icons.psychology_rounded,
    // Food & Drink
    'water_drop': Icons.water_drop_rounded,
    'local_drink': Icons.local_drink_rounded,
    'coffee': Icons.coffee_rounded,
    'local_cafe': Icons.local_cafe_rounded,
    'restaurant': Icons.restaurant_rounded,
    'bakery_dining': Icons.bakery_dining_rounded,
    'eco': Icons.eco_rounded,
    'spa': Icons.spa_rounded,
    'soup_kitchen': Icons.soup_kitchen_rounded,
    'no_drinks': Icons.no_drinks_rounded,
    'emoji_food_beverage': Icons.emoji_food_beverage_rounded,
    // Lifestyle & Creative
    'music_note': Icons.music_note_rounded,
    'headphones': Icons.headphones_rounded,
    'palette': Icons.palette_rounded,
    'brush': Icons.brush_rounded,
    'camera_alt': Icons.camera_alt_rounded,
    'piano': Icons.piano_rounded,
    'pets': Icons.pets_rounded,
    'yard': Icons.yard_rounded,
    'cleaning_services': Icons.cleaning_services_rounded,
    'wash': Icons.wash_rounded,
    'weekend': Icons.weekend_rounded,
    'flight': Icons.flight_rounded,
    // Quit & Discipline
    'smoke_free': Icons.smoke_free_rounded,
    'smoking_rooms': Icons.smoking_rooms_rounded,
    'phonelink_erase': Icons.phonelink_erase_rounded,
    'no_food': Icons.no_food_rounded,
    'block': Icons.block_rounded,
    'do_not_disturb_on': Icons.do_not_disturb_on_rounded,
    'bedtime_off': Icons.bedtime_off_rounded,
    'alarm_off': Icons.alarm_off_rounded,
    'videogame_asset_off': Icons.videogame_asset_off_rounded,
    'money_off': Icons.money_off_rounded,
    'visibility_off': Icons.visibility_off_rounded,
    'timer_off': Icons.timer_off_rounded,
    // Time & Finance
    'alarm': Icons.alarm_rounded,
    'timer': Icons.timer_rounded,
    'schedule': Icons.schedule_rounded,
    'savings': Icons.savings_rounded,
    'account_balance_wallet': Icons.account_balance_wallet_rounded,
    'payments': Icons.payments_rounded,
    'trending_up': Icons.trending_up_rounded,
    'checklist': Icons.checklist_rounded,
    'task_alt': Icons.task_alt_rounded,
    'bolt': Icons.bolt_rounded,
    'rocket_launch': Icons.rocket_launch_rounded,
    'star': Icons.star_rounded,
    'lightbulb': Icons.lightbulb_rounded,
    'tune': Icons.tune_rounded,
    'all_inclusive': Icons.all_inclusive_rounded,
    // Legacy aliases
    'check': Icons.check_circle_rounded,
    'book': Icons.menu_book_rounded,
    'run': Icons.directions_run_rounded,
    'water': Icons.water_drop_rounded,
    'gym': Icons.fitness_center_rounded,
    'sleep': Icons.bedtime_rounded,
    'meditate': Icons.self_improvement_rounded,
    'money': Icons.savings_rounded,
    'heart': Icons.favorite_rounded,
    'music': Icons.music_note_rounded,
    'food': Icons.restaurant_rounded,
    'phone_off': Icons.phonelink_erase_rounded,
    'study': Icons.school_rounded,
    'sun': Icons.wb_sunny_rounded,
    'leaf': Icons.eco_rounded,
  };

  static const List<IconGroup> categories = [
    IconGroup(
      id: 'fitness',
      nameFa: 'ورزش و سلامت',
      nameEn: 'Health & Fitness',
      keys: [
        'directions_run',
        'fitness_center',
        'self_improvement',
        'directions_walk',
        'directions_bike',
        'pool',
        'hiking',
        'sports_martial_arts',
        'sports_basketball',
        'sports_soccer',
        'monitor_heart',
        'medication',
        'bedtime',
        'wb_sunny',
        'favorite',
        'air',
      ],
    ),
    IconGroup(
      id: 'study',
      nameFa: 'کار و یادگیری',
      nameEn: 'Work & Study',
      keys: [
        'code',
        'terminal',
        'menu_book',
        'auto_stories',
        'edit_note',
        'work',
        'laptop_mac',
        'calculate',
        'science',
        'translate',
        'school',
        'psychology',
      ],
    ),
    IconGroup(
      id: 'food',
      nameFa: 'تغذیه و نوشیدنی',
      nameEn: 'Food & Drink',
      keys: [
        'water_drop',
        'local_drink',
        'coffee',
        'local_cafe',
        'restaurant',
        'bakery_dining',
        'eco',
        'spa',
        'soup_kitchen',
        'no_drinks',
        'emoji_food_beverage',
      ],
    ),
    IconGroup(
      id: 'mind',
      nameFa: 'سبک زندگی و هنر',
      nameEn: 'Lifestyle & Creative',
      keys: [
        'music_note',
        'headphones',
        'palette',
        'brush',
        'camera_alt',
        'piano',
        'pets',
        'yard',
        'cleaning_services',
        'wash',
        'weekend',
        'flight',
      ],
    ),
    IconGroup(
      id: 'quit',
      nameFa: 'ترک و کنترل عادت',
      nameEn: 'Quit & Discipline',
      keys: [
        'smoke_free',
        'smoking_rooms',
        'phonelink_erase',
        'no_food',
        'block',
        'do_not_disturb_on',
        'bedtime_off',
        'alarm_off',
        'videogame_asset_off',
        'money_off',
        'visibility_off',
        'timer_off',
      ],
    ),
    IconGroup(
      id: 'time',
      nameFa: 'زمان و مالی',
      nameEn: 'Time & Finance',
      keys: [
        'alarm',
        'timer',
        'schedule',
        'savings',
        'account_balance_wallet',
        'payments',
        'trending_up',
        'checklist',
        'task_alt',
        'bolt',
        'rocket_launch',
        'star',
        'lightbulb',
        'tune',
        'all_inclusive',
      ],
    ),
  ];

  static IconData iconFor(String key) =>
      icons[key] ?? Icons.check_circle_rounded;
}
