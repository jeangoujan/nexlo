import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../data/models/skill.dart';
import '../data/models/session.dart';
import '../theme/app_theme.dart';
import '../data/hive_boxes.dart';
import 'skills_detail_screen.dart';

class SkillStatsScreen extends StatefulWidget {
  final Skill skill;
  const SkillStatsScreen({super.key, required this.skill});

  @override
  State<SkillStatsScreen> createState() => _SkillStatsScreenState();
}

class _SkillStatsScreenState extends State<SkillStatsScreen> {
  bool _goalShown = false;

  @override
  Widget build(BuildContext context) {
    final skill = widget.skill;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final skillBox = HiveBoxes.skillBox();
    final sessionBox = Hive.box<Session>('sessions');

    return ValueListenableBuilder(
      valueListenable: skillBox.listenable(),
      builder: (context, _, __) {
        final liveSkill = skillBox.get(skill.id) ?? skill;

        return ValueListenableBuilder(
          valueListenable: sessionBox.listenable(),
          builder: (context, __, ___) {
            final sessions = sessionBox.values
                .where((s) => s.skillId == liveSkill.id)
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            // --- Total minutes ---
            final baselineMinutes = liveSkill.totalHours * 60;

            final sessionMinutes = sessions.fold<double>(
              0,
              (sum, s) => sum + s.durationMinutes,
            );

            final totalMinutes = baselineMinutes + sessionMinutes;
            final totalHours = totalMinutes / 60.0;



            // --- Exact progress (no rounding) ---
            double goalProgress = 0.0;
            if (liveSkill.goalHours > 0) {
              goalProgress = (totalHours / liveSkill.goalHours);
            }

            final goalPercent = (goalProgress * 100).clamp(0, 999);

            // --- Format total for UI ---
            final formattedTotal = _formatDuration(totalMinutes);

            // --- Show bottom sheet only if real goal reached ---
            final truncatedHours = double.parse(_truncate1(totalHours));

              if (!_goalShown &&
              truncatedHours >= liveSkill.goalHours &&
              liveSkill.goalHours > 0) {

            _goalShown = true;

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showGoalReachedSheet(
                context,
                liveSkill,
                totalHours,
                goalPercent.toDouble(),
              );
            });
          }

            final weekStats = _calculateWeeklyStats(sessions);
            final last5 = sessions.take(5).toList();

            final now = DateTime.now();
            final weekStart = _mondayOf(now);
            final weekEnd = _sundayOf(now);

            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF0F120F) : Colors.white,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                centerTitle: true,
                title: Text(
                  '${liveSkill.name} Practice',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    color: isDark ? textLight : textDark,
                  ),
                ),
              ),
              
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// CREATED AT
                      Center(
                        child: Text(
                          'Created: ${_formatCreatedDate(liveSkill.createdAt)}',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // --- Top stats ---
                      Row(
                        children: [
                          Expanded(
                            child: _NeuroStatCard(
                              label: 'Total Time',
                              value: formattedTotal,
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _NeuroStatCard(
                              label: 'Current Streak',
                              value: '${liveSkill.currentStreak} days',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // --- Goal Progress ---
                      Text(
                        'Goal Progress',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDark ? textLight : textDark,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NeuroProgressBar(
                        progress: goalProgress.clamp(0, 1),
                        label:
                            '${_truncate1(totalHours)} / ${_truncate1(liveSkill.goalHours)} h • ${goalPercent.floor().toString()}%',
                        isDark: isDark,
                      ),

                      const SizedBox(height: 24),

                      // --- Weekly Progress ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Weekly Progress',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: isDark ? textLight : textDark,
                            ),
                          ),
                          Text(
                            '${_fmtDM(weekStart)} – ${_fmtDM(weekEnd)}',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _WeeklySummary(
                        totalMinutes: weekStats['thisWeek'],
                        percentChange: weekStats['percentChange'],
                        daysActive: weekStats['daysActive'],
                        isDark: isDark,
                      ),

                      const SizedBox(height: 30),

                      // --- Recent Sessions ---
                      Text(
                        'Recent Sessions',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: isDark ? textLight : textDark,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (last5.isEmpty)
                        Text(
                          'No sessions yet.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ...last5.map((s) => _DetailedSessionCard(s: s, isDark: isDark)),
                      const SizedBox(height: 24),

                      // --- All Sessions button ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: mintPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 8,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SkillDetailScreen(
                                  skillName: liveSkill.name,
                                  hoursDone: totalHours,
                                  goalHours: liveSkill.goalHours,
                                  skillId: liveSkill.id,
                                ),
                              ),
                            );
                          },
                          child: const Text(
                            'All Sessions →',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ---------------------- Helpers ----------------------

  String _formatDuration(double minutes) {
    if (minutes < 1) return '${(minutes * 60).round()} sec';
    if (minutes < 60) return '${minutes.floor()} min';

    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return '${h}h ${m}min';
  }

  Map<String, dynamic> _calculateWeeklyStats(List<Session> sessions) {
    final now = DateTime.now();
    final startOfWeek = _mondayOf(now);
    final startOfLastWeek = startOfWeek.subtract(const Duration(days: 7));

    double thisWeek = 0;
    double lastWeek = 0;
    final activeDays = <int>{};

    for (final s in sessions) {
      if (!s.date.isBefore(startOfWeek)) {
        thisWeek += s.durationMinutes;
        activeDays.add(s.date.weekday);
      } else if (!s.date.isBefore(startOfLastWeek) &&
          s.date.isBefore(startOfWeek)) {
        lastWeek += s.durationMinutes;
      }
    }

    double? percentChange;
    if (lastWeek > 0) percentChange = ((thisWeek - lastWeek) / lastWeek) * 100;

    return {
      'thisWeek': thisWeek,
      'percentChange': percentChange,
      'daysActive': activeDays,
    };
  }
}

// ---------------------- UI COMPONENTS ----------------------

class _DetailedSessionCard extends StatelessWidget {
  final Session s;
  final bool isDark;
  const _DetailedSessionCard({required this.s, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C18) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.55 : 0.1),
            offset: const Offset(6, 6),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(isDark ? 0.08 : 0.9),
            offset: const Offset(-6, -6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDuration(s.durationMinutes),
            style: theme.textTheme.titleMedium?.copyWith(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: isDark ? textLight : textDark,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatDate(s.date),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          if (s.note?.isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                s.note!,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                  color: isDark ? Colors.white70 : Colors.black.withOpacity(0.65),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  String _formatDuration(double minutes) {
    if (minutes < 1) return '${(minutes * 60).round()} sec';
    if (minutes < 60) return '${minutes.floor()} min';
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return '${h}h ${m}min';
  }
}

class _NeuroStatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  const _NeuroStatCard({
    required this.label,
    required this.value,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C18) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.55 : 0.1),
            offset: const Offset(6, 6),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(isDark ? 0.08 : 0.9),
            offset: const Offset(-6, -6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: isDark ? textLight : textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeuroProgressBar extends StatelessWidget {
  final double progress;
  final String label;
  final bool isDark;
  const _NeuroProgressBar({
    required this.progress,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C18) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.55 : 0.1),
            offset: const Offset(5, 5),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(isDark ? 0.08 : 0.9),
            offset: const Offset(-5, -5),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(
            value: progress,
            color: mintPrimary,
            backgroundColor: isDark ? Colors.white12 : Colors.black12,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  final double totalMinutes;
  final double? percentChange;
  final Set<int> daysActive;
  final bool isDark;

  const _WeeklySummary({
    required this.totalMinutes,
    required this.percentChange,
    required this.daysActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = _formatDuration(totalMinutes);
    final weekDays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181C18) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.55 : 0.1),
            offset: const Offset(6, 6),
            blurRadius: 14,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(isDark ? 0.08 : 0.9),
            offset: const Offset(-6, -6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatted,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDark ? textLight : textDark,
            ),
          ),
          Text(
            percentChange == null
                ? '—'
                : '${percentChange! >= 0 ? '+' : ''}${percentChange!.toStringAsFixed(1)}%',
            style: TextStyle(
              color: percentChange == null
                  ? (isDark ? Colors.white38 : Colors.black26)
                  : (percentChange! >= 0 ? mintPrimary : Colors.redAccent),
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final active = daysActive.contains(i + 1);
              return Column(
                children: [
                  Icon(
                    active ? Icons.check_circle : Icons.circle_outlined,
                    color: active
                        ? mintPrimary
                        : (isDark ? Colors.white24 : Colors.black12),
                    size: 22,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    weekDays[i],
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  String _formatDuration(double minutes) {
    if (minutes < 1) return '${(minutes * 60).round()} sec';
    if (minutes < 60) return '${minutes.floor()} min';
    final h = minutes ~/ 60;
    final m = (minutes % 60).round();
    return '${h}h ${m}min';
  }
}

// ---------------------- DATE HELPERS ----------------------

DateTime _mondayOf(DateTime d) {
  final delta = (d.weekday + 6) % 7;
  return DateTime(d.year, d.month, d.day).subtract(Duration(days: delta));
}

DateTime _sundayOf(DateTime d) => _mondayOf(d).add(const Duration(days: 6));

String _fmtDM(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';

String _formatCreatedDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.'
    '${d.month.toString().padLeft(2, '0')}.'
    '${d.year}';


// Truncate to 1 decimal place WITHOUT rounding (e.g., 19.98 → 19.9)
String _truncate1(double value) {
  return ((value * 10).floor() / 10).toStringAsFixed(1);
}

// ---------------------- GOAL REACHED BOTTOM SHEET ----------------------

Future<void> _showGoalReachedSheet(
  BuildContext context,
  Skill skill,
  double totalHours,
  double goalPercent,
) async {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;

  // avoid multiple triggers


  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (ctx) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: 12, bottom: 26),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // handle
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white12 : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                'Goal reached 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: isDark ? textLight : textDark,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'You have completed your goal of '
                '${skill.goalHours.toStringAsFixed(0)} hours\n'
                'for "${skill.name}".',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                '${goalPercent.toStringAsFixed(0)}% done — amazing work 💚',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: mintPrimary,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: Text(
                        'Okay',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: mintPrimary,
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () async {
                        final newGoal = await _showNewGoalDialog(
                          context,
                          minHours: totalHours,
                          isDark: isDark,
                        );
                        if (newGoal == null) return;

                        if (newGoal < totalHours) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'New goal must not be less than time already done.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: 'Inter'),
                              ),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 30),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                          return;
                        }

                        await _updateSkillGoal(skill, newGoal);

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'New goal set to ${newGoal.toStringAsFixed(0)} hours',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontFamily: 'Inter'),
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 40, vertical: 30),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            duration: const Duration(seconds: 2),
                          ),
                        );

                        Navigator.of(ctx).pop();
                      },
                      child: const Text(
                        'Set new goal',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

Future<double?> _showNewGoalDialog(
  BuildContext context, {
  required double minHours,
  required bool isDark,
}) async {
  final controller = TextEditingController(
    text: minHours.toStringAsFixed(0),
  );

  final result = await showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1C201C) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Set new goal', style: TextStyle(fontFamily: 'Inter')),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          hintText: 'Enter goal in hours (≥ ${minHours.toStringAsFixed(0)})',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          child: const Text('Save'),
        ),
      ],
    ),
  );

  if (result == null || result.isEmpty) return null;
  return double.tryParse(result);
}

Future<void> _updateSkillGoal(Skill skill, double newGoal) async {
  final box = HiveBoxes.skillBox();

  for (final key in box.keys) {
    final value = box.get(key);
    if (value != null && value.id == skill.id) {
      value.goalHours = newGoal;
      await value.save();
    }
  }
}

