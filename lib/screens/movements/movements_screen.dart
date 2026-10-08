import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../models/stock_movement.dart';
import '../../services/print_service.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class MovementsScreen extends StatefulWidget {
  const MovementsScreen({super.key});

  @override
  State<MovementsScreen> createState() => _MovementsScreenState();
}

class _MovementsScreenState extends State<MovementsScreen> {
  List<StockMovement> _movements = [];
  Map<int, Product> _productMap = {};
  final _dateFormat = DateFormat('dd/MM/yy HH:mm');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final movements = await DatabaseHelper.instance.getMovements(limit: 200);
    final products = await DatabaseHelper.instance.getProducts();
    final map = {for (final p in products) p.id!: p};
    setState(() {
      _movements = movements;
      _productMap = map;
    });
  }

  Future<void> _print() async {
    await PrintService.instance.printMovementsReport(_movements, _productMap);
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'JOURNAL DES MOUVEMENTS',
      subtitle: '${_movements.length} mouvement(s) récent(s)',
      helpLines: const [
        'F4: Imprimer le journal | ECHAP: Retour',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f4:
            _print();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: DosBox(
        title: 'HISTORIQUE',
        child: DosTable(
          headers: const ['DATE', 'TYPE', 'AGENT', 'CODE', 'PRODUIT', 'QTÉ', 'AVANT', 'APRÈS'],
          rows: _movements.map((m) {
            final p = _productMap[m.productId];
            return [
              _dateFormat.format(m.createdAt),
              m.typeLabel,
              m.agentName,
              p?.code ?? '-',
              p?.name ?? '-',
              '${m.quantity}',
              '${m.quantityBefore}',
              '${m.quantityAfter}',
            ];
          }).toList(),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
