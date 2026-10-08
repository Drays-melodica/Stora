class Category {
  final int? id;
  final String name;
  final String? description;
  final DateTime createdAt;

  const Category({
    this.id,
    required this.name,
    this.description,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'created_at': createdAt.toIso8601String(),
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as int?,
        name: map['name'] as String,
        description: map['description'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Category copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        createdAt: createdAt ?? this.createdAt,
      );
}
