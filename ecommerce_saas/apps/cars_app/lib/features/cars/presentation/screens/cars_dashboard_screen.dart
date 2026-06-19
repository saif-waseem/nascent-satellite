import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/settings_provider.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../../cars/data/car_contracts_repository.dart';
import 'car_contract_form_screen.dart';
import 'car_contracts_list_screen.dart';
import 'settings_screen.dart';

enum CarsPage { home, newContract, contractsList, settings }

class CurrentPageNotifier extends Notifier<CarsPage> {
  @override
  CarsPage build() => CarsPage.home;
  
  void setPage(CarsPage page) => state = page;
}

final currentPageProvider = NotifierProvider<CurrentPageNotifier, CarsPage>(CurrentPageNotifier.new);

class CarsDashboardScreen extends HookConsumerWidget {
  const CarsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(currentPageProvider);
    final settings = ref.watch(settingsProvider);
    final tenantId = ref.watch(tenantIdProvider);
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    final pageLabels = {
      CarsPage.home: 'الواجهة الرئيسية',
      CarsPage.newContract: 'تسجيل عقد جديد',
      CarsPage.contractsList: 'سجل العقود',
      CarsPage.settings: 'إعدادات المكتب',
    };

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: isDesktop ? null : AppBar(
          title: Text(pageLabels[currentPage]!, style: GoogleFonts.amiri(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.lapis,
          foregroundColor: Colors.white,
          actions: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFe8f5e9), borderRadius: BorderRadius.circular(20)),
              child: const Center(child: Text('● محمي', style: TextStyle(color: Color(0xFF2e7d32), fontSize: 12, fontWeight: FontWeight.w600))),
            ),
          ],
        ),
        drawer: isDesktop ? null : Drawer(
          child: _Sidebar(
            currentPage: currentPage,
            settings: settings,
            onNavigate: (page) {
              ref.read(currentPageProvider.notifier).setPage(page);
              Navigator.pop(context); // Close drawer
            },
          ),
        ),
        body: Row(
          children: [
            if (isDesktop)
              _Sidebar(
                currentPage: currentPage,
                settings: settings,
                onNavigate: (page) => ref.read(currentPageProvider.notifier).setPage(page),
              ),
            Expanded(
              child: Column(
                children: [
                  if (isDesktop)
                    Container(
                      height: 60,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(bottom: BorderSide(color: AppColors.gold, width: 2)),
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(pageLabels[currentPage]!, style: GoogleFonts.amiri(fontSize: 20, color: AppColors.lapis, fontWeight: FontWeight.bold)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFe8f5e9), borderRadius: BorderRadius.circular(20)),
                            child: const Text('● محمي', style: TextStyle(color: Color(0xFF2e7d32), fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Container(
                      color: AppColors.clay,
                      child: _buildPage(currentPage, tenantId, ref, settings),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(CarsPage page, String tenantId, WidgetRef ref, OfficeSettings settings) {
    switch (page) {
      case CarsPage.home:
        return _HomeView(tenantId: tenantId, settings: settings, onNewContract: () {
          ref.read(currentPageProvider.notifier).setPage(CarsPage.newContract);
        });
      case CarsPage.newContract:
        return const CarContractFormScreen();
      case CarsPage.contractsList:
        return const CarContractsListScreen();
      case CarsPage.settings:
        return const SettingsScreen();
    }
  }
}

// ── SIDEBAR WIDGET ────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final CarsPage currentPage;
  final OfficeSettings settings;
  final void Function(CarsPage) onNavigate;

  const _Sidebar({required this.currentPage, required this.settings, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.lapis, AppColors.lapisDark],
        ),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(2, 0))],
      ),
      child: Column(
        children: [
          // Logo Area
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x4Dd4af37), width: 1)),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  settings.logoImagePath != null
                      ? ClipOval(
                          child: Image.asset(settings.logoImagePath!, width: 64, height: 64, fit: BoxFit.cover, errorBuilder: (_,__,___) => const Text('🚗', style: TextStyle(fontSize: 48))),
                        )
                      : const Text('🚗', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 10),
                  Text(
                    settings.officeName,
                    style: GoogleFonts.amiri(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  const Text('نظام العقود', style: TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
          ),
          // Nav Items
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              child: Column(
                children: [
                  _NavItem(icon: '🏠', label: 'الواجهة الرئيسية', page: CarsPage.home, current: currentPage, onTap: onNavigate),
                  _NavItem(icon: '📝', label: 'تسجيل عقد جديد', page: CarsPage.newContract, current: currentPage, onTap: onNavigate),
                  _NavItem(icon: '📂', label: 'سجل العقود', page: CarsPage.contractsList, current: currentPage, onTap: onNavigate),
                  _NavItem(icon: '⚙️', label: 'إعدادات المكتب', page: CarsPage.settings, current: currentPage, onTap: onNavigate),
                ],
              ),
            ),
          ),
          // Footer
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Car Sales v1.3.0', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String icon;
  final String label;
  final CarsPage page;
  final CarsPage current;
  final void Function(CarsPage) onTap;

  const _NavItem({required this.icon, required this.label, required this.page, required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = page == current;
    return GestureDetector(
      onTap: () => onTap(page),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0x26d4af37) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border(right: BorderSide(color: isActive ? AppColors.gold : Colors.transparent, width: 3)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  color: isActive ? AppColors.gold : Colors.white70,
                  fontSize: 15,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── HOME VIEW ────────────────────────────────────────────────────────────────
class _HomeView extends ConsumerWidget {
  final String tenantId;
  final OfficeSettings settings;
  final VoidCallback onNewContract;

  const _HomeView({required this.tenantId, required this.settings, required this.onNewContract});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contractsAsync = ref.watch(carContractsStreamProvider(tenantId));
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: contractsAsync.when(
        data: (contracts) {
          final todayCount = contracts.where((c) => c.createdAt.isAfter(todayStart)).length;
          final monthCount = contracts.where((c) => c.createdAt.isAfter(monthStart)).length;
          final yearCount = contracts.where((c) => c.createdAt.isAfter(yearStart)).length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
                  border: Border.all(color: AppColors.clayDark),
                ),
                child: Column(
                  children: [
                    if (settings.logoImagePath != null) ...[
                      Image.asset(settings.logoImagePath!, height: 90, errorBuilder: (_,__,___) => const SizedBox()),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'مرحباً بك في ${settings.officeName}',
                      style: GoogleFonts.amiri(fontSize: 26, color: AppColors.lapis, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    if (settings.showStats) ...[
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.center,
                        children: [
                          _StatBox(count: todayCount, label: 'عقود اليوم', color: const Color(0xFF1565c0), bg: const Color(0xFFe3f2fd)),
                          _StatBox(count: monthCount, label: 'هذا الشهر', color: const Color(0xFFef6c00), bg: const Color(0xFFfff3e0)),
                          _StatBox(count: yearCount, label: 'هذا العام', color: const Color(0xFF2e7d32), bg: const Color(0xFFe8f5e9)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: onNewContract,
                      icon: const Icon(Icons.add_circle_outline),
                      label: Text('إنشاء عقد جديد', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.lapis,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final Color bg;

  const _StatBox({required this.count, required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Column(
        children: [
          Text('$count', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
        ],
      ),
    );
  }
}
