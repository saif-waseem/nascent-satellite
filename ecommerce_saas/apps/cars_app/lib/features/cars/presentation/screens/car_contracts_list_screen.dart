import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_models/shared_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/providers/tenant_provider.dart';
import '../../data/car_contracts_repository.dart';
import 'car_contract_form_screen.dart';
import 'car_contract_print_preview.dart';

class CarContractsListScreen extends HookConsumerWidget {
  const CarContractsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final contractsAsync = ref.watch(carContractsStreamProvider(tenantId));
    final searchQuery = useState('');

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search Bar
          TextField(
            onChanged: (v) => searchQuery.value = v.toLowerCase(),
            style: GoogleFonts.cairo(),
            decoration: InputDecoration(
              hintText: 'بحث باسم البائع، المشتري، أو السيارة...',
              hintStyle: GoogleFonts.cairo(color: Colors.black38),
              prefixIcon: const Icon(Icons.search, color: AppColors.lapis),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),
          // List
          Expanded(
            child: contractsAsync.when(
              data: (contracts) {
                final filtered = searchQuery.value.isEmpty
                    ? contracts
                    : contracts.where((c) =>
                        c.sellerName.toLowerCase().contains(searchQuery.value) ||
                        c.buyerName.toLowerCase().contains(searchQuery.value) ||
                        c.carModelName.toLowerCase().contains(searchQuery.value)).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📂', style: TextStyle(fontSize: 56)),
                        const SizedBox(height: 12),
                        Text('لا توجد عقود', style: GoogleFonts.amiri(fontSize: 20, color: Colors.black45)),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = filtered[i];
                    return _ContractCard(
                      contract: c,
                      onEdit: () => Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                        appBar: AppBar(title: Text('تعديل العقد', style: GoogleFonts.amiri()), backgroundColor: AppColors.lapis, foregroundColor: Colors.white),
                        body: CarContractFormScreen(editContract: c),
                      ))),
                      onPrint: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CarContractPrintPreview(contract: c))),
                      onDelete: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('تأكيد الحذف', style: GoogleFonts.amiri()),
                            content: Text('هل تريد حذف هذا العقد؟', style: GoogleFonts.cairo()),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('إلغاء', style: GoogleFonts.cairo())),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: Text('حذف', style: GoogleFonts.cairo()),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(carContractsRepositoryProvider).deleteContract(tenantId, c.id);
                        }
                      },
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContractCard extends StatelessWidget {
  final CarContractModel contract;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _ContractCard({required this.contract, required this.onEdit, required this.onPrint, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final date = contract.createdAt;
    final dateStr = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: const Border(right: BorderSide(color: AppColors.gold, width: 3)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🚗', style: TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contract.carModelName, style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.lapisDark)),
                    const SizedBox(height: 2),
                    Text('${contract.sellerName}  ➡️  ${contract.buyerName}', style: GoogleFonts.cairo(fontSize: 12, color: Colors.black54)),
                    Text(dateStr, style: GoogleFonts.cairo(fontSize: 11, color: Colors.black38)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.start,
            children: [
              _ActionBtn(label: 'طباعة', color: AppColors.lapis, icon: Icons.print, onTap: onPrint),
              _ActionBtn(label: 'تعديل', color: AppColors.lapisDark, icon: Icons.edit, onTap: onEdit),
              _ActionBtn(label: 'حذف', color: Colors.red, icon: Icons.delete, onTap: onDelete),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionBtn({required this.label, required this.color, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: GoogleFonts.cairo(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
