import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../src/theme/app_theme.dart';
import '../home/widgets/glass_card.dart';

/// Book an appointment with a therapist.
/// Firestore write (appointments/{autoId}):
/// - userId (string)
/// - therapistId (string)
/// - scheduledAt (timestamp)
/// - status (string)  -> requested / confirmed / cancelled / completed
/// - notes (string)
/// - createdAt (timestamp)
class AppointmentBookingScreen extends StatefulWidget {
  const AppointmentBookingScreen({
    super.key,
    required this.therapistId,
  });

  final String therapistId;

  @override
  State<AppointmentBookingScreen> createState() => _AppointmentBookingScreenState();
}

class _AppointmentBookingScreenState extends State<AppointmentBookingScreen> {
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  bool _submitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate.isBefore(now) ? now : _selectedDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initial.year, initial.month, initial.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.purple,
                  secondary: AppColors.accentOrange,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = picked;
      _selectedTime = null;
    });
  }

  /// If therapist has availabilitySlots, we try to extract time options for the chosen date.
  ///
  /// Supported formats in therapists/{id}.availabilitySlots:
  /// - List<Timestamp>
  /// - List<String> (ISO-like or "HH:mm")
  /// - List<Map> where each item has {"date": Timestamp/String, "time": "HH:mm"}
  ///
  /// If nothing usable exists, we return a default set.
  List<TimeOfDay> _buildTimeOptionsFromTherapistDoc(Map<String, dynamic>? t) {
    const defaults = <TimeOfDay>[
      TimeOfDay(hour: 10, minute: 0),
      TimeOfDay(hour: 12, minute: 0),
      TimeOfDay(hour: 14, minute: 0),
      TimeOfDay(hour: 16, minute: 0),
      TimeOfDay(hour: 18, minute: 0),
    ];

    if (t == null) return defaults;
    final raw = t['availabilitySlots'];
    if (raw is! List) return defaults;

    final chosenYmd = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final times = <TimeOfDay>[];

    for (final item in raw) {
      DateTime? dt;

      if (item is Timestamp) {
        dt = item.toDate();
      } else if (item is String) {
        dt = DateTime.tryParse(item);
        if (dt == null) {
          final hm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(item.trim());
          if (hm != null) {
            final h = int.tryParse(hm.group(1)!);
            final m = int.tryParse(hm.group(2)!);
            if (h != null && m != null) {
              dt = DateTime(chosenYmd.year, chosenYmd.month, chosenYmd.day, h, m);
            }
          }
        }
      } else if (item is Map) {
        final d = item['date'];
        final timeStr = item['time'];

        DateTime? datePart;
        if (d is Timestamp) datePart = d.toDate();
        if (d is String) datePart = DateTime.tryParse(d);

        if (datePart != null && timeStr is String) {
          final hm = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(timeStr.trim());
          if (hm != null) {
            final h = int.tryParse(hm.group(1)!);
            final m = int.tryParse(hm.group(2)!);
            if (h != null && m != null) {
              dt = DateTime(datePart.year, datePart.month, datePart.day, h, m);
            }
          }
        }
      }

      if (dt == null) continue;

      final ymd = DateTime(dt.year, dt.month, dt.day);
      if (ymd != chosenYmd) continue;

      final tod = TimeOfDay(hour: dt.hour, minute: dt.minute);
      if (!times.any((x) => x.hour == tod.hour && x.minute == tod.minute)) {
        times.add(tod);
      }
    }

    times.sort((a, b) {
      final am = a.hour * 60 + a.minute;
      final bm = b.hour * 60 + b.minute;
      return am.compareTo(bm);
    });

    return times.isEmpty ? defaults : times;
  }

  DateTime _combine(DateTime d, TimeOfDay t) {
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _submit({required Map<String, dynamic>? therapist}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please login first.')),
      );
      return;
    }

    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot.')),
      );
      return;
    }

    final scheduledAt = _combine(_selectedDate, _selectedTime!);
    if (scheduledAt.isBefore(DateTime.now().add(const Duration(minutes: 5)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a future time.')),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await FirebaseFirestore.instance.collection('appointments').add({
        'userId': user.uid,
        'therapistId': widget.therapistId,
        'scheduledAt': Timestamp.fromDate(scheduledAt),
        'status': 'requested',
        'notes': _notesController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Appointment requested for ${_formatDateTime(scheduledAt)}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to book appointment: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String _formatDateTime(DateTime d) {
    final h = d.hour;
    final m = d.minute.toString().padLeft(2, '0');
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${_formatDate(d)}  $hh:$m $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final therapistRef = FirebaseFirestore.instance.collection('therapists').doc(widget.therapistId);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/moodgenie_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.white.withValues(alpha: 0.08)),
          ),
          SafeArea(
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: therapistRef.snapshots(),
              builder: (context, snapshot) {
                final t = snapshot.data?.data();
                final name = (t?['name'] ?? 'Therapist') as String;
                final specialization = (t?['specialization'] ?? 'Mental Health') as String;
                final rating = (t?['rating'] is num) ? (t!['rating'] as num).toDouble() : null;
                final expYears = (t?['experienceYears'] is num) ? (t!['experienceYears'] as num).toInt() : null;

                final timeOptions = _buildTimeOptionsFromTherapistDoc(t);

                return CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      floating: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: AppColors.purple),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      title: const Text('Book Appointment'),
                      centerTitle: true,
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          GlassCard(
                            gradientColors: const [Color(0xFFF4EEFF), Color(0xFFFFF7EE)],
                            child: Row(
                              children: [
                                Container(
                                  width: 52,
                                  height: 52,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 14,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.psychology_alt_rounded, color: AppColors.purple),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        specialization,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          if (rating != null) ...[
                                            const Icon(Icons.star_rounded, size: 16, color: AppColors.accentOrange),
                                            const SizedBox(width: 4),
                                            Text(
                                              rating.toStringAsFixed(1),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                          ],
                                          if (expYears != null)
                                            Text(
                                              '$expYears years',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),

                          _sectionTitle('Select date'),
                          const SizedBox(height: 8),
                          GlassCard(
                            gradientColors: const [Color(0xFFFFFFFF), Color(0xFFF4EEFF)],
                            child: Row(
                              children: [
                                const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.purple),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _formatDate(_selectedDate),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                TextButton(onPressed: _pickDate, child: const Text('Change')),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),
                          _sectionTitle('Select time'),
                          const SizedBox(height: 8),
                          GlassCard(
                            gradientColors: const [Color(0xFFFFFFFF), Color(0xFFFFF7EE)],
                            child: Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [for (final t0 in timeOptions) _timeChip(t0)],
                            ),
                          ),

                          const SizedBox(height: 14),
                          _sectionTitle('Notes (optional)'),
                          const SizedBox(height: 8),
                          GlassCard(
                            gradientColors: const [Color(0xFFFFFFFF), Color(0xFFF4EEFF)],
                            child: TextField(
                              controller: _notesController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Tell the therapist what you want to discuss…',
                                border: InputBorder.none,
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _submitting ? null : () => _submit(therapist: t),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentOrange,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                elevation: 0,
                              ),
                              child: _submitting
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text(
                                      'Request Appointment',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Center(
                            child: Text(
                              'Status will be “requested” until therapist confirms.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary.withValues(alpha: 0.9)),
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _timeChip(TimeOfDay t) {
    final selected = _selectedTime != null && _selectedTime!.hour == t.hour && _selectedTime!.minute == t.minute;
    final label = t.format(context);

    return InkWell(
      onTap: () => setState(() => _selectedTime = t),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.purple : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.purple : AppColors.purple.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

