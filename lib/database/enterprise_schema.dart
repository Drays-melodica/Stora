import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Tables entreprise (v4) — clients, entrepôts, lots, commandes.
class EnterpriseSchema {
  EnterpriseSchema._();

  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        contact TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        city TEXT,
        credit_limit REAL NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        address TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS warehouse_stock (
        warehouse_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (warehouse_id, product_id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS product_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        warehouse_id INTEGER,
        lot_number TEXT NOT NULL,
        expiry_date TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL UNIQUE,
        supplier_id INTEGER,
        status TEXT NOT NULL DEFAULT 'draft',
        notes TEXT,
        agent_id INTEGER,
        agent_name TEXT NOT NULL,
        order_date TEXT NOT NULL,
        expected_date TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_order_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity_ordered INTEGER NOT NULL,
        quantity_received INTEGER NOT NULL DEFAULT 0,
        unit_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES purchase_orders(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        status TEXT NOT NULL DEFAULT 'draft',
        notes TEXT,
        agent_id INTEGER,
        agent_name TEXT NOT NULL,
        order_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (customer_id) REFERENCES customers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales_order_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity_ordered INTEGER NOT NULL,
        quantity_shipped INTEGER NOT NULL DEFAULT 0,
        unit_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (order_id) REFERENCES sales_orders(id),
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stock_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        number TEXT NOT NULL UNIQUE,
        product_id INTEGER NOT NULL,
        from_warehouse_id INTEGER NOT NULL,
        to_warehouse_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        notes TEXT,
        agent_id INTEGER,
        agent_name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (from_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (to_warehouse_id) REFERENCES warehouses(id)
      )
    ''');

    // Colonnes entrepôt / lot sur mouvements (si absentes)
    try {
      await db.execute(
          'ALTER TABLE stock_movements ADD COLUMN warehouse_id INTEGER');
    } catch (_) {}
    try {
      await db.execute('ALTER TABLE stock_movements ADD COLUMN lot_number TEXT');
    } catch (_) {}

    final now = DateTime.now().toIso8601String();
    final whCount = await db.rawQuery('SELECT COUNT(*) as c FROM warehouses');
    if ((whCount.first['c'] as int) == 0) {
      await db.insert('warehouses', {
        'code': 'PRINCIPAL',
        'name': 'ENTREPÔT PRINCIPAL',
        'is_default': 1,
        'active': 1,
        'created_at': now,
      });
    }
  }
}
