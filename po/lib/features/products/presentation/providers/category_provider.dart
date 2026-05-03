import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../data/category_repository.dart';
import '../../../../core/providers/tenant_provider.dart';

final categoriesProvider = StreamProvider.autoDispose((ref) {
  final repo = ref.watch(categoryRepositoryProvider);
  final tenantId = ref.watch(tenantIdProvider);
  return Stream.fromFuture(repo.getCategories(tenantId));
});

final categoriesListProvider = Provider.autoDispose((ref) {
  final categoriesAsync = ref.watch(categoriesProvider);
  return categoriesAsync.whenData((list) => list..sort((a, b) => a.name.compareTo(b.name)));
});
