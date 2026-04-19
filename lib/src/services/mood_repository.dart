import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoodRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  static const String _usersCollection = 'users';
  static const String _moodsCollection = 'moods';
  static const List<String> _dateFields = [
    'selectedDate',
    'createdAt',
    'timestamp',
  ];

  MoodRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;

  Future<Map<String, int>> getProfileStats({bool forceRefresh = false}) async {
    final uid = userId;
    if (uid == null) {
      return {'totalMoods': 0, 'streak': 0, 'daysActive': 0};
    }

    final userRef = _firestore.collection(_usersCollection).doc(uid);
    final userSnapshot = await userRef.get();
    final userData = userSnapshot.data();
    final cachedStats = userData?['moodStats'];
    final needsRefresh = userData?['moodStatsNeedsRefresh'] == true;

    if (!forceRefresh && !needsRefresh && cachedStats is Map<String, dynamic>) {
      return {
        'totalMoods': (cachedStats['totalMoods'] as num?)?.toInt() ?? 0,
        'streak': (cachedStats['streak'] as num?)?.toInt() ?? 0,
        'daysActive': (cachedStats['daysActive'] as num?)?.toInt() ?? 0,
      };
    }

    final snapshot = await _firestore
        .collection(_moodsCollection)
        .where('userId', isEqualTo: uid)
        .get();

    final docs = snapshot.docs;
    final total = docs.length;
    final loggedDates =
        docs
            .map((doc) {
              final data = doc.data();
              return (data['selectedDate'] as Timestamp?)?.toDate() ??
                  (data['createdAt'] as Timestamp?)?.toDate() ??
                  (data['timestamp'] as Timestamp?)?.toDate();
            })
            .whereType<DateTime>()
            .map((date) => DateTime(date.year, date.month, date.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    int streak = 0;
    if (loggedDates.isNotEmpty) {
      final now = DateTime.now();
      var checkDate = DateTime(now.year, now.month, now.day);

      for (final date in loggedDates) {
        if (date == checkDate ||
            date == checkDate.subtract(const Duration(days: 1))) {
          streak++;
          checkDate = date.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    final stats = {
      'totalMoods': total,
      'streak': streak,
      'daysActive': loggedDates.length,
    };

    await userRef.set({
      'moodStats': stats,
      'moodStatsNeedsRefresh': false,
      'moodStatsUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    return stats;
  }

  /// Fetches mood data for the last 7 days to display in the summary chart.
  Future<Map<String, dynamic>> getMoodSummary() async {
    final uid = userId;
    if (uid == null) {
      return {
        'bars': <double>[],
        'average': 0.0,
        'counts': <String, int>{},
        'total': 0,
      };
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final endExclusive = today.add(const Duration(days: 1));

    final snapshots = await Future.wait(
      _dateFields.map(
        (field) => _firestore
            .collection(_moodsCollection)
            .where('userId', isEqualTo: uid)
            .where(
              field,
              isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
            )
            .where(field, isLessThan: Timestamp.fromDate(endExclusive))
            .get(),
      ),
    );

    final docsById = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final snapshot in snapshots) {
      for (final doc in snapshot.docs) {
        docsById[doc.id] = doc;
      }
    }

    // Create a map for each day's intensities
    final dailyIntensities = <String, List<double>>{};
    final moodCounts = <String, int>{};

    for (final doc in docsById.values) {
      final data = doc.data();

      final date =
          (data['selectedDate'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.now();

      final pureDate = DateTime(date.year, date.month, date.day);

      // Only process if it falls within the last 7 days window
      if (pureDate.isAfter(sevenDaysAgo.subtract(const Duration(days: 1))) &&
          pureDate.isBefore(endExclusive)) {
        final dayKey = '${pureDate.year}-${pureDate.month}-${pureDate.day}';
        final intensity = (data['intensity'] as num?)?.toDouble() ?? 5.0;
        final mood = (data['mood'] ?? 'unknown') as String;

        dailyIntensities.putIfAbsent(dayKey, () => []).add(intensity);
        moodCounts[mood.toLowerCase()] =
            (moodCounts[mood.toLowerCase()] ?? 0) + 1;
      }
    }

    // Calculate average for each of the 7 days
    final bars = <double>[];
    double totalAvg = 0.0;
    int daysWithData = 0;

    for (int i = 0; i < 7; i++) {
      final day = sevenDaysAgo.add(Duration(days: i));
      final dayKey = '${day.year}-${day.month}-${day.day}';

      if (dailyIntensities.containsKey(dayKey) &&
          dailyIntensities[dayKey]!.isNotEmpty) {
        final dayAvg =
            dailyIntensities[dayKey]!.reduce((a, b) => a + b) /
            dailyIntensities[dayKey]!.length;
        bars.add(dayAvg * 7); // Scale to 70 max height (10 * 7)
        totalAvg += dayAvg;
        daysWithData++;
      } else {
        bars.add(20); // Default small bar for days with no data
      }
    }

    final weeklyAverage = daysWithData > 0 ? totalAvg / daysWithData : 0.0;

    return {
      'bars': bars,
      'average': weeklyAverage,
      'counts': moodCounts,
      'total': docsById.length,
    };
  }

  /// Adds a new mood entry to Firestore.
  Future<void> addMood({
    required String mood,
    required int intensity,
    required DateTime date,
    int? energyLevel,
    int? stressLevel,
    int? waterIntake,
    double? sleepHours,
    List<String>? activities,
    String? note,
  }) async {
    final uid = userId;
    if (uid == null) throw Exception('User not logged in');

    await _firestore.collection(_moodsCollection).add({
      'userId': uid,
      'mood': mood,
      'intensity': intensity,
      'energyLevel': energyLevel ?? 3,
      'stressLevel': stressLevel ?? 5,
      'waterIntake': waterIntake ?? 0,
      'sleepHours': sleepHours ?? 0.0,
      'activities': activities ?? [],
      'note': note ?? '',
      'selectedDate': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection(_usersCollection).doc(uid).set({
      'moodStatsNeedsRefresh': true,
      'moodStatsLastLoggedAt': FieldValue.serverTimestamp(),
      'forecastRefreshNeeded': true,
      'forecastRequestedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
