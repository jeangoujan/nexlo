import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../theme/app_theme.dart';
import '../data/hive_boxes.dart';
import '../data/models/skill.dart';
import 'add_skill_screen.dart';
import 'session_timer_screen.dart';
import 'skill_stats_screen.dart';
import 'settings_screen.dart';
import 'add_existing_skill_screen.dart';
import 'package:flutter/services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Box<Skill> skillBox;
  final Map<int, double> _previousHours = {}; // для анимации пульса

  Duration _defaultSessionDuration = const Duration(hours: 1, minutes: 30);

  @override
  void initState() {
    super.initState();
    skillBox = HiveBoxes.skillBox();
    _loadDefaultDuration();
  }

  Future<void> _loadDefaultDuration() async {
    final box = await Hive.openBox('settings');
    final minutes = box.get('defaultDurationMinutes', defaultValue: 90);
    setState(() {
      _defaultSessionDuration = Duration(minutes: minutes);
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'My Skills',
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: isDark ? textLight : textDark,
          ),
        ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ).then((_) => _loadDefaultDuration());
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? const Color(0xFF1F241F) : Colors.white,
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF232823)
                      : const Color(0xFFE7ECE7),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.55)
                        : Colors.black.withOpacity(0.10),
                    offset: const Offset(4, 4),
                    blurRadius: 10,
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.white.withOpacity(0.07)
                        : Colors.white,
                    offset: const Offset(-3, -3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                Icons.settings_rounded,
                size: 22,
                color: mintPrimary,
              ),
            ),
          ),
        ),
      ],
    ),
      
      body: SafeArea(
  minimum: const EdgeInsets.only(top: 8),
  child: ValueListenableBuilder(
    valueListenable: skillBox.listenable(),
    builder: (context, Box<Skill> box, _) {
      final skills = box.values.toList();
      // print('📦 Skills from Hive:');
      // for (final s in skills) {
      //   print('   ${s.name}: ${s.totalHours.toStringAsFixed(2)} h');
      // }

      if (skills.isEmpty) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Illustration circle
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? const Color(0xFF1A1F1A) : Colors.white,
            border: Border.all(
              color: isDark ? const Color(0xFF232823) : const Color(0xFFE7ECE7),
              width: 1.2,
            ),
            boxShadow: isDark
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.50),
                      offset: const Offset(8, 8),
                      blurRadius: 18,
                    ),
                    BoxShadow(
                      color: Colors.white.withOpacity(0.06),
                      offset: const Offset(-6, -6),
                      blurRadius: 14,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      offset: const Offset(8, 8),
                      blurRadius: 18,
                    ),
                    const BoxShadow(
                      color: Colors.white,
                      offset: Offset(-6, -6),
                      blurRadius: 14,
                    ),
                  ],
          ),
          child: Icon(
            Icons.auto_awesome_rounded,  // Или другой: Icons.spa_rounded, Icons.star_rounded, Icons.bolt_rounded
            size: 46,
            color: mintPrimary,
          ),
        ),

        const SizedBox(height: 26),

        Text(
          "No skills yet",
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: isDark ? textLight : textDark,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Tap "Add Skill" to begin',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    ),
  );
}

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: ListView.separated(
          key: ValueKey(skills.length),
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
          itemCount: skills.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, i) {
            final s = skills[i];

            // 🔄 Проверяем, выросло ли количество часов
            final prev = _previousHours[s.id] ?? s.totalHours;
            final increased = s.totalHours > prev;
            _previousHours[s.id] = s.totalHours;

            // 🧠 Считаем реальное время по всем сессиям из Hive
            final sessionBox = HiveBoxes.sessionBox();
            final sessionsForSkill =
                sessionBox.values.where((sess) => sess.skillId == s.id).toList();

            final baselineHours = s.totalHours;

            final sessionMinutes = sessionsForSkill.fold<double>(
              0,
              (sum, sess) => sum + sess.durationMinutes,
            );

            final totalHours = baselineHours + (sessionMinutes / 60.0);

            // округляем вниз до целого
            final displayHours = totalHours < 1 ? 0 : totalHours.floor();
            final hoursLabel =
                '$displayHours ${displayHours == 1 ? "hour" : "hours"}';

            return _AnimatedPulse(
              active: increased,
              child: GestureDetector(
                onLongPress: () async {
  final action = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 10, bottom: 26),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF181C18) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: isDark ? const Color(0xFF232823) : const Color(0xFFE7ECE7),
            width: 1,
          ),
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.55),
                    offset: const Offset(10, 10),
                    blurRadius: 22,
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(0.07),
                    offset: const Offset(-8, -8),
                    blurRadius: 18,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    offset: const Offset(10, 10),
                    blurRadius: 22,
                  ),
                  const BoxShadow(
                    color: Colors.white,
                    offset: Offset(-8, -8),
                    blurRadius: 18,
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Column(
                children: [

                  /// --- RENAME ---
                  _AnimatedTap(
                    borderRadius: 22,
                    onTap: () => Navigator.pop(ctx, 'rename'),
                    child: _choiceTile(
                      isDark: isDark,
                      icon: Icons.edit_rounded,
                      iconBg: Colors.blue.withOpacity(0.15),
                      iconColor: Colors.blueAccent,
                      title: "Rename skill",
                    ),
                  ),

                  const SizedBox(height: 14),

                  /// --- EDIT GOAL ---
                  _AnimatedTap(
                    borderRadius: 22,
                    onTap: () => Navigator.pop(ctx, 'goal'),
                    child: _choiceTile(
                      isDark: isDark,
                      icon: Icons.flag_rounded,
                      iconBg: Colors.orange.withOpacity(0.15),
                      iconColor: Colors.orangeAccent,
                      title: "Edit goal hours",
                    ),
                  ),

                  const SizedBox(height: 14),

                  /// --- DELETE ---
                  _AnimatedTap(
                    borderRadius: 22,
                    onTap: () => Navigator.pop(ctx, 'delete'),
                    child: _choiceTile(
                      isDark: isDark,
                      icon: Icons.delete_outline_rounded,
                      iconBg: Colors.red.withOpacity(0.15),
                      iconColor: Colors.redAccent,
                      title: "Delete skill",
                    ),
                  ),

                ],
              ),
            )
          ],
        ),
      );
    },
  );

  if (action == 'rename') {
    final controller = TextEditingController(text: s.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C201C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Rename Skill', style: TextStyle(fontFamily: 'Inter')),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(hintText: 'Enter new name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty) {
      s.name = newName.trim();
      await s.save();
      setState(() {});
    }
  } else if (action == 'goal') {
    final controller = TextEditingController(text: s.goalHours.toStringAsFixed(0));
    final newGoal = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1C201C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Goal Hours', style: TextStyle(fontFamily: 'Inter')),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: const InputDecoration(hintText: 'Enter goal in hours'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (newGoal != null && newGoal.isNotEmpty) {
      final parsed = double.tryParse(newGoal);
      if (parsed != null) {
        s.goalHours = parsed;
        await s.save();
        setState(() {});
      }
    }
  }    else if (action == 'delete') {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: isDark ? const Color(0xFF1C201C) : Colors.white,
        title: Text(
          'Delete "${s.name}"?',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        content: Text(
          'This will remove the skill and all its sessions.',
          style: TextStyle(
            fontFamily: 'Inter',
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.black87,
                fontFamily: 'Inter',
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Colors.redAccent,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      debugPrint('🧩 DELETE skill: name=${s.name} id=${s.id} key=${s.key}');
      debugPrint('📦 skills box: len=${skillBox.length} keys=${skillBox.keys.take(20).toList()}');
      // 1️⃣ Удаляем все сессии этого скилла
      final sessionBox = HiveBoxes.sessionBox();
      final sessionsToDelete = sessionBox.values
          .where((sess) => sess.skillId == s.id)
          .toList();

      for (final sess in sessionsToDelete) {
        await sess.delete(); // id сессии = ключ
      }

      // 2️⃣ Удаляем сам скилл
      await s.delete(); // вместо deleteAt(i)

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
            elevation: 8,
            margin: const EdgeInsets.symmetric(horizontal: 50, vertical: 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            content: Center(
              child: Text(
                '"${s.name}" deleted',
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }
},
                child: _SkillCard(
                  name: s.name,
                  hoursLabel: hoursLabel,
                  icon: IconData(s.iconCode, fontFamily: 'MaterialIcons'),
                  circleColor: Color(s.colorValue),
                  iconColor: _getAdaptiveIconColor(Color(s.colorValue), isDark),
                  onCardTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SkillStatsScreen(skill: s),
                      ),
                    );
                  },
                  onStartTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        fullscreenDialog: false,
                        builder: (_) => SessionTimerScreen(
                          skillName: s.name,
                          skillId: s.id,
                          targetDuration: _defaultSessionDuration,
                        ),
                      ),
                    );
                    setState(() {}); // обновим при возврате
                  },
                ),
              ),
            );
          },
        ),
      );
    },
  ),
),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _AddSkillFab(
  onPressed: () async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  HapticFeedback.lightImpact();

final choice = await showModalBottomSheet<String>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 10, bottom: 26),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C18) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color: isDark ? const Color(0xFF232823) : const Color(0xFFE7ECE7),
          width: 1,
        ),
        boxShadow: isDark
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  offset: const Offset(10, 10),
                  blurRadius: 22,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.07),
                  offset: const Offset(-8, -8),
                  blurRadius: 18,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.10),
                  offset: const Offset(10, 10),
                  blurRadius: 22,
                ),
                const BoxShadow(
                  color: Colors.white,
                  offset: Offset(-8, -8),
                  blurRadius: 18,
                ),
              ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // drag handle
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white12 : Colors.black12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),

          const SizedBox(height: 20),

          // centered title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Are you starting something new?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: isDark ? textLight : textDark,
              ),
            ),
          ),

          const SizedBox(height: 26),

          // choice 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AnimatedTap(
              borderRadius: 22,
              onTap: () => Navigator.pop(ctx, 'new'),
              child: _choiceTile(
                isDark: isDark,
                icon: Icons.add_rounded,
                iconBg: mintPrimary.withOpacity(0.12),
                iconColor: mintPrimary,
                title: 'This is something new',
              ),
            ),
          ),

          const SizedBox(height: 14),

          // choice 2
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _AnimatedTap(
              borderRadius: 22,
              onTap: () => Navigator.pop(ctx, 'existing'),
              child: _choiceTile(
                isDark: isDark,
                icon: Icons.history_rounded,
                iconBg: const Color(0xFFF6C84E).withOpacity(0.15),
                iconColor: const Color(0xFFF6C84E),
                title: "I've practiced this before",
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  },
);

  if (choice == 'new') {
    final newSkill = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddSkillScreen()),
    );
    //if (newSkill != null && newSkill is Skill) {
    //  await skillBox.add(newSkill);  // skillBox.put(newSkill.id, newSkill);
    //}
  } else if (choice == 'existing') {
    final existingSkill = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddExistingSkillScreen()),
    );
    //if (existingSkill != null && existingSkill is Skill) {
    //  await skillBox.add(existingSkill);// skillBox.put(existingSkill.id, existingSkill);
   // }
  }
},
),
    );
  }
}

// ---------------------------------------------------------------------------
// Skill Card UI
// ---------------------------------------------------------------------------

class _SkillCard extends StatelessWidget {
  final String name;
  final String hoursLabel;
  final IconData icon;
  final Color circleColor;
  final Color iconColor;
  final VoidCallback onCardTap;
  final VoidCallback onStartTap;

  const _SkillCard({
    super.key,
    required this.name,
    required this.hoursLabel,
    required this.icon,
    required this.circleColor,
    required this.iconColor,
    required this.onCardTap,
    required this.onStartTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF181C18) : Colors.white;

    final neuShadows = isDark
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              offset: const Offset(8, 8),
              blurRadius: 18,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.07),
              offset: const Offset(-6, -6),
              blurRadius: 14,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              offset: const Offset(8, 8),
              blurRadius: 18,
            ),
            const BoxShadow(
              color: Colors.white,
              offset: Offset(-6, -6),
              blurRadius: 12,
            ),
          ];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color:
              isDark ? const Color(0xFF232823) : const Color(0xFFE7ECE7),
          width: 1,
        ),
        boxShadow: neuShadows,
      ),
      child: _AnimatedTap(
        onTap: onCardTap,
        borderRadius: 28,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: circleColor.withOpacity(isDark ? 0.9 : 0.85),
                  border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFE7ECE7),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: iconColor, // ← ВАЖНО!
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        color: isDark ? textLight : textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hoursLabel,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'Inter',
                        color: isDark
                            ? Colors.white.withOpacity(0.7)
                            : Colors.black.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AnimatedTap(
                onTap: onStartTap,
                borderRadius: 30,
                isButton: true,
                child: const _StartPill(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pulse Animation
// ---------------------------------------------------------------------------

class _AnimatedPulse extends StatefulWidget {
  final Widget child;
  final bool active;
  const _AnimatedPulse({required this.child, required this.active});

  @override
  State<_AnimatedPulse> createState() => _AnimatedPulseState();
}

class _AnimatedPulseState extends State<_AnimatedPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  }

  @override
  void didUpdateWidget(covariant _AnimatedPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_ctrl.isAnimating) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final glow = (1 - _ctrl.value) * 0.35;
        return Container(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: mintPrimary.withOpacity(glow),
                blurRadius: 30 * (1 - _ctrl.value),
                spreadRadius: 2 * (1 - _ctrl.value),
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Остальные вспомогательные классы (_StartPill, _AddSkillFab, _AnimatedTap)
// ---------------------------------------------------------------------------
// оставлены без изменений из твоей версии.
// ---------------------------------------------------------------------------
// Start button
// ---------------------------------------------------------------------------

class _StartPill extends StatelessWidget {
  const _StartPill();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F241F) : Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.45 : 0.08),
            offset: const Offset(3, 3),
            blurRadius: 10,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(isDark ? 0.08 : 1),
            offset: const Offset(-3, -3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Text(
        'Start',
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          fontSize: 17,
          color: theme.colorScheme.secondary,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Floating Button
// ---------------------------------------------------------------------------

class _AddSkillFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddSkillFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(
            color: primary.withOpacity(0.35),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add, size: 22),
        label: const Text(
          'Add Skill',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tap Animation
// ---------------------------------------------------------------------------

class _AnimatedTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double borderRadius;
  final bool isButton;

  const _AnimatedTap({
    required this.child,
    required this.onTap,
    this.borderRadius = 20,
    this.isButton = false,
  });

  @override
  State<_AnimatedTap> createState() => _AnimatedTapState();
}

class _AnimatedTapState extends State<_AnimatedTap> {
  bool _pressed = false;

  void _down(TapDownDetails _) => setState(() => _pressed = true);
  void _up(TapUpDetails _) => setState(() => _pressed = false);
  void _cancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final shadowUp = isDark
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              offset: const Offset(5, 5),
              blurRadius: 10,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.07),
              offset: const Offset(-4, -4),
              blurRadius: 10,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              offset: const Offset(6, 6),
              blurRadius: 12,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.95),
              offset: const Offset(-4, -4),
              blurRadius: 10,
            ),
          ];

    final shadowDown = isDark
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.75),
              offset: const Offset(2, 2),
              blurRadius: 5,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.04),
              offset: const Offset(-2, -2),
              blurRadius: 6,
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              offset: const Offset(2, 2),
              blurRadius: 6,
            ),
            BoxShadow(
              color: Colors.white.withOpacity(0.8),
              offset: const Offset(-2, -2),
              blurRadius: 6,
            ),
          ];

    final applied = _pressed
        ? (widget.isButton ? _boost(shadowDown, 1.2) : shadowDown)
        : (widget.isButton ? _boost(shadowUp, 1.1) : shadowUp);

    return GestureDetector(
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onTap: widget.onTap,
      behavior: HitTestBehavior.translucent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          boxShadow: applied,
        ),
        child: widget.child,
      ),
    );
  }

  List<BoxShadow> _boost(List<BoxShadow> src, double k) =>
      src.map((s) => s.copyWith(blurRadius: s.blurRadius * k)).toList();
}

Future<String?> _showRenameDialog(BuildContext context, String oldName, bool isDark) {
  final controller = TextEditingController(text: oldName);
  return showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C201C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Rename Skill', style: TextStyle(fontFamily: 'Inter')),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: const InputDecoration(hintText: 'Enter new name'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
      ],
    ),
  );
}

Future<double?> _showGoalDialog(BuildContext context, double oldGoal, bool isDark) async {
  final controller = TextEditingController(text: oldGoal.toStringAsFixed(0));
  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C201C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit Goal Hours', style: TextStyle(fontFamily: 'Inter')),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: const InputDecoration(hintText: 'Enter goal in hours'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Save')),
      ],
    ),
  );

  if (result == null || result.isEmpty) return null;
  return double.tryParse(result);
}

class _ActionSheetTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionSheetTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      onTap: onTap,
    );
  }
}

Widget _choiceTile({
  required bool isDark,
  required IconData icon,
  required Color iconBg,
  required Color iconColor,
  required String title,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    decoration: BoxDecoration(
      color: isDark ? const Color(0xFF1A1F1A) : Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: isDark ? const Color(0xFF232823) : const Color(0xFFE7ECE7),
        width: 1,
      ),
      boxShadow: isDark
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                offset: const Offset(6, 6),
                blurRadius: 14,
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.07),
                offset: const Offset(-6, -6),
                blurRadius: 12,
              ),
            ]
          : [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                offset: const Offset(6, 6),
                blurRadius: 14,
              ),
              const BoxShadow(
                color: Colors.white,
                offset: Offset(-6, -6),
                blurRadius: 12,
              ),
            ],
    ),
    child: Row(
      children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE7ECE7),
            ),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDark ? textLight : textDark,
            ),
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 20),
      ],
    ),
  );
}


Color _getAdaptiveIconColor(Color base, bool isDark) {
  if (isDark) {
    // В тёмной теме ВСЕГДА белая или почти белая иконка
    return Colors.white.withOpacity(0.9);
  }

  // В светлой теме — затемняем оригинальный цвет
  return _darken(base, 0.32);
}

Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  final hslDark = hsl.withLightness(
    (hsl.lightness - amount).clamp(0.0, 1.0),
  );
  return hslDark.toColor();
}