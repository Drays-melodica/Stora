class ProductBatch {
  final int? id;
  final int productId;
  final int? warehouseId;
  final String lotNumber;
  final DateTime? expiryDate;
  final int quantity;
  final DateTime createdAt;
  final String? productCode;
  final String? productName;

  const ProductBatch({
    this.id,
    required this.productId,
    this.warehouseId,
    required this.lotNumber,
    this.expiryDate,
    required this.quantity,
    required this.createdAt,
    this.productCode,
    this.productName,
  });

  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.isBefore(DateTime.now());
  }

  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final days = expiryDate!.difference(DateTime.now()).inDays;
    return days >= 0 && days <= 30;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'warehouse_id': warehouseId,
        'lot_number': lotNumber,
        'expiry_date': expiryDate?.toIso8601String(),
        'quantity': quantity,
        'created_at': createdAt.toIso8601String(),
      };

  factory ProductBatch.fromMap(Map<String, dynamic> map) => ProductBatch(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        warehouseId: map['warehouse_id'] as int?,
        lotNumber: map['lot_number'] as String,
        expiryDate: map['expiry_date'] != null
            ? DateTime.tryParse(map['expiry_date'] as String)
            : null,
        quantity: map['quantity'] as int? ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
        productCode: map['product_code'] as String?,
        productName: map['product_name'] as String?,
      );
}
