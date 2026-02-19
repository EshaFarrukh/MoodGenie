import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MoodRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  MoodRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  // Get current user ID
  String? get userId => _auth.currentUser?.uid;

  /// Fetches mood data for the last 7 days to display in the summary chart.
  Future<Map<String, dynamic>> getMoodSummary() async {
    final uid = userId;
    if (uid == null) {
      return {'bars': <double>[], 'average': 0.0, 'counts': <String, int>{}, 'total': 0};
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));

    final snap = await _firestore
        .collection('moods')
        .where('userId', isEqualTo: uid)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('createdAt', descending: false)
        .get();

    // Create a map for each day's intensities
    final dailyIntensities = <String, List<double>>{};
    final moodCounts = <String, int>{};

    for (var doc in snap.docs) {
      final data = doc.data();
      final ts = data['createdAt'] as Timestamp;
      final date = ts.toDate();
      final dayKey = '${date.year}-${date.month}-${date.day}';
      final intensity = (data['intensity'] as num?)?.toDouble() ?? 5.0;
      final mood = (data['mood'] ?? 'unknown') as String;

      dailyIntensities.putIfAbsent(dayKey, () => []).add(intensity);
      moodCounts[mood.toLowerCase()] = (moodCounts[mood.toLowerCase()] ?? 0) + 1;
    }

    // Calculate average for each of the 7 days
    final bars = <double>[];
    double totalAvg = 0.0;
    int daysWithData = 0;

    for (int i = 0; i < 7; i++) {
      final day = sevenDaysAgo.add(Duration(days: i));
      final dayKey = '${day.year}-${day.month}-${day.day}';

      if (dailyIntensities.containsKey(dayKey) && dailyIntensities[dayKey]!.isNotEmpty) {
        final dayAvg = dailyIntensities[dayKey]!.reduce((a, b) => a + b) / dailyIntensities[dayKey]!.length;
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
      'total': snap.docs.length,
    };
  }
  /// Adds a new mood entry to Firestore.
  Future<void> addMood({
    required String mood,
    required int intensity,
    required DateTime date,
    String? note,
  }) async {
    final uid = userId;
    if (uid == null) throw Exception('User not logged in');

    await _firestore.collection('moods').add({
      'userId': uid,
      'mood': mood,
      'intensity': intensity,
      'note': note ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'selectedDate': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
    });
  }
}
