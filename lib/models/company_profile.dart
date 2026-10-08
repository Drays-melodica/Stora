class CompanyProfile {
  final String companyName;
  final String? address;
  final String? city;
  final String? phone;
  final String? email;
  final String? taxId;
  final String? website;
  final String? logoPath;
  final DateTime updatedAt;

  const CompanyProfile({
    this.companyName = '',
    this.address,
    this.city,
    this.phone,
    this.email,
    this.taxId,
    this.website,
    this.logoPath,
    required this.updatedAt,
  });

  bool get isConfigured => companyName.trim().isNotEmpty;

  /// Afficher le bloc société sur les PDF (nom, coordonnées ou logo).
  bool get hasPrintIdentity =>
      isConfigured ||
      infoLines.isNotEmpty ||
      (logoPath != null && logoPath!.trim().isNotEmpty);

  List<String> get infoLines {
    final lines = <String>[];
    if (address != null && address!.trim().isNotEmpty) {
      lines.add(address!.trim());
    }
    if (city != null && city!.trim().isNotEmpty) {
      lines.add(city!.trim());
    }
    if (phone != null && phone!.trim().isNotEmpty) {
      lines.add('Tél: ${phone!.trim()}');
    }
    if (email != null && email!.trim().isNotEmpty) {
      lines.add('Email: ${email!.trim()}');
    }
    if (taxId != null && taxId!.trim().isNotEmpty) {
      lines.add('NIF/RC: ${taxId!.trim()}');
    }
    if (website != null && website!.trim().isNotEmpty) {
      lines.add(website!.trim());
    }
    return lines;
  }

  String get displayName =>
      companyName.trim().isNotEmpty ? companyName.trim() : 'STORA';

  Map<String, dynamic> toMap() => {
        'id': 1,
        'company_name': companyName,
        'address': address,
        'city': city,
        'phone': phone,
        'email': email,
        'tax_id': taxId,
        'website': website,
        'logo_path': logoPath,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory CompanyProfile.fromMap(Map<String, dynamic> map) => CompanyProfile(
        companyName: map['company_name'] as String? ?? '',
        address: map['address'] as String?,
        city: map['city'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        taxId: map['tax_id'] as String?,
        website: map['website'] as String?,
        logoPath: map['logo_path'] as String?,
        updatedAt: DateTime.parse(map['updated_at'] as String),
      );

  CompanyProfile copyWith({
    String? companyName,
    String? address,
    String? city,
    String? phone,
    String? email,
    String? taxId,
    String? website,
    String? logoPath,
    bool clearLogo = false,
    DateTime? updatedAt,
  }) =>
      CompanyProfile(
        companyName: companyName ?? this.companyName,
        address: address ?? this.address,
        city: city ?? this.city,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        taxId: taxId ?? this.taxId,
        website: website ?? this.website,
        logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
