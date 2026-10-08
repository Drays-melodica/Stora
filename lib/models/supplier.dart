class Supplier {
  final int? id;
  final String name;
  final String? contact;
  final String? phone;
  final String? email;
  final String? address;
  final DateTime createdAt;

  const Supplier({
    this.id,
    required this.name,
    this.contact,
    this.phone,
    this.email,
    this.address,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'contact': contact,
        'phone': phone,
        'email': email,
        'address': address,
        'created_at': createdAt.toIso8601String(),
      };

  factory Supplier.fromMap(Map<String, dynamic> map) => Supplier(
        id: map['id'] as int?,
        name: map['name'] as String,
        contact: map['contact'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Supplier copyWith({
    int? id,
    String? name,
    String? contact,
    String? phone,
    String? email,
    String? address,
    DateTime? createdAt,
  }) =>
      Supplier(
        id: id ?? this.id,
        name: name ?? this.name,
        contact: contact ?? this.contact,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        createdAt: createdAt ?? this.createdAt,
      );
}
