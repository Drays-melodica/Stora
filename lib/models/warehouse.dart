class Warehouse {
  final int? id;
  final String code;
  final String name;
  final String? address;
  final bool isDefault;
  final bool active;
  final DateTime createdAt;

  const Warehouse({
    this.id,
    required this.code,
    required this.name,
    this.address,
    this.isDefault = false,
    this.active = true,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'address': address,
        'is_default': isDefault ? 1 : 0,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory Warehouse.fromMap(Map<String, dynamic> map) => Warehouse(
        id: map['id'] as int?,
        code: map['code'] as String,
        name: map['name'] as String,
        address: map['address'] as String?,
        isDefault: (map['is_default'] as int? ?? 0) == 1,
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class WarehouseStock {
  final int warehouseId;
  final int productId;
  final int quantity;
  final String? warehouseCode;
  final String? warehouseName;
  final String? productCode;
  final String? productName;

  const WarehouseStock({
    required this.warehouseId,
    required this.productId,
    required this.quantity,
    this.warehouseCode,
    this.warehouseName,
    this.productCode,
    this.productName,
  });

  factory WarehouseStock.fromMap(Map<String, dynamic> map) => WarehouseStock(
        warehouseId: map['warehouse_id'] as int,
        productId: map['product_id'] as int,
        quantity: map['quantity'] as int? ?? 0,
        warehouseCode: map['warehouse_code'] as String?,
        warehouseName: map['warehouse_name'] as String?,
        productCode: map['product_code'] as String?,
        productName: map['product_name'] as String?,
      );
}
