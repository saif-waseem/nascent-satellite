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

class LoyaltyScreen extends ConsumerWidget {
  const LoyaltyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    final appSettingsController = ref.read(appSettingsProvider.notifier);
    final lang = appSettings.locale.languageCode;

    final user = ref.watch(userProvider);
    
    // Check if user is logged in (guest mode check)
    final isGuest = user.value == null;
    
    // If guest, show login prompt instead of profile
    if (isGuest) {
      return Scaffold(
        appBar: AppBar(title: Text(AppStrings.get('my_profile_title', lang))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person_outline, size: 100, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  AppStrings.get('guest_msg_title', lang),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.get('guest_msg_body', lang),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => context.go('/login'),
                  icon: const Icon(Icons.login),
                  label: Text(AppStrings.get('login', lang)),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // User is logged in, show profile
    // Removed unused variables: userName, userPhone, confirmedPoints, pendingPoints
    // The user object is accessed directly within the Consumer for the loyalty card.

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('my_profile_title', lang))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // User Header (Replaced Tenant info with cleaner User Header)
            Consumer(builder: (context, ref, _) {
              final tenant = ref.watch(tenantProvider).value;
              return TextButton.icon(
                onPressed: () async {
                  if (tenant != null && tenant.whatsappNumber.isNotEmpty) {
                    var phone = tenant.whatsappNumber.replaceAll(RegExp(r'\D'), '');
                    if (phone.startsWith('0')) {
                      phone = '964${phone.substring(1)}';
                    }
                    final url = Uri.parse('https://wa.me/$phone');
                    try {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('contact_support_whatsapp_error', lang))));
                      }
                    }
                  }
                },
                icon: const Icon(Icons.chat, color: Colors.green),
                label: Text(AppStrings.get('contact_support', lang), style: const TextStyle(color: Colors.green)),
              );
            }),
            const SizedBox(height: 24),

            // User Info and Loyalty Card (Combined and updated)
            ref.watch(userProvider).maybeWhen(
              data: (user) {
                if (user == null) return Center(child: Text(AppStrings.get('login_required_msg', lang)));
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(radius: 40, backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.person, size: 50, color: Colors.blue)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(user.name ?? 'User', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                          IconButton(
                            onPressed: () => context.push('/profile-edit'),
                            icon: const Icon(Icons.edit, size: 18),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      Text(user.id, style: TextStyle(color: Colors.grey[600])),
                      const Divider(height: 32),
                      _buildCheckInSection(context, ref, user, lang),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.blue.shade900, Colors.blue.shade600]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(AppStrings.get('my_points', lang), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                                Text(formatNumber(user.loyaltyPoints), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                                if (user.pendingPoints > 0)
                                  Row(
                                    children: [
                                      const Icon(Icons.timer, color: Colors.white70, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${formatNumber(user.pendingPoints)} ${AppStrings.get('points_pending', lang)}',
                                        style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const Icon(Icons.stars, color: Colors.amber, size: 48),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              orElse: () => Center(child: Text(AppStrings.get('login_required_title', lang))),
            ),
            const SizedBox(height: 24),
            _buildFeaturedSection(context, ref, lang),
            const SizedBox(height: 24),

            // Settings Section
            Align(alignment: (lang == 'ar' || lang == 'ku') ? Alignment.centerRight : Alignment.centerLeft, child: Text(AppStrings.get('settings', lang), style: Theme.of(context).textTheme.titleLarge)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.language),
                    title: Text(AppStrings.get('language', lang)),
                    subtitle: Text(appSettings.locale.languageCode == 'ar' ? 'العربية' : (appSettings.locale.languageCode == 'ku' ? 'Kurdish' : 'English')),
                    trailing: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: appSettings.locale.languageCode,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: const [
                          DropdownMenuItem(value: 'ar', child: Text('العربية')),
                          DropdownMenuItem(value: 'ku', child: Text('Kurdish')),
                          DropdownMenuItem(value: 'en', child: Text('English')),
                        ],
                        onChanged: (val) {
                          if (val != null) appSettingsController.setLocale(val);
                        },
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(appSettings.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode),
                    title: Text(AppStrings.get('theme', lang)),
                    trailing: Switch(
                      value: appSettings.themeMode == ThemeMode.dark,
                      onChanged: (val) => appSettingsController.toggleTheme(),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.monetization_on),
                    title: Text(AppStrings.get('currency', lang)),
                    trailing: Text(AppStrings.get('curr_iqd', lang), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sign Out
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(AppStrings.get('sign_out', lang), style: const TextStyle(color: Colors.red)),
              onTap: () { // ListTile uses onTap, not onPressed
                 ref.read(userActionsProvider).logout();
                 context.go('/login');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckInSection(BuildContext context, WidgetRef ref, UserModel user, String lang) {
    final lastCheckIn = user.lastCheckInDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    // Check if check-in was today
    final isCheckedInToday = lastCheckIn != null && 
        DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day).isAtSameMomentAs(today);

    // Calculate display streak: reset to 0 if last check-in was more than 1 day ago
    int displayStreak = user.checkInStreak;
    if (lastCheckIn != null && !isCheckedInToday) {
      final lastCheckZero = DateTime(lastCheckIn.year, lastCheckIn.month, lastCheckIn.day);
      if (today.difference(lastCheckZero).inDays > 1) {
        displayStreak = 0;
      }
    } else if (lastCheckIn == null) {
      displayStreak = 0;
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.get('daily_check_in', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  AppStrings.get('streak_label', lang).replaceFirst('{count}', displayStreak.toString()),
                  style: TextStyle(color: Colors.orange.shade800, fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (isCheckedInToday)
              const Icon(Icons.check_circle, color: Colors.green, size: 32)
            else
              FilledButton(
                onPressed: () async {
                  try {
                    // Points logic: Day 1 = 5, others random 1-10
                    final points = user.checkInStreak == 0 ? 5 : (1 + (DateTime.now().millisecond % 10));
                    await ref.read(firestoreServiceProvider).dailyCheckIn(user.id, points);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppStrings.get('check_in_success', lang).replaceFirst('{points}', points.toString())))
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                         SnackBar(content: Text(AppStrings.get('already_checked_in', lang)))
                      );
                    }
                  }
                },
                child: Text(AppStrings.get('check_in_btn', lang)),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // Simple streak visualizer with scroll to avoid overflow
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              final streakProgress = displayStreak % 7;
              final isActive = index < (streakProgress == 0 && displayStreak > 0 ? 7 : streakProgress);
              return Container(
                width: MediaQuery.of(context).size.width / 8,
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: [
                    Icon(
                      isActive ? Icons.stars : Icons.stars_outlined,
                      color: isActive ? Colors.orange : Colors.grey[300],
                      size: 24,
                    ),
                    Text('${index + 1}', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(BuildContext context, WidgetRef ref, String lang) {
    final productsAsync = ref.watch(productsProvider);
    
    return productsAsync.when(
      data: (products) {
        final starred = products.where((p) => p.isDailyStarred).toList()..shuffle();
        if (starred.isEmpty) return const SizedBox.shrink();
        
        final featured = starred.take(2).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.get('featured_for_you', lang), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: featured.length,
                itemBuilder: (context, index) {
                  final p = featured[index];
                  return GestureDetector(
                    onTap: () => context.push('/product-details', extra: p),
                    child: Container(
                      width: 140,
                      margin: const EdgeInsets.only(right: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                              child: p.imageUrl != null 
                                ? CachedNetworkImage(
                                    imageUrl: p.imageUrl!, 
                                    fit: BoxFit.cover, 
                                    width: double.infinity,
                                    placeholder: (_, __) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    errorWidget: (_, __, ___) => const Icon(Icons.broken_image),
                                  )
                                : const Icon(Icons.image, size: 40),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text(formatCurrency(p.price, lang: lang), style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
