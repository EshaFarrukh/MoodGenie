import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:ui';
import '../../../src/theme/app_theme.dart';
import '../../home/widgets/glass_card.dart';
import 'terms_privacy_page.dart';

class ProfileTabPage extends StatefulWidget {
  const ProfileTabPage({super.key});

  @override
  State<ProfileTabPage> createState() => _ProfileTabPageState();
}

class _ProfileTabPageState extends State<ProfileTabPage> {
  bool _darkMode = false;
  bool _reminders = true;
  bool _soundEffects = true;
  int _totalMoods = 0;
  int _streak = 0;
  int _daysActive = 0;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _loadStats();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _reminders = prefs.getBool('reminders') ?? true;
      _soundEffects = prefs.getBool('soundEffects') ?? true;
    });
  }

  Future<void> _savePref(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .get();

      if (!mounted) return;

      final docs = snap.docs;
      final total = docs.length;

      int streak = 0;
      if (docs.isNotEmpty) {
        final now = DateTime.now();
        DateTime checkDate = DateTime(now.year, now.month, now.day);

        final loggedDates = docs
            .map((d) => (d.data()['timestamp'] as Timestamp).toDate())
            .map((d) => DateTime(d.year, d.month, d.day))
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

        for (final date in loggedDates) {
          if (date == checkDate ||
              date == checkDate.subtract(const Duration(days: 1))) {
            streak++;
            checkDate = date.subtract(const Duration(days: 1));
          } else {
            break;
          }
        }
        _daysActive = loggedDates.length;
      }

      setState(() {
        _totalMoods = total;
        _streak = streak;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final emailName = (user?.email ?? 'guest').split('@').first;
    final displayName = user?.displayName ??
        (emailName.isNotEmpty
            ? emailName[0].toUpperCase() + emailName.substring(1)
            : 'MoodGenie User');

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(displayName, user?.email ?? 'guest@moodgenie.com'),
          const SizedBox(height: 20),
          _buildStatsRow(),
          const SizedBox(height: 24),

          _buildSectionLabel('Customize'),
          const SizedBox(height: 10),
          _buildCustomizeSection(),
          const SizedBox(height: 24),

          _buildSectionLabel('Account'),
          const SizedBox(height: 10),
          _buildAccountSection(),
          const SizedBox(height: 24),

          _buildSectionLabel('Support'),
          const SizedBox(height: 10),
          _buildSupportSection(),
          const SizedBox(height: 24),

          _buildSignOutButton(),
          const SizedBox(height: 20),

          Center(
            child: Column(
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [AppColors.primary, AppColors.accentCyan],
                  ).createShader(bounds),
                  child: const Text(
                    'MoodGenie',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.0.0',
                  style: TextStyle(fontSize: 12, color: AppColors.captionLight, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════ Profile Header ═══════════════════════════════════════

  Widget _buildProfileHeader(String name, String email) {
    return GlassCard(
      gradientColors: const [Color(0xFFE8DEFF), Color(0xFFF5F0FF)],
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: AppShadows.glow(AppColors.primaryDeep),
                ),
                child: const Icon(Icons.person_rounded, size: 40, color: Colors.white),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showComingSoon('Profile Photo'),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.accentSoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: AppShadows.soft(),
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w900,
                    color: AppColors.headingDark, letterSpacing: -0.3,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: const TextStyle(fontSize: 13, color: AppColors.captionLight, fontWeight: FontWeight.w500),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFFE0B2)]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 14, color: Color(0xFFFF9800)),
                      SizedBox(width: 4),
                      Text('Wellness Explorer',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
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

  // ═══════ Stats ════════════════════════════════════════════════

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _StatCard(icon: Icons.local_fire_department_rounded, iconColor: const Color(0xFFFF6B35), value: '$_streak', label: 'Day Streak')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(icon: Icons.mood_rounded, iconColor: AppColors.primaryDeep, value: '$_totalMoods', label: 'Moods Logged')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(icon: Icons.calendar_today_rounded, iconColor: const Color(0xFF0288D1), value: '$_daysActive', label: 'Days Active')),
      ],
    );
  }

  // ═══════ Customize ════════════════════════════════════════════

  Widget _buildCustomizeSection() {
    return _SettingsGroup(children: [
      _ToggleSettingItem(
        icon: Icons.dark_mode_rounded, iconBg: const [Color(0xFF37474F), Color(0xFF263238)],
        title: 'Dark Mode', subtitle: 'Switch to dark theme',
        value: _darkMode,
        onChanged: (v) {
          setState(() => _darkMode = v);
          _savePref('darkMode', v);
          _showSnack(v ? 'Dark mode enabled — visual theme coming soon!' : 'Dark mode disabled');
        },
      ),
      _settingsDivider(),
      _ToggleSettingItem(
        icon: Icons.notifications_active_rounded, iconBg: const [AppColors.accentCyan, Color(0xFFFF7043)],
        title: 'Daily Reminders', subtitle: 'Get reminded to log your mood',
        value: _reminders,
        onChanged: (v) {
          setState(() => _reminders = v);
          _savePref('reminders', v);
          _showSnack(v ? 'Daily reminders enabled' : 'Daily reminders disabled');
        },
      ),
      _settingsDivider(),
      _ToggleSettingItem(
        icon: Icons.volume_up_rounded, iconBg: const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
        title: 'Sound Effects', subtitle: 'Play sounds on interactions',
        value: _soundEffects,
        onChanged: (v) {
          setState(() => _soundEffects = v);
          _savePref('soundEffects', v);
          _showSnack(v ? 'Sound effects enabled' : 'Sound effects disabled');
        },
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.palette_rounded, iconBg: const [Color(0xFFCE93D8), Color(0xFFAB47BC)],
        title: 'App Theme', subtitle: 'Purple Crystal',
        trailing: Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDeep]),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: AppShadows.soft(),
          ),
        ),
        onTap: () => _showComingSoon('Theme Picker'),
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.language_rounded, iconBg: const [Color(0xFF81C784), Color(0xFF43A047)],
        title: 'Language', subtitle: 'English',
        onTap: () => _showComingSoon('Language'),
      ),
    ]);
  }

  // ═══════ Account ══════════════════════════════════════════════

  Widget _buildAccountSection() {
    return _SettingsGroup(children: [
      _TapSettingItem(
        icon: Icons.person_outline_rounded, iconBg: const [AppColors.primary, AppColors.primaryDeep],
        title: 'Edit Profile', subtitle: 'Update your personal info',
        onTap: _showEditProfile,
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.lock_outline_rounded, iconBg: const [Color(0xFFFFB74D), Color(0xFFF57C00)],
        title: 'Change Password', subtitle: 'Update your security credentials',
        onTap: _showChangePassword,
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.download_rounded, iconBg: const [Color(0xFF4DB6AC), Color(0xFF00897B)],
        title: 'Export My Data', subtitle: 'Download your mood history',
        onTap: _exportData,
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.delete_outline_rounded, iconBg: const [AppColors.errorSoft, Color(0xFFD32F2F)],
        title: 'Delete Account', subtitle: 'Permanently remove your data',
        isDestructive: true,
        onTap: _showDeleteAccount,
      ),
    ]);
  }

  // ═══════ Support ══════════════════════════════════════════════

  Widget _buildSupportSection() {
    return _SettingsGroup(children: [
      _TapSettingItem(
        icon: Icons.help_outline_rounded, iconBg: const [Color(0xFF7986CB), Color(0xFF3F51B5)],
        title: 'Help Center', subtitle: 'FAQs and troubleshooting',
        onTap: _showHelpCenter,
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.chat_bubble_outline_rounded, iconBg: const [Color(0xFF4FC3F7), Color(0xFF0288D1)],
        title: 'Send Feedback', subtitle: 'Share your thoughts with us',
        onTap: _showFeedback,
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.star_outline_rounded, iconBg: const [Color(0xFFFFD54F), Color(0xFFFFC107)],
        title: 'Rate MoodGenie', subtitle: 'Love the app? Leave a review!',
        onTap: () => _showComingSoon('App Store link coming soon'),
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.share_rounded, iconBg: const [AppColors.accentCyan, Color(0xFFFF7043)],
        title: 'Share with Friends', subtitle: 'Spread the wellness',
        onTap: () => _showComingSoon('Share feature requires share_plus package'),
      ),
      _settingsDivider(),
      _TapSettingItem(
        icon: Icons.description_outlined, iconBg: const [Color(0xFFA1887F), Color(0xFF795548)],
        title: 'Terms & Privacy', subtitle: 'Legal information',
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TermsPrivacyPage()),
        ),
      ),
    ]);
  }

  // ═══════ Sign Out ═════════════════════════════════════════════

  Widget _buildSignOutButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFF6B6B), Color(0xFFEE5A6F)]),
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: AppShadows.glow(AppColors.errorSoft),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _confirmSignOut,
          borderRadius: BorderRadius.circular(AppRadius.m),
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Sign Out', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FUNCTIONAL IMPLEMENTATIONS
  // ═══════════════════════════════════════════════════════════════

  // ─── Edit Profile ──────────────────────────────────────────────

  void _showEditProfile() {
    final user = FirebaseAuth.instance.currentUser;
    final controller = TextEditingController(text: user?.displayName ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Edit Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.headingDark)),
              const SizedBox(height: 6),
              const Text('Update your display name', style: TextStyle(fontSize: 14, color: AppColors.captionLight)),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  hintText: 'Enter your name',
                  prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primaryDeep, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Email: ${user?.email ?? ''}',
                style: const TextStyle(fontSize: 13, color: AppColors.captionLight),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final newName = controller.text.trim();
                    if (newName.isEmpty) return;
                    try {
                      await user?.updateDisplayName(newName);
                      await user?.reload();
                      if (mounted) {
                        Navigator.pop(ctx);
                        setState(() {});
                        _showSnack('Profile updated!');
                      }
                    } catch (e) {
                      if (mounted) _showSnack('Error: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDeep,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Change Password ──────────────────────────────────────────

  void _showChangePassword() {
    final currentPwCtrl = TextEditingController();
    final newPwCtrl = TextEditingController();
    final confirmPwCtrl = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 20),
                const Text('Change Password', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.headingDark)),
                const SizedBox(height: 6),
                const Text('Enter your current and new password', style: TextStyle(fontSize: 14, color: AppColors.captionLight)),
                const SizedBox(height: 20),
                TextField(
                  controller: currentPwCtrl,
                  obscureText: obscureCurrent,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(obscureCurrent ? Icons.visibility_off : Icons.visibility, color: AppColors.captionLight),
                      onPressed: () => setSheetState(() => obscureCurrent = !obscureCurrent),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryDeep, width: 2)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: newPwCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.primary),
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, color: AppColors.captionLight),
                      onPressed: () => setSheetState(() => obscureNew = !obscureNew),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryDeep, width: 2)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: confirmPwCtrl,
                  obscureText: obscureNew,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: const Icon(Icons.lock_rounded, color: AppColors.primary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primaryDeep, width: 2)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (newPwCtrl.text != confirmPwCtrl.text) {
                        _showSnack('Passwords do not match');
                        return;
                      }
                      if (newPwCtrl.text.length < 6) {
                        _showSnack('Password must be at least 6 characters');
                        return;
                      }
                      try {
                        final user = FirebaseAuth.instance.currentUser!;
                        final cred = EmailAuthProvider.credential(email: user.email!, password: currentPwCtrl.text);
                        await user.reauthenticateWithCredential(cred);
                        await user.updatePassword(newPwCtrl.text);
                        if (mounted) {
                          Navigator.pop(ctx);
                          _showSnack('Password changed successfully!');
                        }
                      } on FirebaseAuthException catch (e) {
                        if (mounted) _showSnack(e.message ?? 'Error changing password');
                      } catch (e) {
                        if (mounted) _showSnack('Error: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDeep, foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Export Data ───────────────────────────────────────────────

  Future<void> _exportData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    _showSnack('Preparing your data...');

    try {
      final snap = await FirebaseFirestore.instance
          .collection('moods')
          .where('userId', isEqualTo: uid)
          .orderBy('timestamp', descending: true)
          .get();

      if (snap.docs.isEmpty) {
        _showSnack('No mood data to export');
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('Date,Time,Mood,Intensity,Note');

      for (final doc in snap.docs) {
        final data = doc.data();
        final ts = (data['timestamp'] as Timestamp).toDate();
        final date = '${ts.year}-${ts.month.toString().padLeft(2, '0')}-${ts.day.toString().padLeft(2, '0')}';
        final time = '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
        final mood = data['mood'] ?? '';
        final intensity = data['intensity'] ?? '';
        final note = (data['note'] ?? '').toString().replaceAll(',', ';');
        buffer.writeln('$date,$time,$mood,$intensity,$note');
      }

      await Clipboard.setData(ClipboardData(text: buffer.toString()));

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text('Data Exported!', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.headingDark)),
            ],
          ),
          content: Text(
            '${snap.docs.length} mood entries have been copied to your clipboard as CSV data.\n\nYou can paste this into a spreadsheet, notes app, or email.',
            style: const TextStyle(fontSize: 14, color: AppColors.bodyMuted, height: 1.5),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryDeep, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Done', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnack('Error exporting data: $e');
    }
  }

  // ─── Delete Account ───────────────────────────────────────────

  void _showDeleteAccount() {
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Color(0xFFFF5252), size: 28),
            SizedBox(width: 10),
            Expanded(child: Text('Delete Account', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.headingDark))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently delete:\n• All your mood entries\n• Your chat history\n• Your account data\n\nThis action cannot be undone.',
              style: TextStyle(fontSize: 14, color: AppColors.bodyMuted, height: 1.6),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmCtrl,
              decoration: InputDecoration(
                labelText: 'Type DELETE to confirm',
                hintText: 'DELETE',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF5252), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.captionLight, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (confirmCtrl.text != 'DELETE') {
                _showSnack('Please type DELETE to confirm');
                return;
              }
              Navigator.pop(ctx);
              await _performAccountDeletion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _performAccountDeletion() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _showSnack('Deleting your data...');

    try {
      final uid = user.uid;
      final fs = FirebaseFirestore.instance;

      // Delete moods
      final moods = await fs.collection('moods').where('userId', isEqualTo: uid).get();
      for (final doc in moods.docs) {
        await doc.reference.delete();
      }

      // Delete chats
      final chats = await fs.collection('chats').where('userId', isEqualTo: uid).get();
      for (final doc in chats.docs) {
        await doc.reference.delete();
      }

      // Delete appointments
      final appts = await fs.collection('appointments').where('userId', isEqualTo: uid).get();
      for (final doc in appts.docs) {
        await doc.reference.delete();
      }

      // Delete user doc if any
      try {
        await fs.collection('users').doc(uid).delete();
      } catch (_) {}

      // Delete Firebase Auth account
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (mounted) _showSnack('Please sign out, sign back in, and try again (security requirement)');
      } else {
        if (mounted) _showSnack(e.message ?? 'Error deleting account');
      }
    } catch (e) {
      if (mounted) _showSnack('Error: $e');
    }
  }

  // ─── Help Center ──────────────────────────────────────────────

  void _showHelpCenter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('Help Center', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.headingDark)),
              const SizedBox(height: 6),
              const Text('Frequently asked questions', style: TextStyle(fontSize: 14, color: AppColors.captionLight)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: const [
                    _FaqItem(
                      question: 'How do I log my mood?',
                      answer: 'Tap the "Mood" tab at the bottom, then tap "Log Mood Now". Select your mood, adjust the intensity slider, add an optional note, and tap "Save Mood".',
                    ),
                    _FaqItem(
                      question: 'Where can I see my mood history?',
                      answer: 'Go to the Mood tab and tap "History" to see a calendar view of all your past moods with details for each day.',
                    ),
                    _FaqItem(
                      question: 'How does the AI chat work?',
                      answer: 'MoodGenie\'s AI chat provides emotional support and wellness guidance. Tap the Chat tab to start a conversation. Note: this is not a replacement for professional therapy.',
                    ),
                    _FaqItem(
                      question: 'How do I book a therapist appointment?',
                      answer: 'Navigate to the Therapist section from the Home tab. Browse available therapists, select one, and choose a date and time that works for you.',
                    ),
                    _FaqItem(
                      question: 'Is my data private?',
                      answer: 'Yes! Your mood data is stored securely in your personal account. Only you can access your mood entries, chat history, and personal information.',
                    ),
                    _FaqItem(
                      question: 'How do I export my data?',
                      answer: 'Go to Profile → Export My Data. Your mood entries will be copied to your clipboard as CSV data that you can paste into a spreadsheet.',
                    ),
                    _FaqItem(
                      question: 'Can I delete my account?',
                      answer: 'Yes. Go to Profile → Delete Account. This will permanently remove all your data including mood entries, chats, and appointments.',
                    ),
                    SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Feedback ─────────────────────────────────────────────────

  void _showFeedback() {
    final feedbackCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('Send Feedback', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.headingDark)),
              const SizedBox(height: 6),
              const Text('We\'d love to hear your thoughts!', style: TextStyle(fontSize: 14, color: AppColors.captionLight)),
              const SizedBox(height: 20),
              TextField(
                controller: feedbackCtrl,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: 'What\'s on your mind? Suggestions, bugs, ideas...',
                  hintStyle: const TextStyle(color: AppColors.captionLight),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.primaryDeep, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final text = feedbackCtrl.text.trim();
                    if (text.isEmpty) {
                      _showSnack('Please write something first');
                      return;
                    }
                    try {
                      final uid = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
                      await FirebaseFirestore.instance.collection('feedback').add({
                        'userId': uid,
                        'message': text,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      if (mounted) {
                        Navigator.pop(ctx);
                        _showSnack('Thank you for your feedback! 💜');
                      }
                    } catch (e) {
                      if (mounted) _showSnack('Error sending feedback: $e');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryDeep, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.send_rounded, size: 18),
                      SizedBox(width: 8),
                      Text('Send Feedback', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════ Helpers ══════════════════════════════════════════════

  Future<void> _confirmSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.m)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.headingDark)),
        content: const Text('Are you sure you want to sign out?', style: TextStyle(fontSize: 14, color: AppColors.bodyMuted)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.captionLight, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorSoft, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) await FirebaseAuth.instance.signOut();
  }

  void _showComingSoon(String feature) {
    _showSnack('$feature — Coming Soon!');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: AppColors.headingDark,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _settingsDivider() {
    return Divider(height: 1, thickness: 0.5, color: AppColors.primaryFaint.withOpacity(0.6), indent: 60, endIndent: 16);
  }

  Widget _buildSectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.captionLight, letterSpacing: 0.8)),
    );
  }
}

// ═════════════════════════════════════════════════════════════════
// Reusable widgets
// ═════════════════════════════════════════════════════════════════

class _FaqItem extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqItem({required this.question, required this.answer});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _expanded ? AppColors.primaryLight : const Color(0xFFF8F6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _expanded ? AppColors.primaryFaint : Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.question,
                        style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: _expanded ? AppColors.primaryDeep : AppColors.headingDark,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: _expanded ? AppColors.primaryDeep : AppColors.captionLight),
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.answer,
                    style: const TextStyle(fontSize: 14, color: AppColors.bodyMuted, height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCard({required this.icon, required this.iconColor, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.m),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [Colors.white.withOpacity(0.5), Colors.white.withOpacity(0.25)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.6)),
          ),
          child: Column(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.headingDark)),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.captionLight, fontWeight: FontWeight.w600), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(AppRadius.m),
        boxShadow: AppShadows.soft(),
      ),
      child: Column(children: children),
    );
  }
}

class _ToggleSettingItem extends StatelessWidget {
  final IconData icon;
  final List<Color> iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleSettingItem({required this.icon, required this.iconBg, required this.title, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          _IconBubble(icon: icon, colors: iconBg),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.headingDark)),
                const SizedBox(height: 1),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.captionLight, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(value: value, onChanged: onChanged, activeColor: AppColors.primaryDeep),
          ),
        ],
      ),
    );
  }
}

class _TapSettingItem extends StatelessWidget {
  final IconData icon;
  final List<Color> iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;

  const _TapSettingItem({required this.icon, required this.iconBg, required this.title, required this.subtitle, required this.onTap, this.isDestructive = false, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _IconBubble(icon: icon, colors: iconBg),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDestructive ? AppColors.errorSoft : AppColors.headingDark)),
                    const SizedBox(height: 1),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.captionLight, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded, color: AppColors.navUnselected, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  const _IconBubble({required this.icon, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }
}
