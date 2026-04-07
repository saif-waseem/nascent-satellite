import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'order_model.g.dart';

@HiveType(typeId: 6)
enum OrderStatus { 
  @HiveField(0)
  active, 
  @HiveField(1)
  completed, 
  @HiveField(2)
  cancelled 
}

@HiveType(typeId: 5)
class OrderModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String userId;
  @HiveField(2)
  final String tenantId;
  @HiveField(3)
  final double total;
  @HiveField(4)
  final List<Map<String, dynamic>> items;
  @HiveField(5)
  final OrderStatus status;
  @HiveField(6)
  final String tracking;
  @HiveField(7)
  final DateTime date;
  @HiveField(8)
  final String userName;
  @HiveField(9)
  final String userPhone;
  @HiveField(10)
  final String address;
  @HiveField(11)
  final int pointsAwarded;
  @HiveField(12)
  final int pointsRedeemed;
  @HiveField(13)
  final double discountAmount;
  @HiveField(14)
  final String? couponCode;
  @HiveField(15)
  final double shippingCost;
  @HiveField(16)
  final bool isHiddenForUser;
  @HiveField(17)
  final bool isHiddenForAdmin;
  @HiveField(18)
  final String? landmark; // NEW: Nearest landmark for delivery

  const OrderModel({
    required this.id,
    required this.userId,
    required this.tenantId,
    required this.total,
    required this.items,
    this.status = OrderStatus.active,
    this.tracking = 'Preparing',
    required this.userName,
    required this.userPhone,
    required this.date,
    required this.address,
    this.landmark,
    this.pointsAwarded = 0,
    this.pointsRedeemed = 0,
    this.discountAmount = 0.0,
    this.shippingCost = 0.0,
    this.couponCode,
    this.isHiddenForUser = false,
    this.isHiddenForAdmin = false,
  });

  @override
  List<Object?> get props => [
        id,
        userId,
        tenantId,
        total,
        items,
        status,
        tracking,
        date,
        address,
        landmark,
        userName,
        userPhone,
        pointsAwarded,
        pointsRedeemed,
        discountAmount,
        shippingCost,
        couponCode,
        isHiddenForUser,
        isHiddenForAdmin,
      ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'tenantId': tenantId,
      'total': total,
      'items': items,
      'status': status.name,
      'tracking': tracking,
      'date': date.toIso8601String(),
      'address': address,
      'landmark': landmark,
      'userName': userName,
      'userPhone': userPhone,
      'pointsAwarded': pointsAwarded,
      'pointsRedeemed': pointsRedeemed,
      'discountAmount': discountAmount,
      'shippingCost': shippingCost,
      'couponCode': couponCode,
      'isHiddenForUser': isHiddenForUser,
      'isHiddenForAdmin': isHiddenForAdmin,
    };
  }

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    if (val is Timestamp) return val.toDate();
    return DateTime.now();
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      total: (json['total'] as num? ?? 0.0).toDouble(),
      items: (json['items'] as List?)?.cast<Map<String, dynamic>>() ?? [],
      status: OrderStatus.values.firstWhere(
        (s) => s.name.toLowerCase() == (json['status'] as String? ?? 'active').toLowerCase(),
        orElse: () => OrderStatus.active,
      ),
      tracking: json['tracking'] as String? ?? 'Preparing',
      date: _parseDate(json['date']),
      address: json['address'] as String? ?? '',
      landmark: json['landmark'] as String?,
      userName: json['userName'] as String? ?? 'Guest',
      userPhone: json['userPhone'] as String? ?? '',
      pointsAwarded: json['pointsAwarded'] as int? ?? 0,
      pointsRedeemed: json['pointsRedeemed'] as int? ?? 0,
      discountAmount: (json['discountAmount'] as num? ?? 0.0).toDouble(),
      shippingCost: (json['shippingCost'] as num? ?? 0.0).toDouble(),
      couponCode: json['couponCode'] as String?,
      isHiddenForUser: json['isHiddenForUser'] as bool? ?? false,
      isHiddenForAdmin: json['isHiddenForAdmin'] as bool? ?? false,
    );
  }
}
