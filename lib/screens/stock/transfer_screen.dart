import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../models/warehouse.dart';
import '../../services/stock_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  List<Product> _products = [];
  List<Warehouse> _warehouses = [];
  List<Map<String, dynamic>> _history = [];
  int? _selectedProduct;

  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await StockService.instance.getAllProducts();
    final warehouses = await DatabaseHelper.instance.getWarehouses();
    final history = await DatabaseHelper.instance.getTransfers();
    setState(() {
      _products = products;
      _warehouses = warehouses;
      _history = history;
      if (warehouses.length >= 2) {
        _fromCtrl.text = '${warehouses[0].id}';
        _toCtrl.text = '${warehouses[1].id}';
      } else if (warehouses.isNotEmpty) {
        _fromCtrl.text = '${warehouses.first.id}';
      }
    });
  }

  Future<void> _submit(Map<String, String> values) async {
    if (_selectedProduct == null) {
      await DosDialog.error(context,
          title: 'Erreur', message: 'Sélectionnez un produit.');
      return;
    }
    try {
      await StockService.instance.transferStock(
        productId: _products[_selectedProduct!].id!,
        fromWarehouseId: int.parse(values['ID ENTREPOT SOURCE']!),
        toWarehouseId: int.parse(values['ID ENTREPOT DEST']!),
        quantity: int.parse(values['QUANTITE']!),
        notes: values['NOTES'],
      );
      await DosDialog.success(context,
          title: 'Transfert', message: 'Transfert enregistré.');
      _load();
    } catch (e) {
      await DosDialog.error(context, title: 'Erreur', message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final whHelp = _warehouses.map((w) => '${w.id}:${w.code}').join(' | ');
    return DosScreen(
      title: 'TRANSFERT INTER-ENTREPÔTS',
      subtitle: whHelp,
      captureKeyboard: false,
      helpLines: const [
        'ENTREE: Sélectionner produit | F10: Transférer | ECHAP: Retour',
      ],
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DosBox(
              title: 'PRODUITS / HISTORIQUE',
              child: Column(
                children: [
                  Expanded(
                    child: DosTable(
                      headers: const ['CODE', 'NOM', 'STOCK'],
                      rows: _products
                          .map((p) => [p.code, p.name, '${p.quantity}'])
                          .toList(),
                      onSelect: (i) => setState(() => _selectedProduct = i),
                      onCancel: () => Navigator.pop(context),
                    ),
                  ),
                  Text('Derniers transferts: ${_history.length}',
                      style: DosTheme.dim(size: 12)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DosBox(
              title: 'SAISIE TRANSFERT',
              child: SingleChildScrollView(
                child: DosForm(
                  onCancel: () => Navigator.pop(context),
                  onSubmit: _submit,
                  fields: [
                    DosFormField(
                        label: 'ID ENTREPOT SOURCE',
                        controller: _fromCtrl,
                        required: true,
                        keyboardType: TextInputType.number),
                    DosFormField(
                        label: 'ID ENTREPOT DEST',
                        controller: _toCtrl,
                        required: true,
                        keyboardType: TextInputType.number),
                    DosFormField(
                        label: 'QUANTITE',
                        controller: _qtyCtrl,
                        required: true,
                        keyboardType: TextInputType.number),
                    DosFormField(label: 'NOTES', controller: _notesCtrl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
