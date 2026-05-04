import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:user_app/core/localization/app_settings_controller.dart';
import 'package:user_app/core/localization/resources/app_strings.dart';
import 'package:user_app/features/shared/providers.dart';
import 'package:user_app/core/utils/formatters.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_models/shared_models.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    final appSettingsController = ref.read(appSettingsProvider.notifier);
    final lang = appSettings.locale.languageCode;
    final userAsync = ref.watch(userProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(AppStrings.get('my_profile_title', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) {
          if (user == null) return _buildGuestView(context, lang);
          return _buildProfileView(context, ref, user, lang, appSettings, appSettingsController);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context, String lang) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20)]),
              child: Icon(Icons.person_outline, size: 80, color: Colors.grey[300]),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 32),
            Text(
              AppStrings.get('guest_msg_title', lang),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 12),
            Text(
              AppStrings.get('guest_msg_body', lang),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: () => context.go('/login'),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text(AppStrings.get('login', lang), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ).animate().fadeIn(delay: 600.ms).scale(begin: const Offset(0.9, 0.9)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView(
    BuildContext context, 
    WidgetRef ref, 
    UserModel user, 
    String lang, 
    dynamic appSettings, 
    dynamic appSettingsController
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 70, 16, 100),
      child: Column(
        children: [
          // Premium Profile Header Card
          _buildPremiumIdCard(context, user, lang),
          const SizedBox(height: 24),
          
          // Referral Section [NEW]
          _buildReferralCard(context, user, lang),
          const SizedBox(height: 24),

          // Check-in Section
          _buildPremiumCheckInCard(context, ref, user, lang),
          const SizedBox(height: 24),

          // Settings Section
          _buildSettingsSection(context, ref, lang, appSettings, appSettingsController),
          const SizedBox(height: 32),

          // Sign Out
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
              child: const Icon(Icons.logout, color: Colors.red, size: 20),
            ),
            title: Text(AppStrings.get('sign_out', lang), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () {
               ref.read(userActionsProvider).logout();
               context.go('/login');
            },
          ).animate().fadeIn(delay: 800.ms),
        ],
      ),
    );
  }

  Widget _buildPremiumIdCard(BuildContext context, UserModel user, String lang) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withBlue(200)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Theme.of(context).primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(Icons.stars, size: 150, color: Colors.white.withOpacity(0.1)),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white.withOpacity(0.9),
                        child: Icon(Icons.person_rounded, size: 40, color: Theme.of(context).primaryColor),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name ?? 'Guest',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            user.id,
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => context.push('/profile-edit'),
                      icon: const Icon(Icons.edit_note, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(AppStrings.get('my_points', lang), style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.stars, color: Colors.amber, size: 28),
                            const SizedBox(width: 8),
                            Text(
                              formatNumber(user.loyaltyPoints),
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                        if (user.pendingPoints > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.timer_outlined, color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${formatNumber(user.pendingPoints)} ${AppStrings.get('points_pending', lang)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    _buildTierBadge(user.loyaltyPoints),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().slideY(begin: -0.1, end: 0, duration: 800.ms, curve: Curves.easeOutCubic).fadeIn();
  }

  Widget _buildTierBadge(int points) {
    String tier = points > 1000 ? 'GOLD' : (points > 500 ? 'SILVER' : 'BRONZE');
    Color color = points > 1000 ? Colors.amber[200]! : (points > 500 ? Colors.grey[200]! : Colors.orange[200]!);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.military_tech_rounded, color: color, size: 24),
          Text(tier, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildPremiumCheckInCard(BuildContext context, WidgetRef ref, UserModel user, String lang) {
    final lastCheckIn = user.lastCheckInDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isCheckedInToday = lastCheckIn != null && 
        DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day).isAtSameMomentAs(today);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(AppStrings.get('daily_check_in', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department, color: Colors.orange, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.get('streak_label', lang).replaceFirst('{count}', user.checkInStreak.toString()),
                        style: TextStyle(color: Colors.orange[800], fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              if (isCheckedInToday)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                      const SizedBox(width: 8),
                      Text(AppStrings.get('cat_all', lang).substring(0, 2), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)), // "Done" placeholder
                    ],
                  ),
                )
              else
                FilledButton(
                  onPressed: () => _performCheckIn(context, ref, user, lang),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(AppStrings.get('check_in_btn', lang)),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildStreakVisualizer(context, user.checkInStreak),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildStreakVisualizer(BuildContext context, int streak) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final currentProgress = streak % 7;
        final isCompleted = index < (currentProgress == 0 && streak > 0 ? 7 : currentProgress);
        final isNext = index == (currentProgress == 0 && streak > 0 ? -1 : currentProgress);

        return Column(
          children: [
            Container(
              width: 38,
              height: 48,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.orange[50] : (isNext ? Colors.grey[50] : Colors.transparent),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isCompleted ? Colors.orange[200]! : (isNext ? Colors.blue[100]! : Colors.grey[200]!)),
              ),
              child: Center(
                child: Icon(
                  isCompleted ? Icons.stars_rounded : (isNext ? Icons.stars_outlined : Icons.lock_outline),
                  color: isCompleted ? Colors.orange : (isNext ? Colors.blue[300] : Colors.grey[300]),
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('${index + 1}', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
          ],
        );
      }),
    );
  }

  Future<void> _performCheckIn(BuildContext context, WidgetRef ref, UserModel user, String lang) async {
    try {
      final points = user.checkInStreak == 0 ? 5 : (1 + (DateTime.now().millisecond % 10));
      await ref.read(firestoreServiceProvider).dailyCheckIn(user.id, points);
      
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              margin: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.network(
                    'https://assets9.lottiefiles.com/packages/lf20_tou97p4c.json', // Confetti or Reward
                    height: 150,
                    repeat: false,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '+$points ${AppStrings.get('points_award', lang)}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.orange),
                  ),
                  const SizedBox(height: 8),
                  Text(AppStrings.get('check_in_success', lang).replaceFirst('{points}', points.toString())),
                  const SizedBox(height: 24),
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Great!')),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('already_checked_in', lang))));
      }
    }
  }

  Widget _buildSettingsSection(BuildContext context, WidgetRef ref, String lang, dynamic appSettings, dynamic appSettingsController) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Text(AppStrings.get('settings', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              _buildSettingTile(
                icon: Icons.language_rounded,
                color: Colors.blue,
                title: AppStrings.get('language', lang),
                value: appSettings.locale.languageCode == 'ar' ? 'العربية' : (appSettings.locale.languageCode == 'ku' ? 'Kurdish' : 'English'),
                onTap: () {
                   // Cycle languages or show bottom sheet
                   final current = appSettings.locale.languageCode;
                   final next = current == 'ar' ? 'en' : (current == 'en' ? 'ku' : 'ar');
                   appSettingsController.setLocale(next);
                },
              ),
              const Divider(indent: 50, height: 1),
              _buildSettingTile(
                icon: appSettings.themeMode == ThemeMode.dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                color: Colors.purple,
                title: AppStrings.get('theme', lang),
                value: appSettings.themeMode == ThemeMode.dark ? 'Dark' : 'Light',
                trailing: Switch(
                  value: appSettings.themeMode == ThemeMode.dark,
                  onChanged: (val) => appSettingsController.toggleTheme(),
                ),
              ),
              const Divider(indent: 50, height: 1),
              _buildSettingTile(
                icon: Icons.monetization_on_rounded,
                color: Colors.green,
                title: AppStrings.get('currency', lang),
                value: AppStrings.get('curr_iqd', lang),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildSettingTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      trailing: trailing ?? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }

  Widget _buildReferralCard(BuildContext context, UserModel user, String lang) {
    // Generate a code if not present (simplified for UI)
    final referralCode = user.referralCode ?? '${user.name?.split(' ').first ?? 'USER'}${user.id.substring(user.id.length - 4)}'.toUpperCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.people_alt_rounded, color: Colors.blue[600], size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invite & Earn', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text('Get 50 points for every new friend', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOUR REFERRAL CODE', style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(referralCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                     // Share logic
                  },
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const Text('Share'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.1, end: 0);
  }
}

