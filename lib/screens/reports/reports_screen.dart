import 'package:flutter/material.dart';

import '../../services/order_service.dart';
import '../../services/print_service.dart';
import '../../services/stock_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_menu.dart';
import '../../widgets/dos_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _items = [
    'IMPRIMER RAPPORT STOCK COMPLET',
    'IMPRIMER ALERTES STOCK BAS',
    'IMPRIMER JOURNAL DES MOUVEMENTS',
    'EXPORT CSV PRODUITS',
    'EXPORT CSV MOUVEMENTS',
    'EXPORT CSV CLIENTS',
    'EXPORT CSV STOCK ENTREPÔTS',
    'SUGGESTIONS DE RÉAPPROVISIONNEMENT',
  ];

  Future<void> _showCsvResult(String? path) async {
    if (!mounted) return;
    if (path == null) {
      await DosDialog.info(
        context,
        title: 'Export annulé',
        message: 'Aucun fichier n\'a été enregistré.',
      );
      return;
    }
    await DosDialog.info(
      context,
      title: 'Export CSV',
      message: 'Fichier enregistré:\n$path',
    );
  }

  Future<void> _onSelect(int index) async {
    try {
      switch (index) {
        case 0:
          await PrintService.instance.printStockReport();
          if (mounted) {
            await DosDialog.info(context,
                title: 'Impression', message: 'Dialogue d\'impression ouvert.');
          }
        case 1:
          final low = await StockService.instance.getLowStock();
          if (low.isEmpty) {
            if (mounted) {
              await DosDialog.info(context,
                  title: 'Alertes', message: 'Aucun produit en stock bas.');
            }
            return;
          }
          await PrintService.instance.printLowStockReport();
          if (mounted) {
            await DosDialog.info(context,
                title: 'Impression', message: 'Dialogue d\'impression ouvert.');
          }
        case 2:
          final movements =
              await StockService.instance.getRecentMovements(limit: 500);
          final products = await StockService.instance.getAllProducts();
          final map = {for (final p in products) p.id!: p};
          await PrintService.instance.printMovementsReport(movements, map);
          if (mounted) {
            await DosDialog.info(context,
                title: 'Impression', message: 'Dialogue d\'impression ouvert.');
          }
        case 3:
          await _showCsvResult(
              await ExportService.instance.exportProductsCsv());
        case 4:
          await _showCsvResult(
              await ExportService.instance.exportMovementsCsv());
        case 5:
          await _showCsvResult(
              await ExportService.instance.exportCustomersCsv());
        case 6:
          await _showCsvResult(
              await ExportService.instance.exportWarehouseStockCsv());
        case 7:
          final suggestions =
              await StockService.instance.getReorderSuggestions();
          if (!mounted) return;
          if (suggestions.isEmpty) {
            await DosDialog.info(context,
                title: 'Réappro', message: 'Aucun produit sous le seuil min.');
          } else {
            final lines = suggestions
                .map((p) =>
                    '${p.code} — ${p.name}: stock ${p.quantity} / min ${p.minStock} (à commander ${p.minStock - p.quantity + p.minStock})')
                .join('\n');
            await DosDialog.info(context,
                title: 'Suggestions réappro', message: lines);
          }
      }
    } catch (e) {
      if (mounted) {
        await DosDialog.error(context, title: 'Erreur', message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'RAPPORTS / EXPORT / IMPRESSION',
      subtitle:
          'PDF imprimables et exports CSV (Enregistrer sous / Documents\\STORA_Exports)',
      helpLines: const ['ENTREE: Lancer | ECHAP: Retour'],
      child: DosBox(
        title: 'OPTIONS',
        child: DosMenu(
          items: _items,
          onSelect: _onSelect,
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
