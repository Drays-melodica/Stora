import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/stock_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class StockExitScreen extends StatefulWidget {
  const StockExitScreen({super.key});

  @override
  State<StockExitScreen> createState() => _StockExitScreenState();
}

class _StockExitScreenState extends State<StockExitScreen> {
  List<Product> _products = [];
  int? _selectedProductIndex;

  final _codeCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _refCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _qtyCtrl.dispose();
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await StockService.instance.getAllProducts();
    setState(() => _products = products);
  }

  Future<void> _submit(Map<String, String> values) async {
    if (_selectedProductIndex == null) {
      final code = values['CODE PRODUIT']?.trim().toUpperCase();
      final idx = _products.indexWhere((p) => p.code == code);
      if (idx < 0) {
        await DosDialog.error(
          context,
          title: 'Erreur',
          message: 'Produit introuvable.',
        );
        return;
      }
      setState(() => _selectedProductIndex = idx);
    }

    final qty = int.tryParse(values['QUANTITE'] ?? '');
    if (qty == null || qty <= 0) {
      await DosDialog.error(
        context,
        title: 'Erreur',
        message: 'Quantité invalide.',
      );
      return;
    }

    try {
      final product = _products[_selectedProductIndex!];
      await StockService.instance.addExit(
        productId: product.id!,
        quantity: qty,
        reference: values['REFERENCE'],
        notes: values['NOTES'],
      );
      if (mounted) {
        await DosDialog.success(
          context,
          title: 'Succès',
          message:
              'Sortie enregistrée: -$qty ${product.unit} pour ${product.name}',
        );
        _qtyCtrl.text = '1';
        _refCtrl.clear();
        _notesCtrl.clear();
        setState(() => _selectedProductIndex = null);
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
      title: 'SORTIE DE STOCK',
      captureKeyboard: false,
      subtitle: 'Enregistrer une sortie / consommation',
      helpLines: const [
        'ENTREE: Sélectionner produit | F10: Valider sortie | ECHAP: Retour',
      ],
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DosBox(
              title: 'PRODUITS',
              child: DosTable(
                headers: const ['CODE', 'NOM', 'STOCK'],
                rows: _products
                    .map((p) => [p.code, p.name, '${p.quantity} ${p.unit}'])
                    .toList(),
                onSelect: (i) {
                  setState(() {
                    _selectedProductIndex = i;
                    _codeCtrl.text = _products[i].code;
                  });
                },
                onCancel: () => Navigator.pop(context),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DosBox(
              title: 'SAISIE SORTIE',
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_selectedProductIndex != null)
                      Text(
                        'Stock actuel: ${_products[_selectedProductIndex!].quantity}',
                        style: DosTheme.text(weight: FontWeight.bold),
                      )
                    else
                      Text('Aucun produit sélectionné', style: DosTheme.dim()),
                    const SizedBox(height: 12),
                    DosForm(
                      onCancel: () => Navigator.pop(context),
                      onSubmit: _submit,
                      fields: [
                        DosFormField(
                          label: 'CODE PRODUIT',
                          controller: _codeCtrl,
                          required: true,
                        ),
                        DosFormField(
                          label: 'QUANTITE',
                          controller: _qtyCtrl,
                          required: true,
                          keyboardType: TextInputType.number,
                        ),
                        DosFormField(label: 'REFERENCE', controller: _refCtrl),
                        DosFormField(label: 'NOTES', controller: _notesCtrl),
                      ],
                    ),
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
