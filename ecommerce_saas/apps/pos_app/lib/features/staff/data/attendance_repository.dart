import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_models/shared_models.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class AttendanceRepository {
  final FirebaseFirestore _firestore;

  AttendanceRepository(this._firestore);

  CollectionReference<AttendanceModel> _attendanceRef(String tenantId) =>
      _firestore
          .collection('attendance')
          .withConverter<AttendanceModel>(
            fromFirestore: (snapshot, _) => AttendanceModel.fromJson(snapshot.data()!),
            toFirestore: (model, options) => model.toJson(),
          );

  Stream<List<AttendanceModel>> watchDailyAttendance(String tenantId, DateTime date) {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final startIso = startOfDay.toIso8601String();
    final endIso = endOfDay.toIso8601String();

    return _attendanceRef(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data()).where((record) {
        return record.checkIn.toIso8601String().compareTo(startIso) >= 0 &&
               record.checkIn.toIso8601String().compareTo(endIso) < 0;
      }).toList();
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn)); // Newest first
      return list;
    });
  }

  Stream<List<AttendanceModel>> watchAttendanceHistory(String tenantId, String? staffId) {
    var query = _attendanceRef(tenantId).where('tenantId', isEqualTo: tenantId);
    
    if (staffId != null) {
      query = query.where('staffId', isEqualTo: staffId);
    }

    return query
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs.map((doc) => doc.data()).toList();
      list.sort((a, b) => b.checkIn.compareTo(a.checkIn)); // Newest first
      return list.take(100).toList(); // Limit to 100 in memory
    });
  }

  Future<void> checkIn(AttendanceModel attendance) async {
    final ref = _attendanceRef(attendance.tenantId).doc();
    await ref.set(attendance.copyWith(id: ref.id));
  }

  Future<void> checkOut(String tenantId, String attendanceId, DateTime checkOutTime) async {
    await _attendanceRef(tenantId).doc(attendanceId).update({
      'checkOut': checkOutTime.toIso8601String(),
    });
  }

  Future<AttendanceModel?> getActiveAttendance(String tenantId, String staffId) async {
    final snapshot = await _attendanceRef(tenantId)
        .where('tenantId', isEqualTo: tenantId)
        .where('staffId', isEqualTo: staffId)
        // Removing .where('checkOut', isNull: true) to avoid composite index requirement
        .get();

    if (snapshot.docs.isEmpty) return null;
    
    // Filter in-memory for documents with no check-out time
    for (final doc in snapshot.docs) {
      if (doc.data().checkOut == null) {
        return doc.data();
      }
    }
    return null;
  }
}

final attendanceRepositoryProvider = Provider((ref) => AttendanceRepository(FirebaseFirestore.instance));

final dailyAttendanceProvider = StreamProvider.family<List<AttendanceModel>, ({String tenantId, DateTime date})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).watchDailyAttendance(args.tenantId, args.date);
});

final activeAttendanceProvider = FutureProvider.family<AttendanceModel?, ({String tenantId, String staffId})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).getActiveAttendance(args.tenantId, args.staffId);
});

final attendanceHistoryProvider = StreamProvider.family<List<AttendanceModel>, ({String tenantId, String? staffId})>((ref, args) {
  return ref.watch(attendanceRepositoryProvider).watchAttendanceHistory(args.tenantId, args.staffId);
});
