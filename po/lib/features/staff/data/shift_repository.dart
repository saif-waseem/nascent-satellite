import 'dart:convert';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/tenant_provider.dart';
import '../../../core/services/firestore_rest_service.dart';

class ShiftRepository {
  final FirestoreRestService _restService;
  final SharedPreferences _prefs;

  ShiftRepository(this._restService, this._prefs);

  static const String _activeShiftKey = 'active_shift_session';

  Future<ShiftSessionModel?> getActiveShift(String tenantId, String staffId) async {
    try {
      final query = {
        'where': {
          'compositeFilter': {
            'op': 'AND',
            'filters': [
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'tenantId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': tenantId}
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'staffId'},
                  'op': 'EQUAL',
                  'value': {'stringValue': staffId}
                }
              },
              {
                'fieldFilter': {
                  'field': {'fieldPath': 'status'},
                  'op': 'EQUAL',
                  'value': {'stringValue': 'open'}
                }
              }
            ]
          }
        },
        'limit': 1
      };

      final results = await _restService.runQuery('shift_sessions', query);

      if (results.isNotEmpty) {
        final shift = ShiftSessionModel.fromJson(results.first);
        await _cacheShift(shift);
        return shift;
      }
    } catch (e) {
      return _getCachedShift(tenantId, staffId);
    }
    return null;
  }

  Future<void> _cacheShift(ShiftSessionModel shift) async {
    await _prefs.setString(_activeShiftKey, jsonEncode(shift.toJson()..['id'] = shift.id));
  }

  ShiftSessionModel? _getCachedShift(String tenantId, String staffId) {
    final data = _prefs.getString(_activeShiftKey);
    if (data == null) return null;
    try {
      final shift = ShiftSessionModel.fromJson(jsonDecode(data));
      if (shift.tenantId == tenantId && shift.staffId == staffId && shift.status == 'open') {
        return shift;
      }
    } catch (_) {}
    return null;
  }

  Future<void> startShift(ShiftSessionModel shift) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newShift = shift.copyWith(id: id);
    await _restService.setDocument('shift_sessions/$id', newShift.toJson());
    await _cacheShift(newShift);
  }

  Future<void> closeShift({
    required String tenantId,
    required String shiftId,
    required double actualCash,
    required double expectedCash,
    required Map<String, double> salesSummary,
  }) async {
    await _restService.setDocument('shift_sessions/$shiftId', {
      'status': 'closed',
      'endTime': DateTime.now().toIso8601String(),
      'closingBalanceActual': actualCash,
      'closingBalanceExpected': expectedCash,
      'salesSummary': salesSummary,
    }, isUpdate: true);
    await _prefs.remove(_activeShiftKey);
  }

  Future<List<ShiftSessionModel>> getShiftHistory(String tenantId, {int limit = 50}) async {
    if (tenantId.isEmpty) return [];
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
    final results = await _restService.runQuery('shift_sessions', query);
    final list = results.map((d) => ShiftSessionModel.fromJson(d)).toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }
}

final shiftRepositoryProvider = Provider((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return ShiftRepository(ref.watch(firestoreRestServiceProvider), prefs);
});

final shiftHistoryFutureProvider = FutureProvider.family<List<ShiftSessionModel>, String>((ref, tenantId) {
  final repo = ref.watch(shiftRepositoryProvider);
  return repo.getShiftHistory(tenantId);
});

final activeShiftFutureProvider = FutureProvider.autoDispose.family<ShiftSessionModel?, ({String tenantId, String staffId})>((ref, args) {
  final repo = ref.watch(shiftRepositoryProvider);
  return repo.getActiveShift(args.tenantId, args.staffId);
});
