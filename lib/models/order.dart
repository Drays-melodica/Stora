enum OrderStatus { draft, confirmed, partial, completed, cancelled }

class PurchaseOrder {
  final int? id;
  final String number;
  final int? supplierId;
  final OrderStatus status;
  final String? notes;
  final int? agentId;
  final String agentName;
  final DateTime orderDate;
  final DateTime? expectedDate;
  final DateTime createdAt;
  final String? supplierName;
  final List<PurchaseOrderLine> lines;

  const PurchaseOrder({
    this.id,
    required this.number,
    this.supplierId,
    this.status = OrderStatus.draft,
    this.notes,
    this.agentId,
    required this.agentName,
    required this.orderDate,
    this.expectedDate,
    required this.createdAt,
    this.supplierName,
    this.lines = const [],
  });

  String get statusLabel => status.name.toUpperCase();

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'supplier_id': supplierId,
        'status': status.name,
        'notes': notes,
        'agent_id': agentId,
        'agent_name': agentName,
        'order_date': orderDate.toIso8601String(),
        'expected_date': expectedDate?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) => PurchaseOrder(
        id: map['id'] as int?,
        number: map['number'] as String,
        supplierId: map['supplier_id'] as int?,
        status: OrderStatus.values.byName(map['status'] as String),
        notes: map['notes'] as String?,
        agentId: map['agent_id'] as int?,
        agentName: map['agent_name'] as String? ?? 'INCONNU',
        orderDate: DateTime.parse(map['order_date'] as String),
        expectedDate: map['expected_date'] != null
            ? DateTime.tryParse(map['expected_date'] as String)
            : null,
        createdAt: DateTime.parse(map['created_at'] as String),
        supplierName: map['supplier_name'] as String?,
      );
}

class PurchaseOrderLine {
  final int? id;
  final int orderId;
  final int productId;
  final int quantityOrdered;
  final int quantityReceived;
  final double unitPrice;
  final String? productCode;
  final String? productName;

  const PurchaseOrderLine({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantityOrdered,
    this.quantityReceived = 0,
    this.unitPrice = 0,
    this.productCode,
    this.productName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'quantity_ordered': quantityOrdered,
        'quantity_received': quantityReceived,
        'unit_price': unitPrice,
      };

  factory PurchaseOrderLine.fromMap(Map<String, dynamic> map) =>
      PurchaseOrderLine(
        id: map['id'] as int?,
        orderId: map['order_id'] as int,
        productId: map['product_id'] as int,
        quantityOrdered: map['quantity_ordered'] as int,
        quantityReceived: map['quantity_received'] as int? ?? 0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        productCode: map['product_code'] as String?,
        productName: map['product_name'] as String?,
      );
}

class SalesOrder {
  final int? id;
  final String number;
  final int? customerId;
  final OrderStatus status;
  final String? notes;
  final int? agentId;
  final String agentName;
  final DateTime orderDate;
  final DateTime createdAt;
  final String? customerName;
  final List<SalesOrderLine> lines;

  const SalesOrder({
    this.id,
    required this.number,
    this.customerId,
    this.status = OrderStatus.draft,
    this.notes,
    this.agentId,
    required this.agentName,
    required this.orderDate,
    required this.createdAt,
    this.customerName,
    this.lines = const [],
  });

  String get statusLabel => status.name.toUpperCase();

  Map<String, dynamic> toMap() => {
        'id': id,
        'number': number,
        'customer_id': customerId,
        'status': status.name,
        'notes': notes,
        'agent_id': agentId,
        'agent_name': agentName,
        'order_date': orderDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory SalesOrder.fromMap(Map<String, dynamic> map) => SalesOrder(
        id: map['id'] as int?,
        number: map['number'] as String,
        customerId: map['customer_id'] as int?,
        status: OrderStatus.values.byName(map['status'] as String),
        notes: map['notes'] as String?,
        agentId: map['agent_id'] as int?,
        agentName: map['agent_name'] as String? ?? 'INCONNU',
        orderDate: DateTime.parse(map['order_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        customerName: map['customer_name'] as String?,
      );
}

class SalesOrderLine {
  final int? id;
  final int orderId;
  final int productId;
  final int quantityOrdered;
  final int quantityShipped;
  final double unitPrice;
  final String? productCode;
  final String? productName;

  const SalesOrderLine({
    this.id,
    required this.orderId,
    required this.productId,
    required this.quantityOrdered,
    this.quantityShipped = 0,
    this.unitPrice = 0,
    this.productCode,
    this.productName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'order_id': orderId,
        'product_id': productId,
        'quantity_ordered': quantityOrdered,
        'quantity_shipped': quantityShipped,
        'unit_price': unitPrice,
      };

  factory SalesOrderLine.fromMap(Map<String, dynamic> map) => SalesOrderLine(
        id: map['id'] as int?,
        orderId: map['order_id'] as int,
        productId: map['product_id'] as int,
        quantityOrdered: map['quantity_ordered'] as int,
        quantityShipped: map['quantity_shipped'] as int? ?? 0,
        unitPrice: (map['unit_price'] as num?)?.toDouble() ?? 0,
        productCode: map['product_code'] as String?,
        productName: map['product_name'] as String?,
      );
}
