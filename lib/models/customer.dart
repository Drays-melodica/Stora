class Customer {
  final int? id;
  final String code;
  final String name;
  final String? contact;
  final String? phone;
  final String? email;
  final String? address;
  final String? city;
  final double creditLimit;
  final DateTime createdAt;

  const Customer({
    this.id,
    required this.code,
    required this.name,
    this.contact,
    this.phone,
    this.email,
    this.address,
    this.city,
    this.creditLimit = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'contact': contact,
        'phone': phone,
        'email': email,
        'address': address,
        'city': city,
        'credit_limit': creditLimit,
        'created_at': createdAt.toIso8601String(),
      };

  factory Customer.fromMap(Map<String, dynamic> map) => Customer(
        id: map['id'] as int?,
        code: map['code'] as String,
        name: map['name'] as String,
        contact: map['contact'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        address: map['address'] as String?,
        city: map['city'] as String?,
        creditLimit: (map['credit_limit'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Customer copyWith({
    int? id,
    String? code,
    String? name,
    String? contact,
    String? phone,
    String? email,
    String? address,
    String? city,
    double? creditLimit,
    DateTime? createdAt,
  }) =>
      Customer(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        contact: contact ?? this.contact,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        address: address ?? this.address,
        city: city ?? this.city,
        creditLimit: creditLimit ?? this.creditLimit,
        createdAt: createdAt ?? this.createdAt,
      );
}
