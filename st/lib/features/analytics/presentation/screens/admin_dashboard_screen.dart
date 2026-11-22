import '../../../settings/presentation/screens/warehouses_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/utils/formatters.dart';
import 'package:shared_models/shared_models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  String _timeFilter = 'Day'; // 'Day', 'Month', 'All', 'Custom'
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenantId = ref.read(currentTenantIdProvider);
      ref.read(notificationServiceProvider).initialize(tenantId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(appSettingsProvider).locale.languageCode;
    final asyncOrders = ref.watch(adminOrdersProvider);
    final asyncProducts = ref.watch(adminProductsProvider);
    final asyncCustomers = ref.watch(customerListProvider);

    // Real-time order notification listener
    ref.listen(adminOrdersProvider, (previous, next) {
      if (previous != null && previous.hasValue && next.hasValue) {
        if (next.value!.length > previous.value!.length) {
          final newOrder = next.value!.first;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${AppStrings.get('app_name', lang)}: 🎉 ${AppStrings.get('order_id_label', lang)}${newOrder.id}'),
              action: SnackBarAction(label: AppStrings.get('orders', lang), onPressed: () => context.push('/orders')),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    });

    return Scaffold(
      drawer: const AdminDrawer(),
      backgroundColor: Colors.grey[50], // Lighter background for premium feel
      appBar: AppBar(
        centerTitle: false,
        title: Text(AppStrings.get('analytics', lang), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(tooltip: 'تقرير حركة الصنف والتنويعة',icon:const Icon(Icons.inventory_2_outlined),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const WarehousesScreen(showRecords:true)))),
          _buildLiveIndicator(lang),
          const SizedBox(width: 8),
          _buildTimeFilterButton(lang),
          const SizedBox(width: 16),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Welcome & Quick Stats
                _buildWelcomeHeader(lang),
                const SizedBox(height: 24),
            
            asyncOrders.when(
              skipLoadingOnRefresh: true,
              data: (orders) {
                final sortedOrders = [...orders]..sort((a, b) => b.date.compareTo(a.date));
                final filteredOrders = _filterByTime(sortedOrders, _timeFilter);
                final totalOrders = filteredOrders.length;
                final revenueOrders = filteredOrders.where((o) => o.status != OrderStatus.cancelled).toList();
                final totalRevenue = revenueOrders.fold(0.0, (sum, o) => sum + o.total);
                
                double totalCost = 0.0;
                final allProducts = asyncProducts.value ?? [];
                final purchasePriceMap = { for (var p in allProducts) p.id : (p.purchasePrice ?? 0.0) };
                
                for (var o in revenueOrders) {
                    for (var item in o.items) {
                        final productId = (item['productId'] ?? item['id'])?.toString() ?? '';
                        final qty = (item['quantity'] as num? ?? 1).toInt();
                        final cost = purchasePriceMap[productId] ?? 0.0;
                        totalCost += cost * qty;
                    }
                }
                final netProfit = totalRevenue - totalCost;
                final avgOrderValue = revenueOrders.isNotEmpty ? totalRevenue / revenueOrders.length : 0.0;

                return Column(
                  children: [
                    // Glassmorphic Summary Grid
                    _buildPremiumSummaryGrid(totalRevenue, netProfit, totalOrders, avgOrderValue, lang),
                    const SizedBox(height: 32),
                    
                    // Charts Section
                    LayoutBuilder(
                      builder: (context, chartConstraints) {
                        final isDesktop = chartConstraints.maxWidth > 900;
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: _buildModernChartContainer(
                                  title: AppStrings.get('sales_trends', lang),
                                  child: _buildRevenueChart(revenueOrders, lang),
                                  lang: lang,
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 1,
                                child: _buildModernChartContainer(
                                  title: AppStrings.get('order_trends', lang),
                                  height: 300,
                                  child: _buildOrderTrendsChart(filteredOrders, lang),
                                  lang: lang,
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildModernChartContainer(
                                title: AppStrings.get('sales_trends', lang),
                                child: _buildRevenueChart(revenueOrders, lang),
                                lang: lang,
                              ),
                              const SizedBox(height: 24),
                              _buildModernChartContainer(
                                title: AppStrings.get('order_trends', lang),
                                height: 220,
                                child: _buildOrderTrendsChart(filteredOrders, lang),
                                lang: lang,
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
              error: (err, _) => _buildErrorState(err.toString()),
              loading: () => _buildShimmerDashboard(),
            ),
             const SizedBox(height: 24),
            _buildDataHealthCheck(context, ref, lang),
            const SizedBox(height: 24),
            // 1. Management Hub
            Text(AppStrings.get('app_name', lang), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _buildActionCardSmall(
                  AppStrings.get('orders', lang), 
                  Icons.local_shipping, 
                  Colors.blue,
                  () => context.push('/orders')
                ),
                _buildActionCardSmall(
                  AppStrings.get('categories_label', lang), 
                  Icons.category, 
                  Colors.orange,
                  () => context.push('/categories')
                ),
                _buildActionCardSmall(
                  AppStrings.get('subscribers', lang), 
                  Icons.people, 
                  Colors.teal,
                  () => context.push('/customers')
                ),
                _buildActionCardSmall(
                  AppStrings.get('products_label', lang), 
                  Icons.inventory_2, 
                  Colors.indigo,
                  () => context.push('/products')
                ),
                _buildActionCardSmall(
                  AppStrings.get('settings', lang), 
                  Icons.settings, 
                  Colors.grey,
                  () => context.push('/settings')
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // 2. Marketing & Rewards
            Text(AppStrings.get('marketing_section', lang), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildActionCard(
                  AppStrings.get('manage_coupons', lang), 
                  AppStrings.get('coupons_subtitle', lang), 
                  Icons.confirmation_num_outlined, 
                  Colors.deepOrange,
                  () => context.push('/coupons')
                ),
                const SizedBox(width: 12),
                _buildActionCard(
                  AppStrings.get('loyalty_logic', lang), 
                  AppStrings.get('points_desc', lang), 
                  Icons.stars_rounded, 
                  Colors.amber.shade800,
                  () => context.push('/loyalty-settings')
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // 2. Inventory Alerts (Low Stock)
            asyncProducts.maybeWhen(
              data: (products) {
                final lowStock = products.where((p) => p.stockQuantity <= (p.minStockLevel ?? 5) || !p.inStock).toList();
                if (lowStock.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(AppStrings.get('inventory_alerts', lang), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Colors.red[700])),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(12)),
                          child: Text('${lowStock.length}', style: TextStyle(color: Colors.red[900], fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/low-stock'),
                          child: Text(AppStrings.get('see_all', lang)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: lowStock.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (ctx, i) {
                          final p = lowStock[i];
                          return Container(
                            width: 160,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(
                                  p.inStock ? '${AppStrings.get('stock_quantity_label', lang)}: ${p.stockQuantity}' : AppStrings.get('out_of_stock', lang),
                                  style: TextStyle(color: p.inStock ? Colors.orange[800] : Colors.red, fontSize: 12),
                                ),
                                const Spacer(),
                                OutlinedButton(
                                  onPressed: () => context.push('/low-stock'),
                                  style: OutlinedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(double.infinity, 28),
                                    foregroundColor: Colors.red[700],
                                    side: BorderSide(color: Colors.red.withOpacity(0.3)),
                                  ),
                                  child: Text(AppStrings.get('update', lang), style: const TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            
            // 2. Best Sellers & Top Rated
            Text(AppStrings.get('product_insights', lang), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            asyncProducts.when(
              skipLoadingOnRefresh: true,
              data: (products) {
                final bestSellers = [...products]..sort((a, b) => b.salesCount.compareTo(a.salesCount));
                final topRated = [...products]..sort((a, b) => b.rating.compareTo(a.rating));
                
                return Column(
                  children: [
                    _buildRankingList(AppStrings.get('best_sellers', lang), bestSellers.take(3).toList(), (p) => AppStrings.get('sold_count', lang).replaceFirst('{count}', p.salesCount.toString())),
                    const SizedBox(height: 24),
                    _buildRankingList(AppStrings.get('top_rated', lang), topRated.take(3).toList(), (p) => '⭐ ${p.rating}'),
                  ],
                );
              },
              error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
              loading: () => const Center(child: CircularProgressIndicator()),
            ),
            
            const SizedBox(height: 32),
            
            // 3. Top Customers
            Text(AppStrings.get('top_customers', lang), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            asyncCustomers.maybeWhen(
              skipLoadingOnRefresh: true,
              data: (users) {
                final topBuyers = [...users]..sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
                final topEngaged = [...users]..sort((a, b) => b.purchaseCount.compareTo(a.purchaseCount));
 
                return Column(
                  children: [
                    _buildUserRankingList(AppStrings.get('highest_spenders', lang), topBuyers.take(3).toList(), (u) => AppStrings.get('spent_amount', lang).replaceFirst('{amount}', formatCurrency(u.totalSpent, lang: lang))),
                    const SizedBox(height: 16),
                    _buildUserRankingList(AppStrings.get('most_active', lang), topEngaged.take(3).toList(), (u) => '${u.purchaseCount} ${AppStrings.get('orders', lang)}'),
                  ],
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            
            const SizedBox(height: 48),
          ],
        ),
      );
        },
      ),
    );
  }

  Widget _buildLiveIndicator(String lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ).animate(onPlay: (c) => c.repeat()).scale(duration: 1.seconds, begin: const Offset(1, 1), end: const Offset(1.5, 1.5)).fadeOut(),
          const SizedBox(width: 6),
          Text(
            lang == 'ar' ? 'مباشر' : 'LIVE',
            style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeFilterButton(String lang) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
      ),
      child: PopupMenuButton<String>(
        itemBuilder: (ctx) => [
          PopupMenuItem(value: 'Day', child: Text(AppStrings.get('today', lang))),
          PopupMenuItem(value: 'Month', child: Text(AppStrings.get('this_month', lang))),
          PopupMenuItem(value: 'All', child: Text(AppStrings.get('all_time', lang))),
          PopupMenuItem(value: 'Custom', child: Text(AppStrings.get('custom_range', lang))),
        ],
        onSelected: (v) async {
          if (v == 'Custom') {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2023),
              lastDate: DateTime.now().add(const Duration(days: 1)),
              initialDateRange: _customRange,
            );
            if (picked != null) {
              setState(() {
                _customRange = picked;
                _timeFilter = 'Custom';
              });
            }
          } else {
            setState(() => _timeFilter = v);
          }
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Text(_timeFilter, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String lang) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         Text(
           '${AppStrings.get('welcome', lang)}, Admin 👋',
           style: TextStyle(color: Colors.grey[600], fontSize: 16),
         ),
         const SizedBox(height: 4),
         Text(
           lang == 'ar' ? 'إليك نظرة على أدار متجرك اليوم' : "Here's your store performance today",
           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
         ),
       ],
     );
  }

  Widget _buildPremiumSummaryGrid(double revenue, double profit, int orders, double avg, String lang) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: constraints.maxWidth < 300 ? 1 : isMobile ? 2 : 4,
          mainAxisExtent: 152,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: [
            _buildPremiumCard(AppStrings.get('revenue', lang), formatCurrency(revenue, lang: lang), Icons.payments_rounded, Colors.blue),
            _buildPremiumCard(lang == 'ar' ? 'مجمل الربح' : 'Gross Profit', formatCurrency(profit, lang: lang), Icons.trending_up_rounded, Colors.green),
            _buildPremiumCard(AppStrings.get('orders', lang), '$orders', Icons.shopping_cart_rounded, Colors.purple),
            _buildPremiumCard(AppStrings.get('avg_order', lang), formatCurrency(avg, lang: lang), Icons.query_stats_rounded, Colors.orange),
          ],
        );
      }
    );
  }

  Widget _buildPremiumCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 18),
              ),
              const Spacer(),
              const Icon(Icons.more_horiz, color: Colors.grey, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildModernChartContainer({required String title, required Widget child, required String lang, double height = 300}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
              const Icon(Icons.fullscreen_rounded, color: Colors.grey, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(height: height, child: child),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text('Error: $error', style: const TextStyle(color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildShimmerDashboard() {
    return Column(
      children: [
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 2,
          childAspectRatio: 1.5,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          children: List.generate(4, (index) => Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds)),
        ),
        const SizedBox(height: 32),
        Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24)),
        ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.5.seconds),
      ],
    );
  }

  List<OrderModel> _filterByTime(List<OrderModel> orders, String filter) {
    final now = DateTime.now();
    if (filter == 'Day') {
      return orders.where((o) => o.date.year == now.year && o.date.month == now.month && o.date.day == now.day).toList();
    } else if (filter == 'Month') {
      return orders.where((o) => o.date.year == now.year && o.date.month == now.month).toList();
    } else if (filter == 'Custom' && _customRange != null) {
      return orders.where((o) => !o.date.isBefore(_customRange!.start) &&
                                 o.date.isBefore(_customRange!.end.add(const Duration(days: 1)))).toList();
    }
    return orders;
  }

  Widget _buildRankingList(String title, List<ProductModel> items, String Function(ProductModel) subtitleBuilder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 16)),
        const SizedBox(height: 12),
        ...items.map((p) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            dense: true,
            leading: CircleAvatar(
              backgroundColor: Colors.blueGrey.withOpacity(0.1),
              child: (p.imageUrl != null && p.imageUrl!.startsWith('http')) 
                ? ClipOval(child: Image.network(p.imageUrl!, width: 40, height: 40, fit: BoxFit.cover))
                : Icon(IconData(int.tryParse(p.imageUrl ?? '58900') ?? 58900, fontFamily: 'MaterialIcons'), size: 16),
            ),
            title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitleBuilder(p)),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12),
          ),
        )),
      ],
    );
  }

  Widget _buildUserRankingList(String title, List<UserModel> items, String Function(UserModel) subtitleBuilder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 16)),
        const SizedBox(height: 12),
        ...items.map((u) => Container(
           margin: const EdgeInsets.only(bottom: 8),
           decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
           child: ListTile(
            dense: true,
            leading: CircleAvatar(backgroundColor: Colors.indigo[50], child: Text(u.name?[0] ?? 'U', style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold))),
            title: Text(u.name ?? 'Guest', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(subtitleBuilder(u)),
          ),
        )),
      ],
    );
  }

  Widget _buildActionCardSmall(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          border: Border.all(color: Colors.grey[100]!),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDataHealthCheck(BuildContext context, WidgetRef ref, String lang) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber.shade100.withOpacity(0.3), Colors.amber.shade50.withOpacity(0.1)]),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.amber.shade200.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.health_and_safety_rounded, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(child: Text(lang == 'ar' ? 'سلامة البيانات المتقدمة' : 'Advanced Data Integrity', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.get('data_integrity_msg', lang),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final tenantId = ref.read(currentTenantIdProvider);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.get('analyzing_data', lang))));
                
                await ref.read(analyticsServiceProvider).syncSalesMetrics(tenantId);
                await ref.read(analyticsServiceProvider).syncCustomerMetrics(tenantId);
                await ref.read(analyticsServiceProvider).syncRatingMetrics(tenantId);
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppStrings.get('success_msg', lang)),
                    backgroundColor: Colors.green,
                  ));
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: Colors.amber.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.sync_rounded, size: 18),
              label: Text(lang == 'ar' ? 'تزامن وتحقق الآن' : 'Sync & Verify Now'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
            border: Border.all(color: Colors.grey[100]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRevenueChart(List<OrderModel> orders, String lang) {
    if (orders.isEmpty) return Center(child: Text(AppStrings.get('no_orders', lang)));

    // Group revenue by date
    final Map<String, double> dailyRevenue = {};
    for (var o in orders) {
      final dateKey = DateFormat('yyyy-MM-dd').format(o.date.toLocal());
      dailyRevenue[dateKey] = (dailyRevenue[dateKey] ?? 0) + o.total;
    }

    final sortedKeys = dailyRevenue.keys.toList()..sort();
    final spots = sortedKeys.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), dailyRevenue[e.value]!);
    }).toList();

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[100]!, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= sortedKeys.length) return const SizedBox.shrink();
                if (sortedKeys.length > 7 && value.toInt() % 2 != 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(sortedKeys[value.toInt()].substring(5), style: TextStyle(fontSize: 10, color: Colors.grey[400], fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withBlue(200)]),
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 3,
                strokeColor: Theme.of(context).primaryColor,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Theme.of(context).primaryColor.withOpacity(0.2), Theme.of(context).primaryColor.withOpacity(0.0)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderTrendsChart(List<OrderModel> orders, String lang) {
    if (orders.isEmpty) return const SizedBox.shrink();

    final Map<String, int> dailyOrders = {};
    for (var o in orders) {
      final dateKey = DateFormat('yyyy-MM-dd').format(o.date.toLocal());
      dailyOrders[dateKey] = (dailyOrders[dateKey] ?? 0) + 1;
    }

    final sortedKeys = dailyOrders.keys.toList()..sort();
    final spots = sortedKeys.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), dailyOrders[e.value]!.toDouble());
    }).toList();

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        alignment: BarChartAlignment.spaceAround,
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() < 0 || value.toInt() >= sortedKeys.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(sortedKeys[value.toInt()].substring(5), style: const TextStyle(fontSize: 9, color: Colors.grey)),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: spots.map((s) => BarChartGroupData(
          x: s.x.toInt(),
          barRods: [
            BarChartRodData(
              toY: s.y,
              gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.blue.shade300, Colors.blue.shade700]),
              width: 12,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
            ),
          ],
        )).toList(),
      ),
    );
  }
}
