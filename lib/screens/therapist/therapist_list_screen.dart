import 'dart:ui';
import 'package:moodgenie/src/theme/app_background.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../src/theme/app_theme.dart';
import '../home/widgets/glass_card.dart';
import 'appointment_booking_screen.dart';

// ... imports remain the same

class TherapistListScreen extends StatefulWidget {
  const TherapistListScreen({super.key});

  @override
  State<TherapistListScreen> createState() => _TherapistListScreenState();
}

class _TherapistListScreenState extends State<TherapistListScreen> {
  final _therapistsRef = FirebaseFirestore.instance.collection('therapists');

  @override
  void initState() {
    super.initState();
    // Automatically seed data on screen load to ensure updated content
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedSampleTherapists();
    });
  }

  Future<void> _seedSampleTherapists() async {
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    // Delete old American profiles
    batch.delete(_therapistsRef.doc('dr_sarah_chen'));
    batch.delete(_therapistsRef.doc('dr_michael_rodriguez'));
    batch.delete(_therapistsRef.doc('dr_emily_johnson'));
    batch.delete(_therapistsRef.doc('dr_james_wilson'));
    batch.delete(_therapistsRef.doc('dr_lisa_patel'));




    // Dr. Ayesha Khan
    batch.set(
      _therapistsRef.doc('dr_ayesha_khan'),
      {
        'name': 'Dr. Ayesha Khan',
        'specialty': 'Child & Adolescent',
        'yearsExperience': 9,
        'pricePerSession': 2500,
        'rating': 4.9,
        'nextAvailableAt': Timestamp.fromDate(now.add(const Duration(hours: 4))),
        'availabilitySlots': [
          Timestamp.fromDate(now.add(const Duration(days: 1, hours: 11))),
          Timestamp.fromDate(now.add(const Duration(days: 1, hours: 16))),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Dr. Fatima Ali (was Dr. Sarah Chen)
    batch.set(
      _therapistsRef.doc('dr_fatima_ali'),
      {
        'name': 'Dr. Fatima Ali',
        'specialty': 'Anxiety & Stress',
        'yearsExperience': 8,
        'pricePerSession': 2000,
        'rating': 4.9,
        'nextAvailableAt': Timestamp.fromDate(now.add(const Duration(hours: 3))),
        'availabilitySlots': [
          Timestamp.fromDate(now.add(const Duration(days: 1, hours: 10))),
          Timestamp.fromDate(now.add(const Duration(days: 1, hours: 14))),
          Timestamp.fromDate(now.add(const Duration(days: 2, hours: 11))),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Dr. Ahmed Hassan (was Dr. Michael Rodriguez)
    batch.set(
      _therapistsRef.doc('dr_ahmed_hassan'),
      {
        'name': 'Dr. Ahmed Hassan',
        'specialty': 'Depression & Mood',
        'yearsExperience': 12,
        'pricePerSession': 2800,
        'rating': 4.8,
        'nextAvailableAt': Timestamp.fromDate(now.add(const Duration(days: 1, hours: 2))),
        'availabilitySlots': [
          Timestamp.fromDate(now.add(const Duration(days: 1, hours: 9))),
          Timestamp.fromDate(now.add(const Duration(days: 1, hours: 15))),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Dr. Sana Yousuf (was Dr. Emily Johnson)
    batch.set(
      _therapistsRef.doc('dr_sana_yousuf'),
      {
        'name': 'Dr. Sana Yousuf',
        'specialty': 'Family Therapy',
        'yearsExperience': 15,
        'pricePerSession': 3000,
        'rating': 5.0,
        'nextAvailableAt': Timestamp.fromDate(now.add(const Duration(hours: 6))),
        'availabilitySlots': [
          Timestamp.fromDate(now.add(const Duration(days: 2, hours: 10))),
          Timestamp.fromDate(now.add(const Duration(days: 3, hours: 14))),
        ],
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Dr. Bilal Ahmed (was Dr. James Wilson)
    batch.set(
      _therapistsRef.doc('dr_bilal_ahmed'),
      {
        'name': 'Dr. Bilal Ahmed',
        'specialty': 'Cognitive Behavioral',
        'yearsExperience': 6,
        'pricePerSession': 1500,
        'rating': 4.7,
        'nextAvailableAt': Timestamp.fromDate(now.add(const Duration(days: 2, hours: 4))),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    // Dr. Zainab Malik (was Dr. Lisa Patel)
    batch.set(
      _therapistsRef.doc('dr_zainab_malik'),
      {
        'name': 'Dr. Zainab Malik',
        'specialty': 'Trauma & PTSD',
        'yearsExperience': 10,
        'pricePerSession': 2200,
        'rating': 4.9,
        'nextAvailableAt': Timestamp.fromDate(now.add(const Duration(hours: 1))),
        'createdAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
    // Silent update to ensure smooth UX
  }

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
            const Positioned.fill(
              child: AppBackground(),
            ),
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
                        gradientColors: [Colors.white.withOpacity(0.9), Colors.white.withOpacity(0.7)],
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
          const Positioned.fill(
            child: AppBackground(),
          ),

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
                      _TherapistsSection(
                        therapistsRef: _therapistsRef,
                        onSeedData: _seedSampleTherapists,
                      ),
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
                  'Connect with licensed therapists for mental health support and guidance.',
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
  const _TherapistsSection({
    required this.therapistsRef,
    required this.onSeedData,
  });

  final CollectionReference<Map<String, dynamic>> therapistsRef;
  final VoidCallback onSeedData;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: therapistsRef.orderBy('rating', descending: true).snapshots(),
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

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return GlassCard(
            gradientColors: [Colors.white, Colors.white],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'No therapists yet',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Add therapist documents in Firestore, or tap below to insert sample data.',
                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onSeedData,
                    icon: const Icon(Icons.add),
                    label: const Text('Add sample therapists'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            for (final doc in docs) ...[
              Builder(
                builder: (context) {
                  try {
                    final therapist = Therapist.fromDoc(doc);
                    return _TherapistCard(therapist: therapist);
                  } catch (e) {
                    // If there's an error parsing a specific therapist, show an error card
                    return GlassCard(
                      gradientColors: [Colors.white, Colors.white],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red, size: 20),
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
                            'Document ID: ${doc.id}',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                          Text(
                            'Error: $e',
                            style: const TextStyle(fontSize: 11, color: Colors.red),
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
  const _TherapistCard({required this.therapist});

  final Therapist therapist;

  @override
  Widget build(BuildContext context) {
    final nextSlot = therapist.nextAvailableAt;
    final nextText = nextSlot == null ? 'No slots listed' : _formatNextSlot(nextSlot);

    return GlassCard(
      gradientColors: [Colors.white, Colors.white.withOpacity(0.8)],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.pillCyan,
            child: Text(
              therapist.initials,
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
                        therapist.name,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.star_rounded, size: 18, color: AppColors.accentCyan),
                    const SizedBox(width: 2),
                    Text(
                      therapist.rating.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  therapist.specialty,
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
                    _Pill(icon: Icons.work_outline, text: '${therapist.yearsExperience} years'),
                    _Pill(icon: Icons.payments_outlined, text: 'PKR ${therapist.pricePerSession}/session'),
                    _Pill(icon: Icons.schedule, text: nextText, iconColor: Colors.green),
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
                          builder: (_) => AppointmentBookingScreen(therapistId: therapist.id),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accentCyan,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    final isToday = now.year == dt.year && now.month == dt.month && now.day == dt.day;
    final tmr = now.add(const Duration(days: 1));
    final isTomorrow = tmr.year == dt.year && tmr.month == dt.month && tmr.day == dt.day;

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
        border: Border.all(color: AppColors.primary.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: iconColor ?? AppColors.primary),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
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
              Text('Need immediate help?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'If you are in danger or experiencing a crisis, contact local emergency services or a trusted person right away.',
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.3),
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
                        Colors.redAccent.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () => _showNumberDialog(context, title: 'Crisis Hotline', number: '988'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                  onPressed: () => _showNumberDialog(context, title: 'Emergency', number: '911'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.3),
                    foregroundColor: AppColors.textPrimary,
                    side: BorderSide(
                      color: AppColors.primary.withOpacity(0.6),
                      width: 2,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          )
        ],
      ),
    );
  }

  static void _showNumberDialog(BuildContext context, {required String title, required String number}) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text('Call $number from your phone.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
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
  const _CustomHeader({
    required this.title,
    this.showBack = false,
    this.onAction,
  });

  final String title;
  final bool showBack;
  final VoidCallback? onAction;

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
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.primary),
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

          if (onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.refresh_rounded, size: 20, color: AppColors.accentCyan),
              ),
            )
          else
            const SizedBox(width: 40),
        ],
      ),
    );
  }
}

