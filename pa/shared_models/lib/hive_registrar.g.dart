import 'package:hive_ce/hive.dart';
import 'package:shared_models/src/models/attendance_model.dart';
import 'package:shared_models/src/models/category_model.dart';
import 'package:shared_models/src/models/customer_model.dart';
import 'package:shared_models/src/models/expense_model.dart';
import 'package:shared_models/src/models/order_model.dart';
import 'package:shared_models/src/models/pos_role_model.dart';
import 'package:shared_models/src/models/product_model.dart';
import 'package:shared_models/src/models/product_storage_location.dart';
import 'package:shared_models/src/models/product_variant.dart';
import 'package:shared_models/src/models/purchase_invoice_model.dart';
import 'package:shared_models/src/models/sales_invoice_model.dart';
import 'package:shared_models/src/models/staff_member_model.dart';
import 'package:shared_models/src/models/supplier_model.dart';
import 'package:shared_models/src/models/tenant_model.dart';
import 'package:shared_models/src/models/user_model.dart';
import 'package:shared_models/src/models/car_contract_model.dart';

extension HiveRegistrar on HiveInterface {
  void registerAdapters() {
    registerAdapter(AttendanceModelAdapter());
    registerAdapter(CategoryModelAdapter());
    registerAdapter(CustomerModelAdapter());
    registerAdapter(ExpenseModelAdapter());
    registerAdapter(OrderModelAdapter());
    registerAdapter(OrderStatusAdapter());
    registerAdapter(PosRoleModelAdapter());
    registerAdapter(ProductModelAdapter());
    registerAdapter(ProductStorageLocationAdapter());
    registerAdapter(ProductVariantAdapter());
    registerAdapter(PurchaseInvoiceModelAdapter());
    registerAdapter(InvoiceItemAdapter());
    registerAdapter(PurchaseInvoiceStatusAdapter());
    registerAdapter(SalesInvoiceModelAdapter());
    registerAdapter(SalesItemAdapter());
    registerAdapter(SalesInvoiceStatusAdapter());
    registerAdapter(StaffMemberModelAdapter());
    registerAdapter(SupplierModelAdapter());
    registerAdapter(TenantModelAdapter());
    registerAdapter(UserModelAdapter());
    registerAdapter(CarContractModelAdapter());
  }
}
