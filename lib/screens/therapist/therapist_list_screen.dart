import 'package:moodgenie/src/theme/app_background.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../src/theme/app_theme.dart';
import '../home/widgets/glass_card.dart';
import 'appointment_booking_screen.dart';
import '../../src/auth/models/user_model.dart';

class TherapistListScreen extends StatefulWidget {
  const TherapistListScreen({super.key});

  @override
  State<TherapistListScreen> createState() => _TherapistListScreenState();
}

class _TherapistListScreenState extends State<TherapistListScreen> {
  final _therapistsRef = FirebaseFirestore.instance.collection(
    'public_therapists',
  );

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            // Background with app theme gradient
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF4EEFF), // Purple light
                      Color(0xFFFFF7EE), // Orange light
                    ],
                  ),
                ),
              ),
            ),
            // Background image overlay
            const Positioned.fill(child: AppBackground()),
            SafeArea(
              child: Column(
                children: [
                  _CustomHeader(
                    title: 'Find a Therapist',
                    showBack: Navigator.canPop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: GlassCard(
                        gradientColors: [
                          Colors.white.withValues(alpha: 0.9),
                          Colors.white.withValues(alpha: 0.7),
                        ],
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_off_rounded,
                              size: 64,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Please login to access therapist services',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'You need to be logged in to view and book appointments with therapists.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Background with app theme gradient
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF4EEFF), // Purple light
                    Color(0xFFFFF7EE), // Orange light
                  ],
                ),
              ),
            ),
          ),

          // Background image overlay
          const Positioned.fill(child: AppBackground()),

          // Content
          SafeArea(
            child: Column(
              children: [
                _CustomHeader(
                  title: 'Find a Therapist',
                  showBack: Navigator.canPop(context),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      const _ProfessionalSupportCard(),
                      const SizedBox(height: 14),
                      _TherapistsSection(therapistsRef: _therapistsRef),
                      const SizedBox(height: 16),
                      const _ImmediateHelpCard(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfessionalSupportCard extends StatelessWidget {
  const _ProfessionalSupportCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradientColors: [AppColors.primaryLight, Colors.white],
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.accentCyan],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.verified_user_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Professional Support',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
                SizedBox(height: 4),
                Text(
                  'Connect with credential-verified therapists for mental health support and guidance.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TherapistsSection extends StatelessWidget {
  const _TherapistsSection({required this.therapistsRef});
  final CollectionReference<Map<String, dynamic>> therapistsRef;

  Stream<List<TherapistProfile>> _getCombinedTherapistsStream() {
    return therapistsRef.snapshots().asyncMap((therapistSnap) async {
      final visibleProfiles =
          therapistSnap.docs
              .map((doc) => TherapistProfile.fromMap(doc.data(), doc.id))
              .where(
                (profile) =>
                    profile.isApproved &&
                    profile.acceptingNewPatients &&
                    profile.credentialVerificationStatus == 'verified',
              )
              .toList();

      if (visibleProfiles.isEmpty) {
        return <TherapistProfile>[];
      }

      final liveFlags = await Future.wait(
        visibleProfiles.map((profile) async {
          try {
            final therapistSnapshot = await FirebaseFirestore.instance
                .collection('therapists')
                .doc(profile.therapistId)
                .get();
            return therapistSnapshot.exists;
          } catch (_) {
            return false;
          }
        }),
      );

      final profiles = <TherapistProfile>[
        for (var index = 0; index < visibleProfiles.length; index++)
          if (liveFlags[index]) visibleProfiles[index],
      ]..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
      return profiles;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TherapistProfile>>(
      stream: _getCombinedTherapistsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return GlassCard(
            gradientColors: [Colors.white, Colors.white],
            child: Text(
              'Could not load therapists: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final therapistProfiles = snapshot.data ?? [];
        if (therapistProfiles.isEmpty) {
          return GlassCard(
            gradientColors: const [Colors.white, Colors.white],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(
                  Icons.search_off,
                  size: 48,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No therapists available right now.',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Verified therapists will appear here once their profiles have been reviewed.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final data in therapistProfiles) ...[
              Builder(
                builder: (context) {
                  try {
                    return _TherapistCard(profile: data);
                  } catch (e) {
                    // If there's an error parsing a specific therapist, show an error card
                    return GlassCard(
                      gradientColors: [Colors.white, Colors.white],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Error loading therapist',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Therapist ID: ${data.therapistId}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'Error: $e',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        );
      },
    );
  }
}

class _TherapistCard extends StatelessWidget {
  const _TherapistCard({required this.profile});

  final TherapistProfile profile;

  @override
  Widget build(BuildContext context) {
    final nextSlot = profile.nextAvailableAt;
    final nextText = nextSlot == null
        ? 'No slots listed'
        : _formatNextSlot(nextSlot);

    final name = profile.displayName ?? 'Therapist';
    final initials = name
        .split(' ')
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0])
        .join()
        .toUpperCase();

    return GlassCard(
      gradientColors: [Colors.white, Colors.white.withValues(alpha: 0.8)],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.pillCyan,
            child: Text(
              initials,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.star_rounded,
                      size: 18,
                      color: AppColors.accentCyan,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      (profile.rating ?? 5.0).toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  profile.specialty ?? 'General Practice',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    _Pill(
                      icon: Icons.work_outline,
                      text: '${profile.yearsExperience ?? 0} years',
                    ),
                    _Pill(
                      icon: Icons.payments_outlined,
                      text: 'PKR ${profile.pricePerSession ?? 2500}/session',
                    ),
                    _Pill(
                      icon: Icons.schedule,
                      text: nextText,
                      iconColor: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AppointmentBookingScreen(
                            therapistId: profile.therapistId,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Book Now'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNextSlot(DateTime dt) {
    final now = DateTime.now();
    final isToday =
        now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final tmr = now.add(const Duration(days: 1));
    final isTomorrow =
        tmr.year == dt.year && tmr.month == dt.month && tmr.day == dt.day;

    final hh = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$hh:$mm $ampm';

    if (isToday) return 'Today $time';
    if (isTomorrow) return 'Tomorrow $time';
    return '${dt.day}/${dt.month} $time';
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.iconColor});

  final IconData icon;
  final String text;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.pillCyan,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ImmediateHelpCard extends StatelessWidget {
  const _ImmediateHelpCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      gradientColors: [Colors.white, AppColors.primaryLight],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                'Need immediate help?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'If you are in danger or experiencing a crisis, contact local emergency services or a trusted person right away.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.redAccent,
                        Colors.redAccent.withValues(alpha: 0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _showNumberDialog(
                      context,
                      title: 'Crisis Hotline',
                      number: '988',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Crisis: 988',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showNumberDialog(
                    context,
                    title: 'Emergency',
                    number: '911',
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.6),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Emergency: 911',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _showNumberDialog(
    BuildContext context, {
    required String title,
    required String number,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text('Call $number from your phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class Therapist {
  Therapist({
    required this.id,
    required this.name,
    required this.specialty,
    required this.yearsExperience,
    required this.pricePerSession,
    required this.rating,
    required this.nextAvailableAt,
  });

  final String id;
  final String name;
  final String specialty;
  final int yearsExperience;
  final int pricePerSession;
  final double rating;
  final DateTime? nextAvailableAt;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'T';
    final first = parts.first.isNotEmpty ? parts.first[0] : 'T';
    final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  factory Therapist.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final ts = d['nextAvailableAt'];

    // Safe parsing for yearsExperience
    int yearsExperience = 0;
    final yearsExp = d['yearsExperience'];
    if (yearsExp != null) {
      if (yearsExp is int) {
        yearsExperience = yearsExp;
      } else if (yearsExp is num) {
        yearsExperience = yearsExp.toInt();
      } else {
        yearsExperience = int.tryParse(yearsExp.toString()) ?? 0;
      }
    }

    // Safe parsing for pricePerSession
    int pricePerSession = 0;
    final price = d['pricePerSession'];
    if (price != null) {
      if (price is int) {
        pricePerSession = price;
      } else if (price is num) {
        pricePerSession = price.toInt();
      } else {
        pricePerSession = int.tryParse(price.toString()) ?? 0;
      }
    }

    // Safe parsing for rating
    double rating = 0.0;
    final ratingValue = d['rating'];
    if (ratingValue != null) {
      if (ratingValue is double) {
        rating = ratingValue;
      } else if (ratingValue is num) {
        rating = ratingValue.toDouble();
      } else {
        rating = double.tryParse(ratingValue.toString()) ?? 0.0;
      }
    }

    return Therapist(
      id: doc.id,
      name: d['name']?.toString() ?? 'Therapist',
      specialty: d['specialty']?.toString() ?? 'Mental Health',
      yearsExperience: yearsExperience,
      pricePerSession: pricePerSession,
      rating: rating,
      nextAvailableAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}

class _CustomHeader extends StatelessWidget {
  const _CustomHeader({required this.title, this.showBack = false});

  final String title;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (showBack)
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
            )
          else
            const SizedBox(width: 40),

          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),

          const SizedBox(width: 40),
        ],
      ),
    );
  }
}
