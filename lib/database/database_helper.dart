import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/app_user.dart';
import '../models/category.dart';
import '../models/company_profile.dart';
import '../models/customer.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/product_batch.dart';
import '../models/stock_movement.dart';
import '../models/supplier.dart';
import '../models/warehouse.dart';
import 'enterprise_schema.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _init();
    return _db!;
  }

  Future<Database> _init() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'stora', 'stora.db');
    await Directory(p.dirname(dbPath)).create(recursive: true);

    return openDatabase(
      dbPath,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createUsersTable(db);
    await _createCoreTables(db);
    await _createCompanySettingsTable(db);
    await EnterpriseSchema.createTables(db);
    await _seedDemoData(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createUsersTable(db);
      await db.execute(
          "ALTER TABLE stock_movements ADD COLUMN agent_id INTEGER");
      await db.execute(
          "ALTER TABLE stock_movements ADD COLUMN agent_name TEXT NOT NULL DEFAULT 'INCONNU'");
    }
    if (oldVersion < 3) {
      await _createCompanySettingsTable(db);
    }
    if (oldVersion < 4) {
      await EnterpriseSchema.createTables(db);
      await _migrateWarehouseStock(db);
    }
  }

  Future<void> _migrateWarehouseStock(Database db) async {
    final warehouses = await db.query('warehouses', where: 'is_default = 1');
    if (warehouses.isEmpty) return;
    final whId = warehouses.first['id'] as int;
    final products = await db.query('products');
    for (final p in products) {
      final qty = p['quantity'] as int? ?? 0;
      if (qty <= 0) continue;
      await db.insert(
        'warehouse_stock',
        {
          'warehouse_id': whId,
          'product_id': p['id'],
          'quantity': qty,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _createCompanySettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS company_settings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        company_name TEXT NOT NULL DEFAULT '',
        address TEXT,
        city TEXT,
        phone TEXT,
        email TEXT,
        tax_id TEXT,
        website TEXT,
        logo_path TEXT,
        updated_at TEXT NOT NULL
      )
    ''');

    final rows =
        await db.rawQuery('SELECT COUNT(*) as c FROM company_settings');
    final count = rows.first['c'] as int;
    if (count == 0) {
      await db.insert('company_settings', {
        'id': 1,
        'company_name': '',
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  Future<void> _createUsersTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        role TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_users_username ON users(username)');
  }

  Future<void> _createCoreTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        contact TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        category_id INTEGER,
        supplier_id INTEGER,
        unit TEXT NOT NULL DEFAULT 'UN',
        purchase_price REAL NOT NULL DEFAULT 0,
        sale_price REAL NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER NOT NULL DEFAULT 0,
        location TEXT,
        description TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        quantity_before INTEGER NOT NULL,
        quantity_after INTEGER NOT NULL,
        reference TEXT,
        notes TEXT,
        agent_id INTEGER,
        agent_name TEXT NOT NULL DEFAULT 'INCONNU',
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (agent_id) REFERENCES users(id)
      )
    ''');

    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_code ON products(code)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_movements_product ON stock_movements(product_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_movements_date ON stock_movements(created_at)');
  }

  Future<void> _seedDemoData(Database db) async {
    final now = DateTime.now().toIso8601String();
    await db.insert('categories', {
      'name': 'GENERAL',
      'description': 'Catégorie par défaut',
      'created_at': now,
    });
    await db.insert('suppliers', {
      'name': 'FOURNISSEUR DEMO',
      'contact': 'Service achats',
      'phone': '0000000000',
      'created_at': now,
    });
  }

  // --- Users ---
  Future<bool> hasUsers() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as c FROM users');
    return (result.first['c'] as int) > 0;
  }

  Future<bool> hasAdmin() async {
    final db = await database;
    final result = await db.rawQuery(
        "SELECT COUNT(*) as c FROM users WHERE role = 'admin'");
    return (result.first['c'] as int) > 0;
  }

  Future<int> insertUser(AppUser user) async {
    final db = await database;
    return db.insert('users', user.toMap());
  }

  Future<AppUser?> getUserByUsername(String username) async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );
    if (rows.isEmpty) return null;
    return AppUser.fromMap(rows.first);
  }

  Future<List<AppUser>> getAgents() async {
    final db = await database;
    final rows = await db.query(
      'users',
      where: "role = 'agent'",
      orderBy: 'full_name ASC',
    );
    return rows.map(AppUser.fromMap).toList();
  }

  Future<List<AppUser>> getAllUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'role ASC, full_name ASC');
    return rows.map(AppUser.fromMap).toList();
  }

  Future<int> setUserActive(int id, bool active) async {
    final db = await database;
    return db.update('users', {'active': active ? 1 : 0},
        where: 'id = ?', whereArgs: [id]);
  }

  // --- Company settings ---
  Future<CompanyProfile> getCompanyProfile() async {
    final db = await database;
    final rows = await db.query('company_settings', where: 'id = 1');
    if (rows.isEmpty) {
      return CompanyProfile(updatedAt: DateTime.now());
    }
    return CompanyProfile.fromMap(rows.first);
  }

  Future<void> saveCompanyProfile(CompanyProfile profile) async {
    final db = await database;
    final data = profile.toMap();
    final existing = await db.query('company_settings', where: 'id = 1');
    if (existing.isEmpty) {
      await db.insert('company_settings', data);
    } else {
      await db.update('company_settings', data, where: 'id = 1');
    }
  }

  // --- Categories ---
  Future<List<Category>> getCategories() async {
    final db = await database;
    final rows = await db.query('categories', orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    return db.insert('categories', category.toMap());
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    return db.update('categories', category.toMap(),
        where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // --- Suppliers ---
  Future<List<Supplier>> getSuppliers() async {
    final db = await database;
    final rows = await db.query('suppliers', orderBy: 'name ASC');
    return rows.map(Supplier.fromMap).toList();
  }

  Future<int> insertSupplier(Supplier supplier) async {
    final db = await database;
    return db.insert('suppliers', supplier.toMap());
  }

  Future<int> updateSupplier(Supplier supplier) async {
    final db = await database;
    return db.update('suppliers', supplier.toMap(),
        where: 'id = ?', whereArgs: [supplier.id]);
  }

  Future<int> deleteSupplier(int id) async {
    final db = await database;
    return db.delete('suppliers', where: 'id = ?', whereArgs: [id]);
  }

  // --- Products ---
  Future<List<Product>> getProducts({String? search}) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (search != null && search.isNotEmpty) {
      rows = await db.query(
        'products',
        where: 'code LIKE ? OR name LIKE ?',
        whereArgs: ['%$search%', '%$search%'],
        orderBy: 'name ASC',
      );
    } else {
      rows = await db.query('products', orderBy: 'name ASC');
    }
    return rows.map(Product.fromMap).toList();
  }

  Future<Product?> getProductById(int id) async {
    final db = await database;
    final rows =
        await db.query('products', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<Product?> getProductByCode(String code) async {
    final db = await database;
    final rows =
        await db.query('products', where: 'code = ?', whereArgs: [code]);
    if (rows.isEmpty) return null;
    return Product.fromMap(rows.first);
  }

  Future<int> insertProduct(Product product) async {
    final db = await database;
    return db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await database;
    return db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Product>> getLowStockProducts() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT * FROM products WHERE quantity <= min_stock ORDER BY quantity ASC');
    return rows.map(Product.fromMap).toList();
  }

  // --- Movements ---
  Future<List<StockMovement>> getMovements({int? productId, int? limit}) async {
    final db = await database;
    final rows = await db.query(
      'stock_movements',
      where: productId != null ? 'product_id = ?' : null,
      whereArgs: productId != null ? [productId] : null,
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(StockMovement.fromMap).toList();
  }

  Future<int> insertMovement(StockMovement movement) async {
    final db = await database;
    return db.insert('stock_movements', movement.toMap());
  }

  Future<Map<String, dynamic>> getStockSummary() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT
        COUNT(*) as total_products,
        COALESCE(SUM(quantity), 0) as total_quantity,
        COALESCE(SUM(quantity * purchase_price), 0) as total_value,
        COALESCE(SUM(quantity * sale_price), 0) as total_sale_value,
        SUM(CASE WHEN quantity <= min_stock THEN 1 ELSE 0 END) as low_stock_count,
        SUM(CASE WHEN quantity = 0 THEN 1 ELSE 0 END) as out_of_stock_count
      FROM products
    ''');
    return result.first;
  }

  Future<String> getDatabasePath() async {
    final dir = await getApplicationSupportDirectory();
    return p.join(dir.path, 'stora', 'stora.db');
  }

  /// True si un fichier de base existe déjà (installation précédente).
  Future<bool> databaseFileExists() async {
    final path = await getDatabasePath();
    final file = File(path);
    if (!await file.exists()) return false;
    final len = await file.length();
    return len > 0;
  }

  /// Installe une sauvegarde avant la première ouverture (ou remplace).
  Future<void> installFromBackupFile(String backupPath) async {
    final backup = File(backupPath);
    if (!await backup.exists()) {
      throw Exception('Fichier de sauvegarde introuvable.');
    }
    if (await backup.length() < 100) {
      throw Exception('Fichier de sauvegarde invalide ou vide.');
    }

    final dest = await getDatabasePath();
    await Directory(p.dirname(dest)).create(recursive: true);
    await closeDatabase();

    final wal = File('$dest-wal');
    final shm = File('$dest-shm');
    if (await wal.exists()) await wal.delete();
    if (await shm.exists()) await shm.delete();

    await backup.copy(dest);
    await database;
  }

  /// Ferme la connexion (sauvegarde / restauration).
  Future<void> closeDatabase() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }

  // --- Customers ---
  Future<String> nextCustomerCode() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT code FROM customers WHERE code LIKE ? ORDER BY code DESC LIMIT 1',
        ['CLI-%']);
    var next = 1;
    if (rows.isNotEmpty) {
      final last = rows.first['code'] as String? ?? '';
      final match = RegExp(r'CLI-(\d+)$').firstMatch(last);
      if (match != null) {
        next = (int.tryParse(match.group(1)!) ?? 0) + 1;
      }
    } else {
      final count =
          await db.rawQuery('SELECT COUNT(*) as c FROM customers');
      next = (count.first['c'] as int) + 1;
    }
    return 'CLI-${next.toString().padLeft(4, '0')}';
  }

  Future<List<Customer>> getCustomers({String? search}) async {
    final db = await database;
    if (search != null && search.isNotEmpty) {
      final rows = await db.query(
        'customers',
        where: 'code LIKE ? OR name LIKE ?',
        whereArgs: ['%$search%', '%$search%'],
        orderBy: 'name ASC',
      );
      return rows.map(Customer.fromMap).toList();
    }
    final rows = await db.query('customers', orderBy: 'name ASC');
    return rows.map(Customer.fromMap).toList();
  }

  Future<int> insertCustomer(Customer c) async {
    final db = await database;
    return db.insert('customers', c.toMap());
  }

  Future<int> updateCustomer(Customer c) async {
    final db = await database;
    return db.update('customers', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return db.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<Customer?> getCustomerById(int id) async {
    final db = await database;
    final rows = await db.query('customers', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Customer.fromMap(rows.first);
  }

  // --- Warehouses ---
  Future<List<Warehouse>> getWarehouses({bool activeOnly = true}) async {
    final db = await database;
    final rows = await db.query(
      'warehouses',
      where: activeOnly ? 'active = 1' : null,
      orderBy: 'is_default DESC, name ASC',
    );
    return rows.map(Warehouse.fromMap).toList();
  }

  Future<Warehouse?> getDefaultWarehouse() async {
    final db = await database;
    final rows =
        await db.query('warehouses', where: 'is_default = 1', limit: 1);
    if (rows.isEmpty) {
      final all = await db.query('warehouses', limit: 1);
      if (all.isEmpty) return null;
      return Warehouse.fromMap(all.first);
    }
    return Warehouse.fromMap(rows.first);
  }

  Future<int> insertWarehouse(Warehouse w) async {
    final db = await database;
    if (w.isDefault) {
      await db.update('warehouses', {'is_default': 0});
    }
    return db.insert('warehouses', w.toMap());
  }

  Future<int> updateWarehouse(Warehouse w) async {
    final db = await database;
    if (w.isDefault) {
      await db.update('warehouses', {'is_default': 0});
    }
    return db.update('warehouses', w.toMap(), where: 'id = ?', whereArgs: [w.id]);
  }

  Future<int> getWarehouseStock(int warehouseId, int productId) async {
    final db = await database;
    final rows = await db.query(
      'warehouse_stock',
      where: 'warehouse_id = ? AND product_id = ?',
      whereArgs: [warehouseId, productId],
    );
    if (rows.isEmpty) return 0;
    return rows.first['quantity'] as int? ?? 0;
  }

  Future<void> setWarehouseStock(
      int warehouseId, int productId, int quantity) async {
    final db = await database;
    await db.insert(
      'warehouse_stock',
      {
        'warehouse_id': warehouseId,
        'product_id': productId,
        'quantity': quantity,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<WarehouseStock>> getStockByWarehouse({int? warehouseId}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT ws.warehouse_id, ws.product_id, ws.quantity,
             w.code as warehouse_code, w.name as warehouse_name,
             p.code as product_code, p.name as product_name
      FROM warehouse_stock ws
      JOIN warehouses w ON w.id = ws.warehouse_id
      JOIN products p ON p.id = ws.product_id
      WHERE ws.quantity > 0
      ${warehouseId != null ? 'AND ws.warehouse_id = ?' : ''}
      ORDER BY w.name, p.name
    ''', warehouseId != null ? [warehouseId] : null);
    return rows.map(WarehouseStock.fromMap).toList();
  }

  // --- Batches ---
  Future<List<ProductBatch>> getBatches({bool expiringOnly = false}) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT b.*, p.code as product_code, p.name as product_name
      FROM product_batches b
      JOIN products p ON p.id = b.product_id
      WHERE b.quantity > 0
      ${expiringOnly ? "AND b.expiry_date IS NOT NULL AND date(b.expiry_date) <= date('now', '+30 days')" : ''}
      ORDER BY (b.expiry_date IS NULL), b.expiry_date ASC, b.lot_number
    ''');
    return rows.map(ProductBatch.fromMap).toList();
  }

  Future<int> insertBatch(ProductBatch batch) async {
    final db = await database;
    return db.insert('product_batches', batch.toMap());
  }

  Future<int> updateBatch(ProductBatch batch) async {
    final db = await database;
    return db.update('product_batches', batch.toMap(),
        where: 'id = ?', whereArgs: [batch.id]);
  }

  // --- Purchase orders ---
  Future<String> nextOrderNumber(String prefix) async {
    final db = await database;
    final table =
        prefix == 'PO' ? 'purchase_orders' : 'sales_orders';
    final count =
        await db.rawQuery('SELECT COUNT(*) as c FROM $table');
    final n = (count.first['c'] as int) + 1;
    final date = DateTime.now();
    return '$prefix-${date.year}${date.month.toString().padLeft(2, '0')}-${n.toString().padLeft(4, '0')}';
  }

  Future<List<PurchaseOrder>> getPurchaseOrders() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT po.*, s.name as supplier_name
      FROM purchase_orders po
      LEFT JOIN suppliers s ON s.id = po.supplier_id
      ORDER BY po.created_at DESC
    ''');
    return rows.map(PurchaseOrder.fromMap).toList();
  }

  Future<List<PurchaseOrderLine>> getPurchaseOrderLines(int orderId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT l.*, p.code as product_code, p.name as product_name
      FROM purchase_order_lines l
      JOIN products p ON p.id = l.product_id
      WHERE l.order_id = ?
    ''', [orderId]);
    return rows.map(PurchaseOrderLine.fromMap).toList();
  }

  Future<int> insertPurchaseOrder(PurchaseOrder order) async {
    final db = await database;
    return db.insert('purchase_orders', order.toMap());
  }

  Future<int> insertPurchaseOrderLine(PurchaseOrderLine line) async {
    final db = await database;
    return db.insert('purchase_order_lines', line.toMap());
  }

  Future<void> updatePurchaseOrderStatus(int id, OrderStatus status) async {
    final db = await database;
    await db.update('purchase_orders', {'status': status.name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePurchaseOrderLineReceived(int lineId, int received) async {
    final db = await database;
    await db.update('purchase_order_lines', {'quantity_received': received},
        where: 'id = ?', whereArgs: [lineId]);
  }

  // --- Sales orders ---
  Future<List<SalesOrder>> getSalesOrders() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT so.*, c.name as customer_name
      FROM sales_orders so
      LEFT JOIN customers c ON c.id = so.customer_id
      ORDER BY so.created_at DESC
    ''');
    return rows.map(SalesOrder.fromMap).toList();
  }

  Future<List<SalesOrderLine>> getSalesOrderLines(int orderId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT l.*, p.code as product_code, p.name as product_name
      FROM sales_order_lines l
      JOIN products p ON p.id = l.product_id
      WHERE l.order_id = ?
    ''', [orderId]);
    return rows.map(SalesOrderLine.fromMap).toList();
  }

  Future<int> insertSalesOrder(SalesOrder order) async {
    final db = await database;
    return db.insert('sales_orders', order.toMap());
  }

  Future<int> insertSalesOrderLine(SalesOrderLine line) async {
    final db = await database;
    return db.insert('sales_order_lines', line.toMap());
  }

  Future<void> updateSalesOrderStatus(int id, OrderStatus status) async {
    final db = await database;
    await db.update('sales_orders', {'status': status.name},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateSalesOrderLineShipped(int lineId, int shipped) async {
    final db = await database;
    await db.update('sales_order_lines', {'quantity_shipped': shipped},
        where: 'id = ?', whereArgs: [lineId]);
  }

  Future<int> insertTransfer(Map<String, dynamic> data) async {
    final db = await database;
    return db.insert('stock_transfers', data);
  }

  Future<List<Map<String, dynamic>>> getTransfers({int limit = 100}) async {
    final db = await database;
    return db.rawQuery('''
      SELECT t.*, p.code as product_code, p.name as product_name,
             wf.code as from_code, wt.code as to_code
      FROM stock_transfers t
      JOIN products p ON p.id = t.product_id
      JOIN warehouses wf ON wf.id = t.from_warehouse_id
      JOIN warehouses wt ON wt.id = t.to_warehouse_id
      ORDER BY t.created_at DESC
      LIMIT ?
    ''', [limit]);
  }

  Future<Map<String, dynamic>> getEnterpriseKpis() async {
    final db = await database;
    final summary = await getStockSummary();
    final customers =
        await db.rawQuery('SELECT COUNT(*) as c FROM customers');
    final openPo = await db.rawQuery(
        "SELECT COUNT(*) as c FROM purchase_orders WHERE status IN ('draft','confirmed','partial')");
    final openSo = await db.rawQuery(
        "SELECT COUNT(*) as c FROM sales_orders WHERE status IN ('draft','confirmed','partial')");
    final expiring = await db.rawQuery('''
      SELECT COUNT(*) as c FROM product_batches
      WHERE quantity > 0 AND expiry_date IS NOT NULL
        AND date(expiry_date) <= date('now', '+30 days')
    ''');
    final warehouses =
        await db.rawQuery('SELECT COUNT(*) as c FROM warehouses WHERE active = 1');

    return {
      ...summary,
      'customers_count': customers.first['c'],
      'open_po': openPo.first['c'],
      'open_so': openSo.first['c'],
      'expiring_lots': expiring.first['c'],
      'warehouses_count': warehouses.first['c'],
    };
  }
}
