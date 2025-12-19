// data/hive_boxes.dart
import 'package:hive_flutter/hive_flutter.dart';
import 'models/skill.dart';
import 'models/session.dart';

class HiveBoxes {
  static const skills = 'skills';
  static const sessions = 'sessions';
  static const timer = 'timer_state'; // для восстановления таймера

  static Future<void> init() async {
    // ❌ Больше НЕ вызываем Hive.initFlutter() здесь

    // регистрируем адаптеры (делать один раз, до открытия боксов)
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(SkillAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(SessionAdapter());

    await Hive.openBox<Skill>(skills);
    await Hive.openBox<Session>(sessions);
    await Hive.openBox(timer); // тут будет Map<String, dynamic>-подобное хранилище
    final skillBox = Hive.box<Skill>(skills);
  }

  static Box<Skill> skillBox() => Hive.box<Skill>(skills);
  static Box<Session> sessionBox() => Hive.box<Session>(sessions);
  static Box timerBox() => Hive.box(timer);
}