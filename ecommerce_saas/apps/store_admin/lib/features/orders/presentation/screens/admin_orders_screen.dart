import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:store_admin/features/shared/providers.dart';
import 'package:store_admin/features/shared/widgets/admin_drawer.dart';
import 'package:shared_models/shared_models.dart';
import 'package:store_admin/core/utils/formatters.dart';
import 'package:store_admin/core/localization/resources/app_strings.dart';
import 'package:store_admin/core/localization/app_settings_controller.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';

class AdminOrdersScreen extends ConsumerWidget {
  const AdminOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _AdminOrdersScreenContent();
  }
}

class _AdminOrdersScreenContent extends ConsumerStatefulWidget {
  const _AdminOrdersScreenContent();

  @override
  ConsumerState<_AdminOrdersScreenContent> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<_AdminOrdersScreenContent> {
  pw.Font? _cachedFont;
  pw.ImageProvider? _cachedLogo;
  String? _cachedLogoUrl;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncOrders = ref.watch(adminOrdersProvider);
    final lang = ref.watch(appSettingsProvider).locale.languageCode;

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('orders', lang))),
      drawer: const AdminDrawer(),
      body: asyncOrders.when(
        data: (orders) {
          final filtered = orders.where((o) {
            final matchesSearch = o.id.toLowerCase().contains(_searchQuery) ||
                o.userName.toLowerCase().contains(_searchQuery) ||
                o.userPhone.toLowerCase().contains(_searchQuery);

            bool matchesStatus = true;
            if (_statusFilter == 'Pending') {
              matchesStatus = o.status == OrderStatus.active && (o.tracking == 'Pending' || o.tracking == 'Preparing');
            } else if (_statusFilter == 'Processing') {
              matchesStatus = o.status == OrderStatus.active && o.tracking == 'Processing';
            } else if (_statusFilter == 'Shipped') {
              matchesStatus = o.status == OrderStatus.active && o.tracking == 'Shipped';
            } else if (_statusFilter == 'Delivered') {
              matchesStatus = (o.status == OrderStatus.active || o.status == OrderStatus.completed) && o.tracking == 'Delivered';
            } else if (_statusFilter == 'Completed') {
              matchesStatus = o.status == OrderStatus.completed;
            } else if (_statusFilter == 'Cancelled') {
              matchesStatus = o.status == OrderStatus.cancelled;
            }

            return matchesSearch && matchesStatus;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: AppStrings.get('search_orders_hint', lang),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    'All',
                    'Pending',
                    'Processing',
                    'Shipped',
                    'Delivered',
                    'Completed',
                    'Cancelled',
                  ].map((status) {
                    final label = status == 'All'
                        ? AppStrings.get('all', lang)
                        : (status == 'Pending'
                            ? AppStrings.get('tracking_pending', lang)
                            : (status == 'Processing'
                                ? AppStrings.get('tracking_processing', lang)
                                : (status == 'Shipped'
                                    ? AppStrings.get('tracking_shipped', lang)
                                    : (status == 'Delivered'
                                        ? AppStrings.get('tracking_delivered', lang)
                                        : (status == 'Completed'
                                            ? AppStrings.get('status_completed', lang)
                                            : AppStrings.get('status_cancelled', lang))))));

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(label),
                        selected: _statusFilter == status,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _statusFilter = status;
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(adminOrdersProvider);
                    await ref.read(adminOrdersProvider.future);
                  },
                  child: _buildOrdersList(filtered, lang),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text('Error: $e', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(adminOrdersProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<OrderModel> orders, String lang) {
    if (orders.isEmpty) {
      return ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.3),
          const Icon(Icons.inbox, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Center(child: Text(AppStrings.get('no_orders_yet', lang), style: const TextStyle(color: Colors.grey, fontSize: 16))),
        ],
      );
    }

    return ListView.builder(
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return Card(
          key: ValueKey('${order.id}_${order.status.name}_${order.tracking}'),
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ExpansionTile(
            title: Text('${AppStrings.get('order_id_label', lang)}: #${order.id}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${AppStrings.get('customer', lang)}: ${order.userName}'),
                Text(DateFormat('yyyy-MM-dd HH:mm').format(order.date)),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(formatCurrency(order.total, lang: lang), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                _buildStatusChip(order, lang),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppStrings.get('items_count', lang).replaceFirst('{count}', order.items.length.toString()), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...order.items.map((item) {
                      final color = item['color'];
                      final size = item['size'];
                      final variantInfo = _buildVariantText(color, size, lang);
                      final price = (item['price'] as num?)?.toDouble() ?? 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text('• ${item['name']}$variantInfo x${item['quantity']}')),
                            const SizedBox(width: 8),
                            Text(formatCurrency(price * (item['quantity'] ?? 1), lang: lang)),
                          ],
                        ),
                      );
                    }),
                    const Divider(),
                    _buildDetailRow(AppStrings.get('phone_label', lang), order.userPhone),
                    _buildDetailRow(AppStrings.get('address_label', lang), order.address),
                    if (order.landmark != null && order.landmark!.isNotEmpty)
                      _buildDetailRow(AppStrings.get('landmark', lang), order.landmark!),
                    
                    const Divider(),
                    _buildPaymentBreakdown(order, lang),
                    
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _printInvoice(order, lang),
                          icon: const Icon(Icons.print, size: 18),
                          label: Text(AppStrings.get('print', lang)),
                        ),
                        if (order.status == OrderStatus.active || order.status == OrderStatus.completed)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              _buildStateButton(order, lang, 'Pending', 'tracking_pending', Icons.hourglass_empty, Colors.orange),
                              _buildStateButton(order, lang, 'Processing', 'tracking_processing', Icons.settings_suggest, Colors.blue),
                              _buildStateButton(order, lang, 'Shipped', 'tracking_shipped', Icons.local_shipping, Colors.teal),
                              _buildStateButton(order, lang, 'Delivered', 'tracking_delivered', Icons.check_circle, Colors.green),
                            ],
                          ),
                        if (order.status == OrderStatus.active)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => _confirmCancelOrder(order, lang),
                            icon: const Icon(Icons.cancel, size: 18),
                            label: Text(AppStrings.get('cancel_order', lang)),
                          ),
                        if (order.status == OrderStatus.cancelled || order.status == OrderStatus.completed)
                          TextButton.icon(
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            onPressed: () => _confirmDeleteOrder(order.id, lang),
                            icon: const Icon(Icons.delete, size: 18),
                            label: Text(AppStrings.get('delete', lang)),
                          ),
                        if (order.status == OrderStatus.active)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
                            onPressed: () => _showAddDiscountDialog(order, lang),
                            icon: const Icon(Icons.money_off, size: 18),
                            label: Text(AppStrings.get('discount_code_label', lang)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddDiscountDialog(OrderModel order, String lang) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('discount_code_label', lang)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Amount (e.g. 5.0)'),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text) ?? 0.0;
              if (amount > 0) {
                 await ref.read(adminFirestoreServiceProvider).updateOrderDiscount(order, amount);
                 if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: Text(AppStrings.get('confirm', lang)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentBreakdown(OrderModel order, String lang) {
    // subtotal calculation using non-nullable price and quantity from items
    final subtotal = order.items.fold<double>(0, (sum, i) {
      final price = (i['price'] as num).toDouble();
      final qty = (i['quantity'] as num).toInt();
      return sum + (price * qty);
    });
    final tenant = ref.read(tenantProvider).value;
    final pointsToCurrency = tenant?.pointsToCurrencyRatio ?? 0.1;
    final pointsDiscount = order.pointsRedeemed * pointsToCurrency;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.get('payment_details', lang) ?? 'Payment Details', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 8),
        _buildDetailRow(AppStrings.get('subtotal', lang) ?? 'Subtotal', formatCurrency(subtotal, lang: lang)),
        if (order.pointsRedeemed > 0)
          _buildDetailRow(
            '${AppStrings.get('points_redeemed', lang) ?? 'Points'}: ${order.pointsRedeemed}', 
            '-${formatCurrency(pointsDiscount, lang: lang)}',
            valueColor: Colors.red,
          ),
        if (order.couponCode != null)
           _buildDetailRow(
            '${AppStrings.get('coupon', lang) ?? 'Coupon'}: ${order.couponCode}', 
            '-${formatCurrency(order.discountAmount, lang: lang)}',
            valueColor: Colors.red,
          ),
        if (order.discountAmount > 0 && order.couponCode == null)
          _buildDetailRow(
            AppStrings.get('admin_discount', lang) ?? 'Admin Discount', 
            '-${formatCurrency(order.discountAmount, lang: lang)}',
            valueColor: Colors.red,
          ),
        _buildDetailRow(AppStrings.get('shipping_cost', lang), formatCurrency(order.shippingCost, lang: lang)),
        const Divider(),
        _buildDetailRow(
          AppStrings.get('total', lang), 
          formatCurrency(order.total, lang: lang),
          isBold: true,
          valueColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$label:', style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(
            value, 
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderModel order, String lang) {
    Color color = Colors.grey;
    String label = order.tracking;
    
    if (order.status == OrderStatus.cancelled) {
      color = Colors.red;
      label = AppStrings.get('status_cancelled', lang);
    } else if (order.status == OrderStatus.completed || order.tracking == 'Delivered') {
      color = Colors.green;
      label = AppStrings.get('tracking_delivered', lang);
    } else if (order.tracking == 'Shipped') {
      color = Colors.indigo;
      label = AppStrings.get('tracking_shipped', lang);
    } else if (order.tracking == 'Processing') {
      color = Colors.blue;
      label = AppStrings.get('tracking_processing', lang);
    } else {
      color = Colors.orange;
      label = AppStrings.get('tracking_pending', lang);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color)),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStateButton(OrderModel order, String lang, String targetTracking, String translationKey, IconData icon, Color color) {
    final isCurrent = order.tracking == targetTracking || (targetTracking == 'Pending' && order.tracking == 'Preparing');
    
    // If it's delivered, the master status becomes completed.
    final targetStatus = targetTracking == 'Delivered' ? OrderStatus.completed : OrderStatus.active;
    
    return isCurrent 
      ? FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: null, // disabled because it's current
          icon: Icon(icon, size: 18),
          label: Text(AppStrings.get(translationKey, lang)),
        )
      : OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color)),
          onPressed: () => targetTracking == 'Delivered'
              ? _confirmDeliverOrder(order, lang)
              : _updateStatus(order, targetStatus, targetTracking),
          icon: Icon(icon, size: 18),
          label: Text(AppStrings.get(translationKey, lang)),
        );
  }

  Future<void> _updateStatus(OrderModel order, OrderStatus newStatus, String tracking) async {
    // Immediate feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Updating status to $tracking...'), duration: const Duration(seconds: 1)),
    );

    try {
      await ref.read(adminFirestoreServiceProvider).updateOrderStatus(order, newStatus, tracking);
      
      // Refresh to ensure stream catches it if local state lags
      ref.invalidate(adminOrdersProvider);

      // Send OneSignal notification
      try {
        final tenant = ref.read(tenantProvider).value;
        await ref.read(notificationServiceProvider).sendOneSignalNotification(
          tenantId: order.tenantId,
          title: 'Order $tracking',
          body: 'Your order #${order.id} is now $tracking.',
          storeName: tenant?.name,
          logoUrl: tenant?.logoUrl,
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _confirmDeliverOrder(OrderModel order, String lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang == 'ar' ? 'تأكيد تسليم الطلبية' : 'Confirm Delivery'),
        content: Text(lang == 'ar'
            ? 'هل أنت متأكد أن الطلبية #${order.id} قد تم تسليمها؟'
            : 'Are you sure order #${order.id} has been delivered?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(lang == 'ar' ? 'لا' : 'No'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang == 'ar' ? 'نعم، تم التسليم' : 'Yes, Delivered'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _updateStatus(order, OrderStatus.completed, 'Delivered');
    }
  }

  Future<void> _confirmCancelOrder(OrderModel order, String lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('cancel_order', lang)),
        content: Text(AppStrings.get('cancel_order_confirm', lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(AppStrings.get('confirm', lang)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _updateStatus(order, OrderStatus.cancelled, 'Cancelled');
    }
  }

  Future<void> _confirmDeleteOrder(String orderId, String lang) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppStrings.get('delete_order', lang)),
        content: Text(AppStrings.get('confirm_delete_msg', lang)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.get('cancel', lang))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: Text(AppStrings.get('delete', lang)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await ref.read(adminFirestoreServiceProvider).deleteOrder(orderId);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order deleted successfully')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  String _translateVariant(dynamic val, String lang) {
    if (val == null) return '';
    final s = val.toString();
    if (s == 'Default') return AppStrings.get('default_variant', lang);
    return AppStrings.get(s.toLowerCase(), lang);
  }

  String _buildVariantText(dynamic color, dynamic size, String lang) {
    final List<String> parts = [];
    final hasColor = color != null && color.toString() != 'none' && color.toString() != 'Default' && color.toString().isNotEmpty;
    final hasSize = size != null && size.toString() != 'none' && size.toString() != 'Default' && size.toString().isNotEmpty;
    
    if (hasColor) {
      parts.add('${AppStrings.get('color_label', lang)}: ${_translateVariant(color, lang)}');
    }
    if (hasSize) {
      parts.add('${AppStrings.get('size_label', lang)}: ${_translateVariant(size, lang)}');
    }
    
    if (parts.isEmpty) return '';
    return ' (${parts.join(' - ')})';
  }

  Future<void> _printInvoice(OrderModel order, String lang) async {
     try {
      final format = await showDialog<PdfPageFormat>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppStrings.get('select_printer', lang)),
          content: Text(AppStrings.get('paper_format_desc', lang)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, PdfPageFormat.a4), child: Text(AppStrings.get('a4_format', lang))),
            TextButton(onPressed: () => Navigator.pop(ctx, PdfPageFormat.roll80), child: Text(AppStrings.get('thermal_format', lang))),
          ],
        ),
      );

      if (format == null) return;
      _cachedFont ??= await PdfGoogleFonts.cairoRegular();
      final font = _cachedFont!;
      final doc = pw.Document();
      final tenant = await ref.read(tenantProvider.future);
      final isThermal = format == PdfPageFormat.roll80;
      
      // Logo Logic
      if (tenant?.name.toLowerCase().contains('aniqa') ?? false) {
          try {
            final byteData = await rootBundle.load('assets/images/aniqa_logo.jpg');
            _cachedLogo = pw.MemoryImage(byteData.buffer.asUint8List());
          } catch (_) {}
      } else if (tenant?.logoUrl != null && tenant!.logoUrl!.startsWith('http')) {
          if (_cachedLogoUrl != tenant.logoUrl) {
            try {
              _cachedLogo = await networkImage(tenant.logoUrl!);
              _cachedLogoUrl = tenant.logoUrl;
            } catch (_) {}
          }
      }
      final logoImage = _cachedLogo;

      doc.addPage(
        pw.Page(
          pageFormat: format,
          theme: pw.ThemeData.withFont(base: font, bold: font),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context context) {
                  final subtotal = order.items.fold<double>(0, (sum, i) => sum + ((i['price'] as num).toDouble() * (i['quantity'] as num).toInt()));
                  final tenant = ref.read(tenantProvider).value;
                  final pointsToCurrency = tenant?.pointsToCurrencyRatio ?? 0.1;
                  final pointsDiscount = order.pointsRedeemed * pointsToCurrency;
                  
                  return pw.Padding(
                    padding: pw.EdgeInsets.all(isThermal ? 10 : 24),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Center(
                          child: pw.Column(children: [
                            if (logoImage != null) pw.Container(width: 50, height: 50, child: pw.Image(logoImage)),
                            pw.Text(tenant?.name ?? AppStrings.get('store_name', lang), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                            pw.Text('${AppStrings.get('invoice', lang).toUpperCase()} #${order.id}'),
                          ]),
                        ),
                        pw.SizedBox(height: 20),
                        pw.Text('${AppStrings.get('customer', lang)}: ${order.userName}'),
                        // Sanitize phone number (remove tenantId prefix if present)
                        pw.Text('${AppStrings.get('phone_label', lang)}: ${order.userPhone.split('_').last}'),
                        pw.Text('${AppStrings.get('address_label', lang)}: ${order.address}'),
                        if (order.landmark != null && order.landmark!.isNotEmpty)
                           pw.Text('${AppStrings.get('landmark', lang)}: ${order.landmark}'),
                        pw.Divider(),
                        pw.Table(
                          children: [
                            pw.TableRow(children: [
                              pw.Text(AppStrings.get('item_short', lang), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                              pw.Text(AppStrings.get('qty_short', lang), textAlign: pw.TextAlign.center),
                              pw.Text(AppStrings.get('total', lang), textAlign: pw.TextAlign.left),
                            ]),
                            ...order.items.map((i) => pw.TableRow(children: [
                              pw.Text('${i['name']}${_buildVariantText(i['color'], i['size'], lang)}'),
                              pw.Text('${i['quantity']}', textAlign: pw.TextAlign.center),
                              pw.Text(formatCurrency((i['price'] as num).toDouble() * (i['quantity'] as num), lang: lang), textAlign: pw.TextAlign.left),
                            ])),
                          ],
                        ),
                        pw.Divider(),
                        
                        // Breakdown
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                          pw.Text(AppStrings.get('subtotal', lang)),
                          pw.Text(formatCurrency(subtotal, lang: lang)),
                        ]),
                        
                        if (order.pointsRedeemed > 0)
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            pw.Text('${AppStrings.get('points_redeemed', lang)} (${order.pointsRedeemed})'),
                            pw.Text('-${formatCurrency(pointsDiscount, lang: lang)}'),
                          ]),
                          
                        if (order.couponCode != null)
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            pw.Text('${AppStrings.get('coupon', lang)} (${order.couponCode})'),
                            pw.Text('-${formatCurrency(order.discountAmount, lang: lang)}'),
                          ]),
                          
                        if (order.discountAmount > 0 && order.couponCode == null)
                           pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            pw.Text(AppStrings.get('admin_discount', lang)),
                            pw.Text('-${formatCurrency(order.discountAmount, lang: lang)}'),
                          ]),

                        if (order.shippingCost > 0)
                          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                            pw.Text(AppStrings.get('shipping_cost', lang)),
                            pw.Text(formatCurrency(order.shippingCost, lang: lang)),
                          ]),
                        
                        pw.SizedBox(height: 5),
                        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                          pw.Text(AppStrings.get('total', lang), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                          pw.Text(formatCurrency(order.total, lang: lang), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                        ]),
                      ],
                    ),
                  );
          },
        ),
      );

      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
