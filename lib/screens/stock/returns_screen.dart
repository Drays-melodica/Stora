import 'package:flutter/material.dart';

import '../../models/product.dart';
import '../../services/stock_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_menu.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class ReturnsScreen extends StatefulWidget {
  const ReturnsScreen({super.key});

  @override
  State<ReturnsScreen> createState() => _ReturnsScreenState();
}

class _ReturnsScreenState extends State<ReturnsScreen> {
  List<Product> _products = [];
  int? _selected;
  bool _customerReturn = true;

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
    try {
      Product product;
      if (_selected != null) {
        product = _products[_selected!];
      } else {
        product = _products.firstWhere(
            (p) => p.code == values['CODE PRODUIT']!.toUpperCase());
      }
      final qty = int.parse(values['QUANTITE']!);
      if (_customerReturn) {
        await StockService.instance.addReturnIn(
          productId: product.id!,
          quantity: qty,
          reference: values['REFERENCE'],
          notes: values['NOTES'],
        );
      } else {
        await StockService.instance.addReturnOut(
          productId: product.id!,
          quantity: qty,
          reference: values['REFERENCE'],
          notes: values['NOTES'],
        );
      }
      await DosDialog.success(context,
          title: 'Retour', message: 'Mouvement de retour enregistré.');
      _load();
    } catch (e) {
      await DosDialog.error(context, title: 'Erreur', message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'RETOURS',
      subtitle: _customerReturn
          ? 'Retour client (réintégration stock)'
          : 'Retour fournisseur (sortie stock)',
      captureKeyboard: false,
      helpLines: const [
        '1: Retour client | 2: Retour fournisseur | F10: Valider | ECHAP: Retour',
      ],
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: DosBox(
              title: 'TYPE DE RETOUR',
              child: DosMenu(
                key: ValueKey(_customerReturn),
                items: const [
                  'RETOUR CLIENT (+ stock)',
                  'RETOUR FOURNISSEUR (- stock)',
                ],
                selectedIndex: _customerReturn ? 0 : 1,
                onSelect: (i) => setState(() => _customerReturn = i == 0),
                onCancel: () => Navigator.pop(context),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: DosBox(
              title: 'PRODUITS',
              child: DosTable(
                headers: const ['CODE', 'NOM', 'STOCK'],
                rows: _products
                    .map((p) => [p.code, p.name, '${p.quantity}'])
                    .toList(),
                onSelect: (i) {
                  setState(() {
                    _selected = i;
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
              title: 'SAISIE',
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _customerReturn ? 'Mode: CLIENT' : 'Mode: FOURNISSEUR',
                      style: DosTheme.text(weight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    DosForm(
                      onCancel: () => Navigator.pop(context),
                      onSubmit: _submit,
                      fields: [
                        DosFormField(
                            label: 'CODE PRODUIT',
                            controller: _codeCtrl,
                            required: true),
                        DosFormField(
                            label: 'QUANTITE',
                            controller: _qtyCtrl,
                            required: true,
                            keyboardType: TextInputType.number),
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
