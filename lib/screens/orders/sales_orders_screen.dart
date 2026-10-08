import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/order.dart';
import '../../services/order_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class SalesOrdersScreen extends StatefulWidget {
  const SalesOrdersScreen({super.key});

  @override
  State<SalesOrdersScreen> createState() => _SalesOrdersScreenState();
}

class _SalesOrdersScreenState extends State<SalesOrdersScreen> {
  List<SalesOrder> _orders = [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final orders = await DatabaseHelper.instance.getSalesOrders();
    setState(() => _orders = orders);
  }

  Future<void> _create() async {
    final customers = await DatabaseHelper.instance.getCustomers();
    final products = await DatabaseHelper.instance.getProducts();
    if (customers.isEmpty || products.isEmpty) {
      await DosDialog.error(context,
          title: 'Impossible',
          message: 'Créez au moins un client et un produit.');
      return;
    }

    final customerId = TextEditingController(text: '${customers.first.id}');
    final productCode = TextEditingController(text: products.first.code);
    final qty = TextEditingController(text: '1');
    final price = TextEditingController(text: '0');
    final notes = TextEditingController();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DosScreen(
          title: 'NOUVELLE COMMANDE VENTE',
          captureKeyboard: false,
          subtitle:
              'Clients: ${customers.map((c) => '${c.id}:${c.name}').join(' | ')}',
          helpLines: const ['F10: Créer | ECHAP: Annuler'],
          child: DosBox(
            title: 'BON DE LIVRAISON / VENTE',
            child: DosForm(
              onCancel: () => Navigator.pop(ctx),
              onSubmit: (values) async {
                try {
                  final cid = int.parse(values['ID CLIENT']!);
                  final code = values['CODE PRODUIT']!.toUpperCase();
                  final product = products.firstWhere((p) => p.code == code);
                  await OrderService.instance.createSalesOrder(
                    customerId: cid,
                    productId: product.id!,
                    quantity: int.parse(values['QUANTITE']!),
                    unitPrice:
                        double.tryParse(values['PRIX UNITAIRE'] ?? '0') ?? 0,
                    notes: values['NOTES'],
                  );
                  if (ctx.mounted) {
                    await DosDialog.success(ctx,
                        title: 'OK', message: 'Commande de vente créée.');
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
                    label: 'ID CLIENT',
                    controller: customerId,
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
    customerId.dispose();
    productCode.dispose();
    qty.dispose();
    price.dispose();
    notes.dispose();
    _load();
  }

  Future<void> _ship() async {
    if (_orders.isEmpty) return;
    final order = _orders[_selected];
    if (order.status == OrderStatus.completed) {
      await DosDialog.info(context,
          title: 'Info', message: 'Commande déjà livrée.');
      return;
    }
    final ok = await DosDialog.confirm(
      context,
      title: 'Livraison',
      message: 'Livrer ${order.number} et sortir le stock ?',
    );
    if (ok == true) {
      try {
        await OrderService.instance.shipSalesOrder(order.id!);
        await DosDialog.success(context,
            title: 'Livraison', message: 'Stock mis à jour.');
        _load();
      } catch (e) {
        await DosDialog.error(context, title: 'Erreur', message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'COMMANDES DE VENTE',
      subtitle: '${_orders.length} commande(s)',
      helpLines: const [
        'F2: Nouvelle | ENTREE: Livrer | ECHAP: Retour',
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
          headers: const ['N°', 'CLIENT', 'STATUT', 'AGENT', 'DATE'],
          rows: _orders
              .map((o) => [
                    o.number,
                    o.customerName ?? '-',
                    o.statusLabel,
                    o.agentName,
                    o.orderDate.toIso8601String().substring(0, 10),
                  ])
              .toList(),
          onSelectionChanged: (i) => setState(() => _selected = i),
          onSelect: (_) => _ship(),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
