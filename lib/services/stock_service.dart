import '../database/database_helper.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/stock_movement.dart';
import '../models/warehouse.dart';
import 'auth_service.dart';

class StockService {
  StockService._();
  static final StockService instance = StockService._();

  final _db = DatabaseHelper.instance;
  final _auth = AuthService.instance;

  Future<int> _resolveWarehouse(int? warehouseId) async {
    if (warehouseId != null) return warehouseId;
    final wh = await _db.getDefaultWarehouse();
    if (wh?.id == null) throw Exception('Aucun entrepôt configuré.');
    return wh!.id!;
  }

  Future<StockMovement> addEntry({
    required int productId,
    required int quantity,
    String? reference,
    String? notes,
    int? warehouseId,
    String? lotNumber,
    DateTime? expiryDate,
  }) async {
    return _applyMovement(
      productId: productId,
      quantity: quantity,
      type: MovementType.entry,
      reference: reference,
      notes: notes,
      warehouseId: warehouseId,
      lotNumber: lotNumber,
      expiryDate: expiryDate,
    );
  }

  Future<StockMovement> addExit({
    required int productId,
    required int quantity,
    String? reference,
    String? notes,
    int? warehouseId,
  }) async {
    final product = await _db.getProductById(productId);
    if (product == null) throw Exception('Produit introuvable');
    if (product.quantity < quantity) {
      throw Exception('Stock insuffisant (${product.quantity} disponible)');
    }
    final whId = await _resolveWarehouse(warehouseId);
    final whQty = await _db.getWarehouseStock(whId, productId);
    if (whQty < quantity) {
      throw Exception(
          'Stock insuffisant dans l\'entrepôt ($whQty disponible)');
    }
    return _applyMovement(
      productId: productId,
      quantity: quantity,
      type: MovementType.exit,
      reference: reference,
      notes: notes,
      warehouseId: warehouseId,
    );
  }

  Future<StockMovement> adjustStock({
    required int productId,
    required int newQuantity,
    String? notes,
    int? warehouseId,
  }) async {
    final product = await _db.getProductById(productId);
    if (product == null) throw Exception('Produit introuvable');

    final diff = newQuantity - product.quantity;
    if (diff == 0) {
      throw Exception('Quantité identique au stock actuel');
    }

    return _applyMovement(
      productId: productId,
      quantity: diff.abs(),
      type: MovementType.adjustment,
      notes: notes ?? 'Ajustement inventaire',
      forceNewQuantity: newQuantity,
      warehouseId: warehouseId,
    );
  }

  Future<StockMovement> addReturnIn({
    required int productId,
    required int quantity,
    String? reference,
    String? notes,
    int? warehouseId,
  }) {
    return _applyMovement(
      productId: productId,
      quantity: quantity,
      type: MovementType.returnIn,
      reference: reference,
      notes: notes ?? 'Retour client',
      warehouseId: warehouseId,
    );
  }

  Future<StockMovement> addReturnOut({
    required int productId,
    required int quantity,
    String? reference,
    String? notes,
    int? warehouseId,
  }) async {
    final product = await _db.getProductById(productId);
    if (product == null) throw Exception('Produit introuvable');
    if (product.quantity < quantity) {
      throw Exception('Stock insuffisant');
    }
    return _applyMovement(
      productId: productId,
      quantity: quantity,
      type: MovementType.returnOut,
      reference: reference,
      notes: notes ?? 'Retour fournisseur',
      warehouseId: warehouseId,
    );
  }

  Future<void> transferStock({
    required int productId,
    required int fromWarehouseId,
    required int toWarehouseId,
    required int quantity,
    String? notes,
  }) async {
    if (fromWarehouseId == toWarehouseId) {
      throw Exception('Entrepôts source et destination identiques.');
    }
    if (quantity <= 0) throw Exception('Quantité invalide.');

    final fromQty = await _db.getWarehouseStock(fromWarehouseId, productId);
    if (fromQty < quantity) {
      throw Exception('Stock insuffisant dans l\'entrepôt source ($fromQty).');
    }

    final toQty = await _db.getWarehouseStock(toWarehouseId, productId);
    await _db.setWarehouseStock(
        fromWarehouseId, productId, fromQty - quantity);
    await _db.setWarehouseStock(toWarehouseId, productId, toQty + quantity);

    final number = 'TR-${DateTime.now().millisecondsSinceEpoch}';
    await _db.insertTransfer({
      'number': number,
      'product_id': productId,
      'from_warehouse_id': fromWarehouseId,
      'to_warehouse_id': toWarehouseId,
      'quantity': quantity,
      'notes': notes,
      'agent_id': _auth.currentAgentId,
      'agent_name': _auth.currentAgentName,
      'created_at': DateTime.now().toIso8601String(),
    });

    final product = await _db.getProductById(productId);
    if (product != null) {
      await _db.insertMovement(StockMovement(
        productId: productId,
        type: MovementType.transfer,
        quantity: quantity,
        quantityBefore: product.quantity,
        quantityAfter: product.quantity,
        reference: number,
        notes: notes,
        agentId: _auth.currentAgentId,
        agentName: _auth.currentAgentName,
        warehouseId: fromWarehouseId,
        createdAt: DateTime.now(),
      ));
    }
  }

  Future<StockMovement> _applyMovement({
    required int productId,
    required int quantity,
    required MovementType type,
    String? reference,
    String? notes,
    int? forceNewQuantity,
    int? warehouseId,
    String? lotNumber,
    DateTime? expiryDate,
  }) async {
    if (!_auth.isLoggedIn) {
      throw Exception('Session expirée. Reconnectez-vous.');
    }

    final product = await _db.getProductById(productId);
    if (product == null) throw Exception('Produit introuvable');

    final whId = await _resolveWarehouse(warehouseId);
    final before = product.quantity;
    int after;

    switch (type) {
      case MovementType.entry:
      case MovementType.returnIn:
        after = before + quantity;
      case MovementType.exit:
      case MovementType.returnOut:
        after = before - quantity;
      case MovementType.adjustment:
        after = forceNewQuantity ?? before;
      case MovementType.transfer:
        after = before;
    }

    // Sync warehouse stock
    final whBefore = await _db.getWarehouseStock(whId, productId);
    int whAfter = whBefore;
    switch (type) {
      case MovementType.entry:
      case MovementType.returnIn:
        whAfter = whBefore + quantity;
      case MovementType.exit:
      case MovementType.returnOut:
        whAfter = whBefore - quantity;
      case MovementType.adjustment:
        whAfter = forceNewQuantity ?? whBefore;
      case MovementType.transfer:
        break;
    }
    if (type != MovementType.transfer) {
      await _db.setWarehouseStock(whId, productId, whAfter < 0 ? 0 : whAfter);
    }

    // Lot tracking on entry
    if ((type == MovementType.entry || type == MovementType.returnIn) &&
        lotNumber != null &&
        lotNumber.trim().isNotEmpty) {
      await _db.insertBatch(ProductBatch(
        productId: productId,
        warehouseId: whId,
        lotNumber: lotNumber.trim().toUpperCase(),
        expiryDate: expiryDate,
        quantity: quantity,
        createdAt: DateTime.now(),
      ));
    }

    final movement = StockMovement(
      productId: productId,
      type: type,
      quantity: quantity,
      quantityBefore: before,
      quantityAfter: after,
      reference: reference,
      notes: notes,
      agentId: _auth.currentAgentId,
      agentName: _auth.currentAgentName,
      warehouseId: whId,
      lotNumber: lotNumber,
      createdAt: DateTime.now(),
    );

    await _db.insertMovement(movement);
    if (type != MovementType.transfer) {
      await _db.updateProduct(
        product.copyWith(quantity: after, updatedAt: DateTime.now()),
      );
    }

    return movement;
  }

  Future<List<Product>> searchProducts(String query) =>
      _db.getProducts(search: query);

  Future<List<Product>> getAllProducts() => _db.getProducts();

  Future<List<Product>> getLowStock() => _db.getLowStockProducts();

  Future<List<Product>> getReorderSuggestions() async {
    final products = await _db.getLowStockProducts();
    return products;
  }

  Future<List<StockMovement>> getRecentMovements({int limit = 50}) =>
      _db.getMovements(limit: limit);

  Future<Map<String, dynamic>> getSummary() => _db.getStockSummary();

  Future<Map<String, dynamic>> getEnterpriseKpis() =>
      _db.getEnterpriseKpis();

  Future<List<Warehouse>> getWarehouses() => _db.getWarehouses();
}
