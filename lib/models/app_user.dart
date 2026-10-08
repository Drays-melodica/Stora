enum UserRole { admin, agent }

class AppUser {
  final int? id;
  final String username;
  final String fullName;
  final UserRole role;
  final String passwordHash;
  final String salt;
  final bool active;
  final DateTime createdAt;

  const AppUser({
    this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.passwordHash,
    required this.salt,
    this.active = true,
    required this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;

  String get roleLabel => isAdmin ? 'ADMINISTRATEUR' : 'AGENT';

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'password_hash': passwordHash,
        'salt': salt,
        'role': role.name,
        'active': active ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
        id: map['id'] as int?,
        username: map['username'] as String,
        fullName: map['full_name'] as String,
        role: UserRole.values.byName(map['role'] as String),
        passwordHash: map['password_hash'] as String,
        salt: map['salt'] as String,
        active: (map['active'] as int? ?? 1) == 1,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  AppUser copyWith({
    int? id,
    String? username,
    String? fullName,
    UserRole? role,
    String? passwordHash,
    String? salt,
    bool? active,
    DateTime? createdAt,
  }) =>
      AppUser(
        id: id ?? this.id,
        username: username ?? this.username,
        fullName: fullName ?? this.fullName,
        role: role ?? this.role,
        passwordHash: passwordHash ?? this.passwordHash,
        salt: salt ?? this.salt,
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
      );
}
