import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/warehouse.dart';
import '../../services/sound_service.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_table.dart';

class WarehousesScreen extends StatefulWidget {
  const WarehousesScreen({super.key});

  @override
  State<WarehousesScreen> createState() => _WarehousesScreenState();
}

class _WarehousesScreenState extends State<WarehousesScreen> {
  List<Warehouse> _warehouses = [];
  List<WarehouseStock> _stock = [];
  int _mode = 0; // 0 list, 1 stock

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final wh = await DatabaseHelper.instance.getWarehouses(activeOnly: false);
    final stock = await DatabaseHelper.instance.getStockByWarehouse();
    setState(() {
      _warehouses = wh;
      _stock = stock;
    });
  }

  Future<void> _add() async {
    final code = TextEditingController();
    final name = TextEditingController();
    final address = TextEditingController();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DosScreen(
          title: 'NOUVEL ENTREPÔT',
          captureKeyboard: false,
          helpLines: const ['F10: Enregistrer | ECHAP: Annuler'],
          child: DosBox(
            title: 'SAISIE',
            child: DosForm(
              onCancel: () => Navigator.pop(ctx),
              onSubmit: (values) async {
                await DatabaseHelper.instance.insertWarehouse(Warehouse(
                  code: values['CODE']!.toUpperCase(),
                  name: values['NOM']!,
                  address: values['ADRESSE'],
                  createdAt: DateTime.now(),
                ));
                SoundService.instance.beepOk();
                if (ctx.mounted) Navigator.pop(ctx);
              },
              fields: [
                DosFormField(label: 'CODE', controller: code, required: true),
                DosFormField(label: 'NOM', controller: name, required: true),
                DosFormField(label: 'ADRESSE', controller: address),
              ],
            ),
          ),
        ),
      ),
    );
    code.dispose();
    name.dispose();
    address.dispose();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'ENTREPÔTS / EMPLACEMENTS',
      subtitle: _mode == 0
          ? '${_warehouses.length} entrepôt(s)'
          : '${_stock.length} ligne(s) de stock',
      helpLines: const [
        'F2: Nouvel entrepôt | TAB: Basculer liste/stock | ECHAP: Retour',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f2:
            _add();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.tab:
            setState(() => _mode = _mode == 0 ? 1 : 0);
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: DosBox(
        title: _mode == 0 ? 'ENTREPÔTS' : 'STOCK PAR ENTREPÔT',
        child: _mode == 0
            ? DosTable(
                headers: const ['CODE', 'NOM', 'DÉFAUT', 'ACTIF'],
                rows: _warehouses
                    .map((w) => [
                          w.code,
                          w.name,
                          w.isDefault ? 'OUI' : '',
                          w.active ? 'OUI' : 'NON',
                        ])
                    .toList(),
                onCancel: () => Navigator.pop(context),
              )
            : DosTable(
                headers: const ['ENTREPÔT', 'CODE', 'PRODUIT', 'QTÉ'],
                rows: _stock
                    .map((s) => [
                          s.warehouseCode ?? '',
                          s.productCode ?? '',
                          s.productName ?? '',
                          '${s.quantity}',
                        ])
                    .toList(),
                onCancel: () => Navigator.pop(context),
              ),
      ),
    );
  }
}
