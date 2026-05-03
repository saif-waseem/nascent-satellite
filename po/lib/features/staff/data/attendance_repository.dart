import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../core/services/firestore_rest_service.dart';

class AttendanceRepository {
  final FirestoreRestService _restService;

  AttendanceRepository(this._restService);

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
    
    final results = await _restService.runQuery('attendance', query);
    final list = results.map((data) => AttendanceModel.fromJson(data)).where((record) {
      return record.checkIn.isAfter(startOfDay) && record.checkIn.isBefore(endOfDay);
    }).toList();
    
    list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
    return list;
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

    final results = await _restService.runQuery('attendance', query);
    final list = results.map((data) => AttendanceModel.fromJson(data)).toList();
    list.sort((a, b) => b.checkIn.compareTo(a.checkIn));
    return list;
  }

  Future<void> checkIn(AttendanceModel attendance) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await _restService.setDocument('attendance/$id', attendance.copyWith(id: id).toJson());
  }

  Future<void> checkOut(String tenantId, String attendanceId, DateTime checkOutTime) async {
    await _restService.setDocument('attendance/$attendanceId', {
      'checkOut': checkOutTime.toIso8601String(),
    }, isUpdate: true);
  }

  Future<AttendanceModel?> getActiveAttendance(String tenantId, String staffId) async {
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
        return AttendanceModel.fromJson(data);
      }
    }
    return null;
  }
}

final attendanceRepositoryProvider = Provider((ref) => AttendanceRepository(ref.watch(firestoreRestServiceProvider)));

final dailyAttendanceProvider = FutureProvider.family<List<AttendanceModel>, ({String tenantId, DateTime date})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).getDailyAttendance(args.tenantId, args.date);
});

final activeAttendanceProvider = FutureProvider.family<AttendanceModel?, ({String tenantId, String staffId})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).getActiveAttendance(args.tenantId, args.staffId);
});

final attendanceHistoryProvider = FutureProvider.family<List<AttendanceModel>, ({String tenantId, String? staffId})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).getAttendanceHistory(args.tenantId, args.staffId);
});
