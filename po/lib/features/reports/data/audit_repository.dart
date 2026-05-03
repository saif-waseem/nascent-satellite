import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';

class AuditRepository {
  final FirestoreRestService _restService;

  AuditRepository(this._restService);

  Future<void> log({
    required String tenantId,
    required String staffId,
    required String staffName,
    required String action,
    required String description,
    Map<String, dynamic> metadata = const {},
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final log = AuditLogModel(
      id: id,
      tenantId: tenantId,
      staffId: staffId,
      staffName: staffName,
      action: action,
      description: description,
      timestamp: DateTime.now(),
      metadata: metadata,
    );
    await _restService.setDocument('audit_logs/$id', log.toJson());
  }

  Future<List<AuditLogModel>> getLogs(String tenantId, {int limit = 100}) async {
    final query = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      },
      'limit': limit
    };
    final results = await _restService.runQuery('audit_logs', query);
    final list = results.map((d) => AuditLogModel.fromJson(d)).toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}

final auditRepositoryProvider = Provider((ref) => AuditRepository(ref.watch(firestoreRestServiceProvider)));

final auditLogsFutureProvider = FutureProvider.family<List<AuditLogModel>, String>((ref, tenantId) {
  final repo = ref.watch(auditRepositoryProvider);
  return repo.getLogs(tenantId);
});
