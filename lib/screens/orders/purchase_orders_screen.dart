import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  List<PurchaseOrder> _orders = [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await DatabaseHelper.instance.getPurchaseOrders();
    setState(() => _orders = orders);
  }

  Future<void> _create() async {
    final suppliers = await DatabaseHelper.instance.getSuppliers();
    final products = await DatabaseHelper.instance.getProducts();
    if (suppliers.isEmpty || products.isEmpty) {
      await DosDialog.error(context,
          title: 'Impossible',
          message: 'Créez au moins un fournisseur et un produit.');
      return;
    }

    final supplierId = TextEditingController(text: '${suppliers.first.id}');
    final productCode = TextEditingController(text: products.first.code);
    final qty = TextEditingController(text: '1');
    final price = TextEditingController(text: '0');
    final notes = TextEditingController();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DosScreen(
          title: 'NOUVELLE COMMANDE ACHAT',
          captureKeyboard: false,
          subtitle:
              'Fournisseurs: ${suppliers.map((s) => '${s.id}:${s.name}').join(' | ')}',
          helpLines: const ['F10: Créer | ECHAP: Annuler'],
          child: DosBox(
            title: 'BON DE COMMANDE',
            child: DosForm(
              onCancel: () => Navigator.pop(ctx),
              onSubmit: (values) async {
                try {
                  final sid = int.parse(values['ID FOURNISSEUR']!);
                  final code = values['CODE PRODUIT']!.toUpperCase();
                  final product = products.firstWhere(
                    (p) => p.code == code,
                    orElse: () => throw Exception('Produit introuvable'),
                  );
                  await OrderService.instance.createPurchaseOrder(
                    supplierId: sid,
                    productId: product.id!,
                    quantity: int.parse(values['QUANTITE']!),
                    unitPrice: double.tryParse(values['PRIX UNITAIRE'] ?? '0') ?? 0,
                    notes: values['NOTES'],
                  );
                  if (ctx.mounted) {
                    await DosDialog.success(ctx,
                        title: 'OK', message: 'Commande d\'achat créée.');
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
                    label: 'ID FOURNISSEUR',
                    controller: supplierId,
                    required: true,
                    keyboardType: TextInputType.number),
                DosFormField(
                    label: 'CODE PRODUIT',
                    controller: productCode,
                    required: true),
                DosFormField(
                    label: 'QUANTITE',
                    controller: qty,
                    required: true,
                    keyboardType: TextInputType.number),
                DosFormField(label: 'PRIX UNITAIRE', controller: price),
                DosFormField(label: 'NOTES', controller: notes),
              ],
            ),
          ),
        ),
      ),
    );
    supplierId.dispose();
    productCode.dispose();
    qty.dispose();
    price.dispose();
    notes.dispose();
    _load();
  }

  Future<void> _receive() async {
    if (_orders.isEmpty) return;
    final order = _orders[_selected];
    if (order.status == OrderStatus.completed) {
      await DosDialog.info(context,
          title: 'Info', message: 'Commande déjà réceptionnée.');
      return;
    }
    final ok = await DosDialog.confirm(
      context,
      title: 'Réception',
      message: 'Réceptionner ${order.number} et entrer le stock ?',
    );
    if (ok == true) {
      try {
        await OrderService.instance.receivePurchaseOrder(order.id!);
        await DosDialog.success(context,
            title: 'Réception', message: 'Stock mis à jour.');
        _load();
      } catch (e) {
        await DosDialog.error(context, title: 'Erreur', message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'COMMANDES D\'ACHAT',
      subtitle: '${_orders.length} commande(s)',
      helpLines: const [
        'F2: Nouvelle | ENTREE: Réceptionner | ECHAP: Retour',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f2:
            _create();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: DosBox(
        title: 'LISTE',
        child: DosTable(
          headers: const ['N°', 'FOURNISSEUR', 'STATUT', 'AGENT', 'DATE'],
          rows: _orders
              .map((o) => [
                    o.number,
                    o.supplierName ?? '-',
                    o.statusLabel,
                    o.agentName,
                    o.orderDate.toIso8601String().substring(0, 10),
                  ])
              .toList(),
          onSelectionChanged: (i) => setState(() => _selected = i),
          onSelect: (_) => _receive(),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
