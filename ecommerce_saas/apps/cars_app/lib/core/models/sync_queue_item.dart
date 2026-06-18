import 'package:hive_ce/hive.dart';

part 'sync_queue_item.g.dart';

@HiveType(typeId: 100)
enum SyncAction {
  @HiveField(0)
  create,
  @HiveField(1)
  update,
  @HiveField(2)
  delete,
}

@HiveType(typeId: 101)
class SyncQueueItem extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String collectionPath;
  @HiveField(2)
  final Map<String, dynamic> data;
  @HiveField(3)
  final SyncAction action;
  @HiveField(4)
  final DateTime createdAt;

  SyncQueueItem({
    required this.id,
    required this.collectionPath,
    required this.data,
    required this.action,
    required this.createdAt,
  });
}
