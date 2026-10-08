import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../database/database_helper.dart';
import '../../models/product.dart';
import '../../services/print_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_search_bar.dart' show dosMatchesQuery;
import '../../widgets/dos_searchable_table.dart';
import 'product_form_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _all = [];
  List<Product> _products = [];
  int _selectedIndex = 0;
  final _searchCtrl = TextEditingController();
  final _currency = NumberFormat.currency(locale: 'fr_FR', symbol: '');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final products = await DatabaseHelper.instance.getProducts();
    if (!mounted) return;
    setState(() {
      _all = products;
      _applyFilter(_searchCtrl.text);
    });
  }

  void _applyFilter(String query) {
    _products = _all
        .where((p) => dosMatchesQuery(query, [
              p.code,
              p.name,
              p.unit,
              p.location,
              p.description,
            ]))
        .toList();
    if (_products.isNotEmpty) {
      _selectedIndex = _selectedIndex.clamp(0, _products.length - 1);
    } else {
      _selectedIndex = 0;
    }
  }

  Future<void> _addProduct() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
    if (result == true) await _load();
  }

  Future<void> _editProduct() async {
    if (_products.isEmpty) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(product: _products[_selectedIndex]),
      ),
    );
    if (result == true) await _load();
  }

  Future<void> _deleteProduct() async {
    if (_products.isEmpty) return;
    final product = _products[_selectedIndex];
    final confirm = await DosDialog.confirm(
      context,
      title: 'Supprimer',
      message:
          'Supprimer le produit "${product.name}" ?\nCette action est irréversible.',
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteProduct(product.id!);
      await _load();
    }
  }

  Future<void> _printLabel() async {
    if (_products.isEmpty) return;
    await PrintService.instance.printProductLabel(_products[_selectedIndex]);
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'GESTION DES PRODUITS',
      subtitle: '${_products.length}/${_all.length} produit(s)',
      helpLines: const [
        'RECH> : taper | ↓ : tableau | ↑ ligne 1 : recherche',
        'ENTREE: Modifier | F2: Nouveau | F3: Supprimer | F4: Étiquette | ECHAP: Retour',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f2:
            _addProduct();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f3:
            _deleteProduct();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f4:
            _printLabel();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            Navigator.pop(context);
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: DosBox(
        title: 'LISTE DES PRODUITS',
        child: DosSearchableTable(
          searchController: _searchCtrl,
          searchHint: 'Code, nom, emplacement…',
          onSearchChanged: (q) => setState(() => _applyFilter(q)),
          headers: const [
            'CODE',
            'NOM',
            'QTÉ',
            'MIN',
            'UNITÉ',
            'PRIX ACHAT',
            'EMPL.'
          ],
          rows: _products.map((p) {
            final low = p.isLowStock ? '!' : '';
            return [
              p.code,
              '$low${p.name}',
              '${p.quantity}',
              '${p.minStock}',
              p.unit,
              _currency.format(p.purchasePrice),
              p.location ?? '',
            ];
          }).toList(),
          onSelect: (_) => _editProduct(),
          onSelectionChanged: (i) => setState(() => _selectedIndex = i),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
