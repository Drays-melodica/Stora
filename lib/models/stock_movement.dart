enum MovementType { entry, exit, adjustment, transfer, returnIn, returnOut }

class StockMovement {
  final int? id;
  final int productId;
  final MovementType type;
  final int quantity;
  final int quantityBefore;
  final int quantityAfter;
  final String? reference;
  final String? notes;
  final int? agentId;
  final String agentName;
  final int? warehouseId;
  final String? lotNumber;
  final DateTime createdAt;

  const StockMovement({
    this.id,
    required this.productId,
    required this.type,
    required this.quantity,
    required this.quantityBefore,
    required this.quantityAfter,
    this.reference,
    this.notes,
    this.agentId,
    required this.agentName,
    this.warehouseId,
    this.lotNumber,
    required this.createdAt,
  });

  String get typeLabel {
    switch (type) {
      case MovementType.entry:
        return 'ENTREE';
      case MovementType.exit:
        return 'SORTIE';
      case MovementType.adjustment:
        return 'AJUSTEMENT';
      case MovementType.transfer:
        return 'TRANSFERT';
      case MovementType.returnIn:
        return 'RETOUR CLIENT';
      case MovementType.returnOut:
        return 'RETOUR FOURN.';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'type': type.name,
        'quantity': quantity,
        'quantity_before': quantityBefore,
        'quantity_after': quantityAfter,
        'reference': reference,
        'notes': notes,
        'agent_id': agentId,
        'agent_name': agentName,
        'warehouse_id': warehouseId,
        'lot_number': lotNumber,
        'created_at': createdAt.toIso8601String(),
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String;
    MovementType type;
    try {
      type = MovementType.values.byName(typeName);
    } catch (_) {
      type = MovementType.adjustment;
    }
    return StockMovement(
      id: map['id'] as int?,
      productId: map['product_id'] as int,
      type: type,
      quantity: map['quantity'] as int,
      quantityBefore: map['quantity_before'] as int,
      quantityAfter: map['quantity_after'] as int,
      reference: map['reference'] as String?,
      notes: map['notes'] as String?,
      agentId: map['agent_id'] as int?,
      agentName: map['agent_name'] as String? ?? 'INCONNU',
      warehouseId: map['warehouse_id'] as int?,
      lotNumber: map['lot_number'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
