class Product {
  final int? id;
  final String code;
  final String name;
  final int? categoryId;
  final int? supplierId;
  final String unit;
  final double purchasePrice;
  final double salePrice;
  final int quantity;
  final int minStock;
  final String? location;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Product({
    this.id,
    required this.code,
    required this.name,
    this.categoryId,
    this.supplierId,
    this.unit = 'UN',
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.quantity = 0,
    this.minStock = 0,
    this.location,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isLowStock => quantity <= minStock;

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'category_id': categoryId,
        'supplier_id': supplierId,
        'unit': unit,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'quantity': quantity,
        'min_stock': minStock,
        'location': location,
        'description': description,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        code: map['code'] as String,
        name: map['name'] as String,
        categoryId: map['category_id'] as int?,
        supplierId: map['supplier_id'] as int?,
        unit: map['unit'] as String? ?? 'UN',
        purchasePrice: (map['purchase_price'] as num?)?.toDouble() ?? 0,
        salePrice: (map['sale_price'] as num?)?.toDouble() ?? 0,
        quantity: map['quantity'] as int? ?? 0,
        minStock: map['min_stock'] as int? ?? 0,
        location: map['location'] as String?,
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  Product copyWith({
    int? id,
    String? code,
    String? name,
    int? categoryId,
    int? supplierId,
    String? unit,
    double? purchasePrice,
    double? salePrice,
    int? quantity,
    int? minStock,
    String? location,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Product(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        categoryId: categoryId ?? this.categoryId,
        supplierId: supplierId ?? this.supplierId,
        unit: unit ?? this.unit,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        salePrice: salePrice ?? this.salePrice,
        quantity: quantity ?? this.quantity,
        minStock: minStock ?? this.minStock,
        location: location ?? this.location,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
