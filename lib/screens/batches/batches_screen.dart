import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../models/product_batch.dart';
import '../../services/stock_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class BatchesScreen extends StatefulWidget {
  const BatchesScreen({super.key});

  @override
  State<BatchesScreen> createState() => _BatchesScreenState();
}

class _BatchesScreenState extends State<BatchesScreen> {
  List<ProductBatch> _batches = [];
  bool _expiringOnly = false;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final batches =
        await DatabaseHelper.instance.getBatches(expiringOnly: _expiringOnly);
    setState(() => _batches = batches);
  }

  Future<void> _addLot() async {
    final products = await StockService.instance.getAllProducts();
    if (products.isEmpty) {
      await DosDialog.error(context,
          title: 'Erreur', message: 'Aucun produit.');
      return;
    }
    final code = TextEditingController(text: products.first.code);
    final lot = TextEditingController();
    final qty = TextEditingController(text: '1');
    final expiry = TextEditingController();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DosScreen(
          title: 'ENTRÉE AVEC LOT',
          captureKeyboard: false,
          helpLines: const [
            'Date péremption: JJ/MM/AAAA | F10: Valider | ECHAP: Annuler',
          ],
          child: DosBox(
            title: 'LOT / PÉREMPTION',
            child: DosForm(
              onCancel: () => Navigator.pop(ctx),
              onSubmit: (values) async {
                try {
                  final product = products.firstWhere(
                      (p) => p.code == values['CODE PRODUIT']!.toUpperCase());
                  DateTime? exp;
                  final expStr = values['DATE PEREMPTION']?.trim() ?? '';
                  if (expStr.isNotEmpty) {
                    exp = DateFormat('dd/MM/yyyy').parseStrict(expStr);
                  }
                  await StockService.instance.addEntry(
                    productId: product.id!,
                    quantity: int.parse(values['QUANTITE']!),
                    lotNumber: values['N LOT'],
                    expiryDate: exp,
                    notes: 'Entrée lot',
                  );
                  if (ctx.mounted) {
                    await DosDialog.success(ctx,
                        title: 'OK', message: 'Lot enregistré.');
                    Navigator.pop(ctx);
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    await DosDialog.error(
                        ctx, title: 'Erreur', message: e.toString());
                  }
                }
              },
              fields: [
                DosFormField(
                    label: 'CODE PRODUIT', controller: code, required: true),
                DosFormField(
                    label: 'N LOT', controller: lot, required: true),
                DosFormField(
                    label: 'QUANTITE',
                    controller: qty,
                    required: true,
                    keyboardType: TextInputType.number),
                DosFormField(label: 'DATE PEREMPTION', controller: expiry),
              ],
            ),
          ),
        ),
      ),
    );
    code.dispose();
    lot.dispose();
    qty.dispose();
    expiry.dispose();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'LOTS / PÉREMPTION',
      subtitle: _expiringOnly
          ? 'Lots expirés ou < 30 jours'
          : '${_batches.length} lot(s)',
      helpLines: const [
        'F2: Entrée avec lot | F3: Filtrer alertes | ECHAP: Retour',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f2:
            _addLot();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f3:
            setState(() => _expiringOnly = !_expiringOnly);
            _load();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: DosBox(
        title: 'LOTS',
        child: DosTable(
          headers: const ['LOT', 'CODE', 'PRODUIT', 'QTÉ', 'PÉREMPTION', 'ALERTE'],
          rows: _batches.map((b) {
            String alert = '';
            if (b.isExpired) {
              alert = 'EXPIRÉ';
            } else if (b.isExpiringSoon) {
              alert = 'BIENTÔT';
            }
            return [
              b.lotNumber,
              b.productCode ?? '',
              b.productName ?? '',
              '${b.quantity}',
              b.expiryDate != null ? _dateFormat.format(b.expiryDate!) : '-',
              alert,
            ];
          }).toList(),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
