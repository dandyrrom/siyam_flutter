import '../models/supplier.dart';
import 'supabase/supabase_supplier_service.dart';

// ============================================================================
// SUPPLIER SERVICE
// ============================================================================
//
// SIYAM now uses the real Supabase backend.
//
// SupplierService() therefore resolves directly to SupabaseSupplierService.
// No MockDatabase / MockSupplierService is used here.
// ============================================================================

abstract interface class SupplierService {
  factory SupplierService() => SupabaseSupplierService();

  Future<List<Supplier>> fetchSuppliers();

  Future<Supplier> createSupplier({
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  });

  Future<Supplier> updateSupplier({
    required String suppId,
    required String suppName,
    String? contactNum,
    String? contactTel,
    String? address,
  });

  Future<void> deleteSupplier(String suppId);

  Future<List<PurchaseOrder>> fetchAllPurchaseOrders();

  Future<List<PurchaseOrder>> fetchPurchaseOrdersForSupplier(
    String suppId,
  );

  Future<PurchaseOrder?> fetchPurchaseOrder(String purId);

  Future<List<OrderLineItem>> fetchOrderItems(String purId);

  Future<List<OrderSpendEntry>> fetchOrderSpendEntries();

  Future<PurchaseOrder> createPurchaseOrder({
    required String suppId,
    required String recordedByUserId,
    required String receivedBy,
    required List<OrderItemInput> items,
    DateTime? receivedDate,
  });
}