import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/stock_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Product> _products = [];
  int? _selectedIndex;
  final _newQtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newQtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await StockService.instance.getAllProducts();
    setState(() => _products = products);
  }

  Future<void> _adjust(Map<String, String> values) async {
    if (_selectedIndex == null) {
      await DosDialog.error(
        context,
        title: 'Erreur',
        message: 'Sélectionnez un produit.',
      );
      return;
    }

    final newQty = int.tryParse(values['NOUVELLE QUANTITE'] ?? '');
    if (newQty == null || newQty < 0) {
      await DosDialog.error(
        context,
        title: 'Erreur',
        message: 'Quantité invalide.',
      );
      return;
    }

    try {
      final product = _products[_selectedIndex!];
      await StockService.instance.adjustStock(
        productId: product.id!,
        newQuantity: newQty,
        notes: values['NOTES'],
      );
      if (mounted) {
        await DosDialog.success(
          context,
          title: 'Inventaire',
          message:
              'Stock ajusté: ${product.name}\nAncien: ${product.quantity} → Nouveau: $newQty',
        );
        _newQtyCtrl.clear();
        _notesCtrl.clear();
        setState(() => _selectedIndex = null);
        _load();
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
      title: 'INVENTAIRE / AJUSTEMENT',
      captureKeyboard: false,
      subtitle: 'Corriger les quantités après comptage physique',
      helpLines: const [
        'ENTREE: Sélectionner | F10: Appliquer ajustement | ECHAP: Retour',
      ],
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DosBox(
              title: 'PRODUITS',
              child: DosTable(
                headers: const ['CODE', 'NOM', 'STOCK ACTUEL', 'MIN'],
                rows: _products
                    .map((p) => [
                          p.code,
                          p.name,
                          '${p.quantity}',
                          '${p.minStock}',
                        ])
                    .toList(),
                onSelect: (i) {
                  setState(() {
                    _selectedIndex = i;
                    _newQtyCtrl.text = '${_products[i].quantity}';
                  });
                },
                onCancel: () => Navigator.pop(context),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DosBox(
              title: 'AJUSTEMENT',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedIndex != null) ...[
                    Text(
                      'Produit: ${_products[_selectedIndex!].name}',
                      style: DosTheme.text(weight: FontWeight.bold),
                    ),
                    Text(
                      'Stock système: ${_products[_selectedIndex!].quantity}',
                      style: DosTheme.dim(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DosForm(
                    onCancel: () => Navigator.pop(context),
                    onSubmit: _adjust,
                    fields: [
                      DosFormField(
                        label: 'NOUVELLE QUANTITE',
                        controller: _newQtyCtrl,
                        required: true,
                        keyboardType: TextInputType.number,
                      ),
                      DosFormField(label: 'NOTES', controller: _notesCtrl),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
