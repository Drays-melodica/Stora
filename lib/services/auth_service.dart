import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../database/database_helper.dart';
import '../models/app_user.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final _db = DatabaseHelper.instance;
  AppUser? _currentUser;

  AppUser? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt$password');
    return sha256.convert(bytes).toString();
  }

  Future<bool> hasAnyUser() => _db.hasUsers();

  Future<bool> hasAdmin() => _db.hasAdmin();

  Future<AppUser> createAdmin({
    required String username,
    required String fullName,
    required String password,
  }) async {
    if (await _db.hasAdmin()) {
      throw Exception('Un administrateur existe déjà.');
    }
    if (password.length < 4) {
      throw Exception('Mot de passe trop court (min. 4 caractères).');
    }

    final salt = _generateSalt();
    final user = AppUser(
      username: username.trim().toLowerCase(),
      fullName: fullName.trim().toUpperCase(),
      role: UserRole.admin,
      passwordHash: _hashPassword(password, salt),
      salt: salt,
      createdAt: DateTime.now(),
    );

    final id = await _db.insertUser(user);
    _currentUser = user.copyWith(id: id);
    return _currentUser!;
  }

  Future<AppUser> createAgent({
    required String username,
    required String fullName,
    required String password,
  }) async {
    if (!isAdmin) {
      throw Exception('Seul un administrateur peut créer des agents.');
    }
    if (password.length < 4) {
      throw Exception('Mot de passe trop court (min. 4 caractères).');
    }

    final existing = await _db.getUserByUsername(username.trim().toLowerCase());
    if (existing != null) {
      throw Exception('Nom d\'utilisateur déjà utilisé.');
    }

    final salt = _generateSalt();
    final user = AppUser(
      username: username.trim().toLowerCase(),
      fullName: fullName.trim().toUpperCase(),
      role: UserRole.agent,
      passwordHash: _hashPassword(password, salt),
      salt: salt,
      createdAt: DateTime.now(),
    );

    final id = await _db.insertUser(user);
    return user.copyWith(id: id);
  }

  Future<AppUser> login(String username, String password) async {
    final user = await _db.getUserByUsername(username.trim().toLowerCase());
    if (user == null || !user.active) {
      throw Exception('Identifiants incorrects.');
    }

    final hash = _hashPassword(password, user.salt);
    if (hash != user.passwordHash) {
      throw Exception('Identifiants incorrects.');
    }

    _currentUser = user;
    return user;
  }

  void logout() {
    _currentUser = null;
  }

  String get currentAgentName =>
      _currentUser?.fullName ?? _currentUser?.username ?? 'INCONNU';

  int? get currentAgentId => _currentUser?.id;
}
