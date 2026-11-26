import 'package:flutter_test/flutter_test.dart';
import 'package:shared_models/shared_models.dart';

void main() {
  group('CurrencyDefaults', () {
    test('maps countries to expected default currencies and normalizes codes', () {
      expect(CurrencyDefaults.forCountry('iq'), 'د.ع');
      expect(CurrencyDefaults.forCountry('sa'), 'ر.س');
      expect(CurrencyDefaults.forCountry('us'), '\$');
      expect(CurrencyDefaults.normalizeCurrency('IQD'), 'د.ع');
      expect(CurrencyDefaults.normalizeCurrency('AED'), 'د.إ');
      expect(CurrencyDefaults.normalizeCurrency('USD'), '\$');
      expect(CurrencyDefaults.countryNameAr('iq'), 'العراق');
    });
  });

  group('BatchInventoryHelper & Pharmacist FEFO scenario', () {
    final batch1 = ProductStorageLocation(
      warehouseName: 'المخزن الرئيسي',
      batchNumber: 'LOT-JAN',
      receivedAt: DateTime(2027, 1, 1),
      expiryDate: DateTime(2027, 8, 31),
      quantity: 20,
    );
    final batch2 = ProductStorageLocation(
      warehouseName: 'المخزن الرئيسي',
      batchNumber: 'LOT-FEB',
      receivedAt: DateTime(2027, 2, 1),
      expiryDate: DateTime(2027, 6, 30),
      quantity: 30,
    );

    final medicine = ProductModel(
      id: 'med-1',
      tenantId: 't-1',
      name: 'Amoxicillin 500mg',
      description: '',
      price: 5000,
      category: 'أدوية',
      stockQuantity: 50,
      variants: [
        ProductVariant(
          color: 'Default',
          size: 'Default',
          stock: 50,
          storageLocations: [batch1, batch2],
        ),
      ],
    );

    test('distinguishes separate batches via sameLot', () {
      expect(batch1.sameLot(batch2), isFalse);
      expect(
        batch1.sameLot(batch1.copyWith(quantity: 99)),
        isTrue,
      );
    });

    test('suggests and deducts FEFO from earliest-expiring batch first', () {
      final nowBeforeExpiry = DateTime(2027, 3, 1);
      expect(
        BatchInventoryHelper.sellableStock(medicine, now: nowBeforeExpiry),
        50,
      );

      final next = BatchInventoryHelper.nextSellableBatch(
        medicine,
        now: nowBeforeExpiry,
      );
      expect(next?.batchNumber, 'LOT-FEB');

      final afterSale = BatchInventoryHelper.deductFefo(
        [batch1, batch2],
        5,
        now: nowBeforeExpiry,
      );
      expect(afterSale[0].quantity, 20);
      expect(afterSale[1].quantity, 25);

      final updatedProduct = medicine.copyWith(
        variants: [medicine.variants.first.copyWith(storageLocations: afterSale)],
      );
      final alerts = BatchInventoryHelper.inspectBatches(
        updatedProduct,
        warnDays: 30,
        now: DateTime(2027, 6, 15),
      );
      expect(alerts.length, 1);
      expect(alerts.first.isExpired, isFalse);
      expect(alerts.first.message, contains('بقيت 25 قطعة'));
      expect(alerts.first.message, contains('2027-06-30'));
    });

    test('blocks expired batch while keeping valid batch sellable', () {
      final postBatch2Expiry = DateTime(2027, 7, 5);
      final partiallySold = medicine.copyWith(
        variants: [
          medicine.variants.first.copyWith(
            storageLocations: [batch1, batch2.copyWith(quantity: 25)],
          ),
        ],
      );

      expect(
        BatchInventoryHelper.sellableStock(partiallySold, now: postBatch2Expiry),
        20,
      );
      final next = BatchInventoryHelper.nextSellableBatch(
        partiallySold,
        now: postBatch2Expiry,
      );
      expect(next?.batchNumber, 'LOT-JAN');

      final deducted = BatchInventoryHelper.deductFefo(
        partiallySold.variants.first.storageLocations,
        5,
        now: postBatch2Expiry,
      );
      // Expired batch2 stays at 25, valid batch1 drops from 20 -> 15
      expect(deducted[0].quantity, 15);
      expect(deducted[1].quantity, 25);

      final fullyExpired = medicine.copyWith(
        variants: [
          medicine.variants.first.copyWith(
            storageLocations: [batch1, batch2],
          ),
        ],
      );
      expect(
        BatchInventoryHelper.sellableStock(fullyExpired, now: DateTime(2027, 9, 10)),
        0,
      );
      expect(
        BatchInventoryHelper.nextSellableBatch(fullyExpired, now: DateTime(2027, 9, 10)),
        isNull,
      );
    });
  });

  group('Model roundtrip serialization', () {
    test('preserves tenant countryCode, invoice currency, and item batch info', () {
      final tenant = TenantModel(
        id: 't1',
        name: 'Al-Shifa Pharmacy',
        adminIds: const ['u1'],
        createdAt: DateTime(2026, 1, 1),
        currencyUnit: 'د.ع',
        countryCode: 'iq',
      );
      final decodedTenant = TenantModel.fromJson(tenant.toJson());
      expect(decodedTenant.countryCode, 'iq');
      expect(decodedTenant.currencyUnit, 'د.ع');

      final invoice = SalesInvoiceModel(
        id: 'inv-1',
        tenantId: 't1',
        receiptNumber: 'R-100',
        date: DateTime(2027, 2, 1),
        totalAmount: 25,
        currency: '\$',
        items: [
          SalesItem(
            productId: 'p1',
            productName: 'Med',
            quantity: 2,
            unitPrice: 12.5,
            warehouseName: 'USD Branch',
            batchNumber: 'LOT-B2',
            expiryDate: DateTime(2027, 6, 30),
          ),
        ],
      );
      final decodedInv = SalesInvoiceModel.fromJson(invoice.toJson());
      expect(decodedInv.currency, '\$');
      expect(decodedInv.items.first.batchNumber, 'LOT-B2');
      expect(decodedInv.items.first.expiryDate?.year, 2027);
    });
  });
}
