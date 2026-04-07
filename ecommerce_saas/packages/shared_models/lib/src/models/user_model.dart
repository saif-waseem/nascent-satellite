import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 4)
class UserModel extends Equatable {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String email;
  @HiveField(2)
  final String? name;
  @HiveField(3)
  final String? tenantId;
  @HiveField(4)
  final int loyaltyPoints;
  @HiveField(5)
  final int pendingPoints;
  @HiveField(6)
  final int sharesCount;
  @HiveField(7)
  final double totalSpent;
  @HiveField(8)
  final String? password;
  @HiveField(9)
  final DateTime createdAt;
  @HiveField(10)
  final bool isBlocked;
  @HiveField(11)
  final String? address; 
  @HiveField(12)
  final DateTime? lastCheckInDate;
  @HiveField(13)
  final int checkInStreak;
  @HiveField(14)
  final int purchaseCount;
  @HiveField(15)
  final String? landmark;
  @HiveField(16)
  final String? phone;
  @HiveField(17)
  final double balance;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
    this.tenantId, 
    this.loyaltyPoints = 0,
    this.pendingPoints = 0,
    this.sharesCount = 0,
    this.totalSpent = 0.0,
    this.password,
    required this.createdAt,
    this.isBlocked = false,
    this.address, 
    this.landmark,
    this.phone,
    this.lastCheckInDate,
    this.checkInStreak = 0,
    this.purchaseCount = 0,
    this.balance = 0.0,
  });

  @override
  List<Object?> get props => [id, email, name, tenantId, loyaltyPoints, pendingPoints, sharesCount, totalSpent, password, createdAt, isBlocked, address, landmark, phone, lastCheckInDate, checkInStreak, purchaseCount, balance]; 

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'tenantId': tenantId, // Added to toJson
      'loyaltyPoints': loyaltyPoints,
      'pendingPoints': pendingPoints,
      'sharesCount': sharesCount,
      'totalSpent': totalSpent,
      'password': password,
      'createdAt': createdAt.toIso8601String(),
      'isBlocked': isBlocked,
      'address': address, 
      'landmark': landmark,
      'phone': phone,
      'lastCheckInDate': lastCheckInDate?.toIso8601String(),
      'checkInStreak': checkInStreak,
      'purchaseCount': purchaseCount,
      'balance': balance,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? tenantId, // Added to copyWith parameters
    int? loyaltyPoints,
    int? pendingPoints,
    int? sharesCount,
    double? totalSpent,
    String? password,
    DateTime? createdAt,
    bool? isBlocked,
    String? address, 
    String? landmark,
    String? phone,
    DateTime? lastCheckInDate,
    int? checkInStreak,
    int? purchaseCount,
    double? balance,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      tenantId: tenantId ?? this.tenantId, // Added to copyWith return
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      pendingPoints: pendingPoints ?? this.pendingPoints,
      sharesCount: sharesCount ?? this.sharesCount,
      totalSpent: totalSpent ?? this.totalSpent,
      password: password ?? this.password,
      createdAt: createdAt ?? this.createdAt,
      isBlocked: isBlocked ?? this.isBlocked,
      address: address ?? this.address, 
      landmark: landmark ?? this.landmark,
      phone: phone ?? this.phone,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      checkInStreak: checkInStreak ?? this.checkInStreak,
      purchaseCount: purchaseCount ?? this.purchaseCount,
      balance: balance ?? this.balance,
    );
  }

  static DateTime _parseDate(dynamic val) {
    if (val is DateTime) return val;
    if (val is String) return DateTime.parse(val);
    if (val is Timestamp) return val.toDate();
    return DateTime.now();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      tenantId: json['tenantId'] as String?, // Added to fromJson
      loyaltyPoints: json['loyaltyPoints'] as int? ?? 0,
      pendingPoints: json['pendingPoints'] as int? ?? 0,
      sharesCount: json['sharesCount'] as int? ?? 0,
      totalSpent: (json['totalSpent'] as num? ?? 0.0).toDouble(),
      password: json['password'] as String?,
      createdAt: _parseDate(json['createdAt']),
      isBlocked: json['isBlocked'] as bool? ?? false,
      address: json['address'] as String?,
      landmark: json['landmark'] as String?,
      phone: json['phone'] as String?,
      lastCheckInDate: json['lastCheckInDate'] != null ? _parseDate(json['lastCheckInDate']) : null,
      checkInStreak: json['checkInStreak'] as int? ?? 0,
      purchaseCount: json['purchaseCount'] as int? ?? 0,
      balance: (json['balance'] as num? ?? 0.0).toDouble(),
    );
  }
}

