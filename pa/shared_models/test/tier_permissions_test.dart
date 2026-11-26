import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  group('TenantModel Tier permissions', () {
    test('Tier A restricts cloud sync, LAN, Excel, multi-branch, and video gen even with stale flags', () {
      final tierA = TenantModel(
        id: 't-a',
        name: 'Tier A Store',
        adminIds: const ['u1'],
        createdAt: DateTime(2026, 1, 1),
        isActive: true,
        isPosEnabled: true,
        posTier: 'A',
      );

      expect(tierA.effectivePosTier, 'A');
      expect(tierA.effectivePosDeviceLimit, 1);
      expect(tierA.isPosLanAllowed, isFalse);
      expect(tierA.isPosCloudAllowed, isFalse);
      expect(tierA.isPosRemoteDashAllowed, isFalse);
      expect(tierA.isPosExcelAllowed, isFalse);
      expect(tierA.isPosMultiBranchAllowed, isFalse);
      expect(tierA.isPosVideoGenAllowed, isFalse);

      final tierAWithStaleFlags = tierA.copyWith(
        posCloudBackupEnabled: true,
        posLanSyncEnabled: true,
        posExcelEnabled: true,
        posMultiBranchEnabled: true,
        posRemoteDashEnabled: true,
        posVideoGenEnabled: true,
      );
      expect(tierAWithStaleFlags.isPosCloudAllowed, isFalse);
      expect(tierAWithStaleFlags.isPosLanAllowed, isFalse);
      expect(tierAWithStaleFlags.isPosExcelAllowed, isFalse);
      expect(tierAWithStaleFlags.isPosMultiBranchAllowed, isFalse);
      expect(tierAWithStaleFlags.isPosRemoteDashAllowed, isFalse);
      expect(tierAWithStaleFlags.isPosVideoGenAllowed, isFalse);
    });

    test('Tier B enables LAN sync only, Tier C enables cloud/excel/video, Tier D enables all', () {
      final tierB = TenantModel(
        id: 't-b',
        name: 'Tier B Store',
        adminIds: const ['u1'],
        createdAt: DateTime(2026, 1, 1),
        posTier: 'B',
      );
      expect(tierB.effectivePosDeviceLimit, 5);
      expect(tierB.isPosLanAllowed, isTrue);
      expect(tierB.isPosCloudAllowed, isFalse);
      expect(tierB.isPosExcelAllowed, isFalse);
      expect(tierB.isPosMultiBranchAllowed, isFalse);

      final tierC = tierB.copyWith(posTier: 'C');
      expect(tierC.effectivePosDeviceLimit, 10);
      expect(tierC.isPosLanAllowed, isTrue);
      expect(tierC.isPosCloudAllowed, isTrue);
      expect(tierC.isPosExcelAllowed, isTrue);
      expect(tierC.isPosVideoGenAllowed, isTrue);
      expect(tierC.isPosMultiBranchAllowed, isFalse);

      final tierD = tierB.copyWith(posTier: 'D');
      expect(tierD.effectivePosDeviceLimit, -1);
      expect(tierD.isPosCloudAllowed, isTrue);
      expect(tierD.isPosMultiBranchAllowed, isTrue);
    });

    test('Subscription expired beyond grace days automatically downgrades to Tier A', () {
      final expired = TenantModel(
        id: 't-exp',
        name: 'Expired Store',
        adminIds: const ['u1'],
        createdAt: DateTime(2025, 1, 1),
        posTier: 'D',
        posDeviceLimit: -1,
        posCloudBackupEnabled: true,
        posExcelEnabled: true,
        posMultiBranchEnabled: true,
        posExpiryDate: DateTime.now().subtract(const Duration(days: 30)),
        posGraceDays: 14,
      );

      expect(expired.isPosSubscriptionExpiredBeyondGrace, isTrue);
      expect(expired.effectivePosTier, 'A');
      expect(expired.effectivePosDeviceLimit, 1);
      expect(expired.isPosCloudAllowed, isFalse);
      expect(expired.isPosExcelAllowed, isFalse);
      expect(expired.isPosMultiBranchAllowed, isFalse);
    });
  });
}
