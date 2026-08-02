import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';
import '../../../core/services/local_db_service.dart';
import '../../../core/models/sync_queue_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/tenant_provider.dart';
import 'dart:convert';

class AttendanceRepository {
  final FirestoreRestService _restService;
  final SharedPreferences _prefs;

  AttendanceRepository(this._restService, this._prefs);

  static const String _activeAttendanceKey = 'active_attendance_record';

  Future<List<AttendanceModel>> getDailyAttendance(String tenantId, DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final query = {
      'where': {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      }
    };
    
    try {
      final results = await _restService.runQuery('attendance', query);
      final list = results.map((data) => AttendanceModel.fromJson(data)).where((record) {
        return record.checkIn.isAfter(startOfDay) && record.checkIn.isBefore(endOfDay);
      }).toList();
      
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    } catch (_) {
      return []; // Return empty list if offline and no specific daily cache
    }
  }

  Future<List<AttendanceModel>> getAttendanceHistory(String tenantId, String? staffId) async {
    final filters = [
      {
        'fieldFilter': {
          'field': {'fieldPath': 'tenantId'},
          'op': 'EQUAL',
          'value': {'stringValue': tenantId}
        }
      }
    ];
    
    if (staffId != null) {
      filters.add({
        'fieldFilter': {
          'field': {'fieldPath': 'staffId'},
          'op': 'EQUAL',
          'value': {'stringValue': staffId}
        }
      });
    }

    final query = {
      'where': {
        'compositeFilter': {
          'op': 'AND',
          'filters': filters
        }
      },
      'limit': 100
    };

    try {
      final results = await _restService.runQuery('attendance', query);
      final list = results.map((data) => AttendanceModel.fromJson(data)).toList();
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<void> checkIn(AttendanceModel attendance) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newRecord = attendance.copyWith(id: id);
    final data = newRecord.toJson()..['id'] = id;

    try {
      await _restService.setDocument('attendance/$id', data);
    } catch (e) {
      await LocalDbService.addToSyncQueue(
        collectionPath: 'attendance/$id',
        data: data,
        action: SyncAction.create,
      );
    }
    await _cacheActiveAttendance(newRecord);
  }

  Future<void> checkOut(String tenantId, String attendanceId, DateTime checkOutTime) async {
    final data = {
      'checkOut': checkOutTime.toIso8601String(),
    };

    try {
      await _restService.setDocument('attendance/$attendanceId', data, isUpdate: true);
    } catch (e) {
      await LocalDbService.addToSyncQueue(
        collectionPath: 'attendance/$attendanceId',
        data: data..['id'] = attendanceId,
        action: SyncAction.update,
      );
    }
    await _prefs.remove(_activeAttendanceKey);
  }

  Future<AttendanceModel?> getActiveAttendance(String tenantId, String staffId) async {
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
              }
            ]
          }
        }
      };

      final results = await _restService.runQuery('attendance', query);
      for (var data in results) {
        if (data['checkOut'] == null) {
          final record = AttendanceModel.fromJson(data);
          await _cacheActiveAttendance(record);
          return record;
        }
      }
    } catch (e) {
      return _getCachedActiveAttendance(tenantId, staffId);
    }
    return null;
  }

  Future<void> _cacheActiveAttendance(AttendanceModel attendance) async {
    await _prefs.setString(_activeAttendanceKey, jsonEncode(attendance.toJson()..['id'] = attendance.id));
  }

  AttendanceModel? _getCachedActiveAttendance(String tenantId, String staffId) {
    final data = _prefs.getString(_activeAttendanceKey);
    if (data == null) return null;
    try {
      final record = AttendanceModel.fromJson(jsonDecode(data));
      if (record.tenantId == tenantId && record.staffId == staffId && record.checkOut == null) {
        return record;
      }
    } catch (_) {}
    return null;
  }
}

final attendanceRepositoryProvider = Provider((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AttendanceRepository(ref.watch(firestoreRestServiceProvider), prefs);
});

final dailyAttendanceProvider = FutureProvider.family<List<AttendanceModel>, ({String tenantId, DateTime date})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).getDailyAttendance(args.tenantId, args.date);
});

final activeAttendanceProvider = FutureProvider.family<AttendanceModel?, ({String tenantId, String staffId})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).getActiveAttendance(args.tenantId, args.staffId);
});

final attendanceHistoryProvider = FutureProvider.family<List<AttendanceModel>, ({String tenantId, String? staffId})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).getAttendanceHistory(args.tenantId, args.staffId);
});
