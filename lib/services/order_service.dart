import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import '../database/database_helper.dart';
import '../models/order.dart';
import 'auth_service.dart';
import 'stock_service.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final _db = DatabaseHelper.instance;
  final _auth = AuthService.instance;

  Future<PurchaseOrder> createPurchaseOrder({
    required int supplierId,
    required int productId,
    required int quantity,
    double unitPrice = 0,
    String? notes,
  }) async {
    final number = await _db.nextOrderNumber('PO');
    final now = DateTime.now();
    final order = PurchaseOrder(
      number: number,
      supplierId: supplierId,
      status: OrderStatus.confirmed,
      notes: notes,
      agentId: _auth.currentAgentId,
      agentName: _auth.currentAgentName,
      orderDate: now,
      createdAt: now,
    );
    final id = await _db.insertPurchaseOrder(order);
    await _db.insertPurchaseOrderLine(PurchaseOrderLine(
      orderId: id,
      productId: productId,
      quantityOrdered: quantity,
      unitPrice: unitPrice,
    ));
    return order.copyWithId(id);
  }

  Future<void> receivePurchaseOrder(int orderId) async {
    final lines = await _db.getPurchaseOrderLines(orderId);
    for (final line in lines) {
      final remaining = line.quantityOrdered - line.quantityReceived;
      if (remaining <= 0) continue;
      await StockService.instance.addEntry(
        productId: line.productId,
        quantity: remaining,
        reference: 'PO#$orderId',
        notes: 'Réception commande achat',
      );
      await _db.updatePurchaseOrderLineReceived(
          line.id!, line.quantityOrdered);
    }
    await _db.updatePurchaseOrderStatus(orderId, OrderStatus.completed);
  }

  Future<SalesOrder> createSalesOrder({
    required int customerId,
    required int productId,
    required int quantity,
    double unitPrice = 0,
    String? notes,
  }) async {
    final number = await _db.nextOrderNumber('SO');
    final now = DateTime.now();
    final order = SalesOrder(
      number: number,
      customerId: customerId,
      status: OrderStatus.confirmed,
      notes: notes,
      agentId: _auth.currentAgentId,
      agentName: _auth.currentAgentName,
      orderDate: now,
      createdAt: now,
    );
    final id = await _db.insertSalesOrder(order);
    await _db.insertSalesOrderLine(SalesOrderLine(
      orderId: id,
      productId: productId,
      quantityOrdered: quantity,
      unitPrice: unitPrice,
    ));
    return order.copyWithId(id);
  }

  Future<void> shipSalesOrder(int orderId) async {
    final lines = await _db.getSalesOrderLines(orderId);
    for (final line in lines) {
      final remaining = line.quantityOrdered - line.quantityShipped;
      if (remaining <= 0) continue;
      await StockService.instance.addExit(
        productId: line.productId,
        quantity: remaining,
        reference: 'SO#$orderId',
        notes: 'Livraison commande vente',
      );
      await _db.updateSalesOrderLineShipped(line.id!, line.quantityOrdered);
    }
    await _db.updateSalesOrderStatus(orderId, OrderStatus.completed);
  }
}

extension on PurchaseOrder {
  PurchaseOrder copyWithId(int id) => PurchaseOrder(
        id: id,
        number: number,
        supplierId: supplierId,
        status: status,
        notes: notes,
        agentId: agentId,
        agentName: agentName,
        orderDate: orderDate,
        expectedDate: expectedDate,
        createdAt: createdAt,
        supplierName: supplierName,
        lines: lines,
      );
}

extension on SalesOrder {
  SalesOrder copyWithId(int id) => SalesOrder(
        id: id,
        number: number,
        customerId: customerId,
        status: status,
        notes: notes,
        agentId: agentId,
        agentName: agentName,
        orderDate: orderDate,
        createdAt: createdAt,
        customerName: customerName,
        lines: lines,
      );
}

class ExportService {
  ExportService._();
  static final ExportService instance = ExportService._();

  final _dateFormat = DateFormat('yyyyMMdd_HHmmss');

  Future<String> _defaultDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'STORA_Exports'));
    await dir.create(recursive: true);
    return dir.path;
  }

  String _csvCell(Object? value) {
    final raw =
        (value ?? '').toString().replaceAll('\r\n', ' ').replaceAll('\n', ' ');
    if (raw.contains(';') || raw.contains('"') || raw.contains(',')) {
      return '"${raw.replaceAll('"', '""')}"';
    }
    return raw;
  }

  String _csvLine(List<Object?> cells) => cells.map(_csvCell).join(';');

  /// Dialogue Enregistrer sous via PowerShell (compatible plein écran).
  /// Retourne null si annulé ; lance si le dialogue échoue complètement.
  Future<String?> _pickSavePathWindows({
    required String defaultDir,
    required String fileName,
  }) async {
    final initial = defaultDir.replaceAll("'", "''");
    final name = fileName.replaceAll("'", "''");
    final script = '''
Add-Type -AssemblyName System.Windows.Forms
[void][System.Windows.Forms.Application]::EnableVisualStyles()
\$owner = New-Object System.Windows.Forms.Form
\$owner.TopMost = \$true
\$owner.ShowInTaskbar = \$false
\$owner.FormBorderStyle = 'None'
\$owner.Opacity = 0
\$owner.Size = New-Object System.Drawing.Size(1, 1)
\$owner.StartPosition = 'Manual'
\$owner.Location = New-Object System.Drawing.Point(-10000, -10000)
\$owner.Show()
\$dialog = New-Object System.Windows.Forms.SaveFileDialog
\$dialog.Title = 'Enregistrer export CSV STORA'
\$dialog.Filter = 'CSV (*.csv)|*.csv|Tous (*.*)|*.*'
\$dialog.DefaultExt = 'csv'
\$dialog.AddExtension = \$true
\$dialog.OverwritePrompt = \$true
\$dialog.RestoreDirectory = \$true
\$dialog.InitialDirectory = '$initial'
\$dialog.FileName = '$name'
try {
  \$result = \$dialog.ShowDialog(\$owner)
  if (\$result -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Out.Write(\$dialog.FileName)
  } else {
    [Console]::Out.Write('__CANCELLED__')
  }
} finally {
  \$owner.Close()
  \$owner.Dispose()
}
''';

    try {
      final result = await Process.run(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        runInShell: false,
      );
      if (result.exitCode != 0) return null;
      final path = (result.stdout as String).trim();
      if (path.isEmpty) return null;
      if (path == '__CANCELLED__') return '';
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Écrit un CSV (BOM UTF-8 pour Excel).
  /// Retourne null si l'utilisateur annule le dialogue.
  Future<String?> _write(String basename, String content) async {
    final fileName =
        'stora_${basename}_${_dateFormat.format(DateTime.now())}.csv';
    final defaultDir = await _defaultDir();

    String? path;
    if (Platform.isWindows) {
      try {
        final picked = await _pickSavePathWindows(
          defaultDir: defaultDir,
          fileName: fileName,
        );
        if (picked == '') return null; // annulé
        path = (picked != null && picked.isNotEmpty) ? picked : null;
      } finally {
        try {
          await Future<void>.delayed(const Duration(milliseconds: 150));
          if (!await windowManager.isFullScreen()) {
            await windowManager.setFullScreen(true);
          }
          await windowManager.show();
          await windowManager.focus();
        } catch (_) {}
      }
    }

    // Fallback : écriture directe dans Documents/STORA_Exports
    path ??= p.join(defaultDir, fileName);
    if (!path.toLowerCase().endsWith('.csv')) {
      path = '$path.csv';
    }

    final file = File(path);
    await file.parent.create(recursive: true);

    final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(content)];
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<String?> exportProductsCsv() async {
    final products = await DatabaseHelper.instance.getProducts();
    final buf = StringBuffer();
    buf.writeln(_csvLine([
      'CODE',
      'NOM',
      'QUANTITE',
      'MIN',
      'UNITE',
      'PRIX_ACHAT',
      'PRIX_VENTE',
      'EMPLACEMENT',
    ]));
    for (final p in products) {
      buf.writeln(_csvLine([
        p.code,
        p.name,
        p.quantity,
        p.minStock,
        p.unit,
        p.purchasePrice,
        p.salePrice,
        p.location ?? '',
      ]));
    }
    return _write('produits', buf.toString());
  }

  Future<String?> exportMovementsCsv() async {
    final movements =
        await DatabaseHelper.instance.getMovements(limit: 5000);
    final products = await DatabaseHelper.instance.getProducts();
    final map = {
      for (final p in products)
        if (p.id != null) p.id!: p,
    };
    final buf = StringBuffer();
    buf.writeln(_csvLine([
      'DATE',
      'TYPE',
      'AGENT',
      'CODE',
      'PRODUIT',
      'QTE',
      'AVANT',
      'APRES',
      'REF',
      'LOT',
    ]));
    for (final m in movements) {
      final prod = map[m.productId];
      buf.writeln(_csvLine([
        m.createdAt.toIso8601String(),
        m.typeLabel,
        m.agentName,
        prod?.code ?? '',
        prod?.name ?? '',
        m.quantity,
        m.quantityBefore,
        m.quantityAfter,
        m.reference ?? '',
        m.lotNumber ?? '',
      ]));
    }
    return _write('mouvements', buf.toString());
  }

  Future<String?> exportCustomersCsv() async {
    final customers = await DatabaseHelper.instance.getCustomers();
    final buf = StringBuffer();
    buf.writeln(
        _csvLine(['CODE', 'NOM', 'CONTACT', 'TELEPHONE', 'EMAIL', 'VILLE']));
    for (final c in customers) {
      buf.writeln(_csvLine([
        c.code,
        c.name,
        c.contact ?? '',
        c.phone ?? '',
        c.email ?? '',
        c.city ?? '',
      ]));
    }
    return _write('clients', buf.toString());
  }

  Future<String?> exportWarehouseStockCsv() async {
    final rows = await DatabaseHelper.instance.getStockByWarehouse();
    final buf = StringBuffer();
    buf.writeln(_csvLine(['ENTREPOT', 'CODE', 'PRODUIT', 'QUANTITE']));
    for (final r in rows) {
      buf.writeln(_csvLine([
        r.warehouseCode ?? '',
        r.productCode ?? '',
        r.productName ?? '',
        r.quantity,
      ]));
    }
    return _write('stock_entrepots', buf.toString());
  }
}
