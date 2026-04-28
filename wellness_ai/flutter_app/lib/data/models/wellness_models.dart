// Core data models for Wellness AI

class UserProfile {
  final String userId;
  final List<String> goals;
  final String fitnessLevel;
  final int streakDays;
  final int totalCheckins;
  final DailyCheckin? lastCheckin;

  const UserProfile({
    required this.userId,
    required this.goals,
    required this.fitnessLevel,
    required this.streakDays,
    required this.totalCheckins,
    this.lastCheckin,
  });

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
        userId: j['user_id'],
        goals: List<String>.from(j['goals'] ?? []),
        fitnessLevel: j['fitness_level'] ?? 'beginner',
        streakDays: j['streak_days'] ?? 0,
        totalCheckins: j['total_checkins'] ?? 0,
        lastCheckin: j['last_checkin'] != null
            ? DailyCheckin.fromJson(j['last_checkin'])
            : null,
      );
}

class DailyCheckin {
  final String date;
  final double sleepHours;
  final int stressLevel;
  final int energyLevel;
  final String mood;
  final String notes;

  const DailyCheckin({
    required this.date,
    required this.sleepHours,
    required this.stressLevel,
    required this.energyLevel,
    required this.mood,
    this.notes = '',
  });

  factory DailyCheckin.fromJson(Map<String, dynamic> j) => DailyCheckin(
        date: j['date'],
        sleepHours: (j['sleep_hours'] as num).toDouble(),
        stressLevel: j['stress_level'],
        energyLevel: j['energy_level'],
        mood: j['mood'],
        notes: j['notes'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'sleep_hours': sleepHours,
        'stress_level': stressLevel,
        'energy_level': energyLevel,
        'mood': mood,
        'notes': notes,
      };
}

class WellnessActivity {
  final String routineActivityId;
  final String id;
  final String name;
  final int duration;
  final String timeOfDay;
  final String description;
  final String goal;
  bool completed;
  String? completedAt;

  WellnessActivity({
    required this.routineActivityId,
    required this.id,
    required this.name,
    required this.duration,
    required this.timeOfDay,
    required this.description,
    required this.goal,
    this.completed = false,
    this.completedAt,
  });

  factory WellnessActivity.fromJson(Map<String, dynamic> j) => WellnessActivity(
        routineActivityId: j['routine_activity_id'] ?? j['id'],
        id: j['id'],
        name: j['name'],
        duration: j['duration'] ?? 0,
        timeOfDay: j['time_of_day'] ?? 'any',
        description: j['description'] ?? '',
        goal: j['goal'] ?? '',
        completed: j['completed'] ?? false,
        completedAt: j['completed_at'],
      );
}

class DailyRoutine {
  final String routineId;
  final String date;
  final List<WellnessActivity> activities;
  final int totalDurationMinutes;
  final String message;
  final Map<String, dynamic> adaptedFor;

  const DailyRoutine({
    required this.routineId,
    required this.date,
    required this.activities,
    required this.totalDurationMinutes,
    required this.message,
    required this.adaptedFor,
  });

  factory DailyRoutine.fromJson(Map<String, dynamic> j) => DailyRoutine(
        routineId: j['routine_id'],
        date: j['date'],
        activities: (j['activities'] as List)
            .map((a) => WellnessActivity.fromJson(a))
            .toList(),
        totalDurationMinutes: j['total_duration_minutes'] ?? 0,
        message: j['message'] ?? '',
        adaptedFor: Map<String, dynamic>.from(j['adapted_for'] ?? {}),
      );

  int get completedCount => activities.where((a) => a.completed).length;
  double get completionRate =>
      activities.isEmpty ? 0 : completedCount / activities.length;
}

class ConsistencyReport {
  final int periodDays;
  final int checkinDays;
  final int activitiesCompleted;
  final int activitiesTotal;
  final double completionRate;
  final int currentStreakDays;
  final String trend;
  final Map<String, double> averages;

  const ConsistencyReport({
    required this.periodDays,
    required this.checkinDays,
    required this.activitiesCompleted,
    required this.activitiesTotal,
    required this.completionRate,
    required this.currentStreakDays,
    required this.trend,
    required this.averages,
  });

  factory ConsistencyReport.fromJson(Map<String, dynamic> j) => ConsistencyReport(
        periodDays: j['period_days'],
        checkinDays: j['checkin_days'],
        activitiesCompleted: j['activities_completed'],
        activitiesTotal: j['activities_total'],
        completionRate: (j['completion_rate'] as num).toDouble(),
        currentStreakDays: j['current_streak_days'],
        trend: j['trend'],
        averages: Map<String, double>.from(
          (j['averages'] as Map).map((k, v) => MapEntry(k, (v as num).toDouble())),
        ),
      );
}
