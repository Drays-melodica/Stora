import 'package:flutter/material.dart';

import '../../database/database_helper.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/supplier.dart';
import '../../services/sound_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, this.product});

  final Product? product;

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  late final TextEditingController _code;
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _quantity;
  late final TextEditingController _minStock;
  late final TextEditingController _location;
  late final TextEditingController _description;
  late final TextEditingController _categoryId;
  late final TextEditingController _supplierId;

  List<Category> _categories = [];
  List<Supplier> _suppliers = [];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _code = TextEditingController(text: p?.code ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _unit = TextEditingController(text: p?.unit ?? '');
    _purchasePrice =
        TextEditingController(text: p?.purchasePrice.toString() ?? '0');
    _salePrice = TextEditingController(text: p?.salePrice.toString() ?? '0');
    _quantity = TextEditingController(
        text: p?.quantity.toString() ?? (_isEdit ? '0' : '0'));
    _minStock = TextEditingController(text: p?.minStock.toString() ?? '0');
    _location = TextEditingController(text: p?.location ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _categoryId =
        TextEditingController(text: p?.categoryId?.toString() ?? '1');
    _supplierId =
        TextEditingController(text: p?.supplierId?.toString() ?? '1');
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    final cats = await DatabaseHelper.instance.getCategories();
    final sups = await DatabaseHelper.instance.getSuppliers();
    setState(() {
      _categories = cats;
      _suppliers = sups;
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    _unit.dispose();
    _purchasePrice.dispose();
    _salePrice.dispose();
    _quantity.dispose();
    _minStock.dispose();
    _location.dispose();
    _description.dispose();
    _categoryId.dispose();
    _supplierId.dispose();
    super.dispose();
  }

  Future<void> _save(Map<String, String> values) async {
    try {
      final now = DateTime.now();
      final product = Product(
        id: widget.product?.id,
        code: values['CODE']!.toUpperCase(),
        name: values['DESIGNATION']!,
        categoryId: int.tryParse(values['ID CATEGORIE'] ?? ''),
        supplierId: int.tryParse(values['ID FOURNISSEUR'] ?? ''),
        unit: (values['UNITE']?.trim().isNotEmpty ?? false)
            ? values['UNITE']!.trim().toUpperCase()
            : 'UN',
        purchasePrice: double.tryParse(values['PRIX ACHAT'] ?? '0') ?? 0,
        salePrice: double.tryParse(values['PRIX VENTE'] ?? '0') ?? 0,
        quantity: _isEdit
            ? widget.product!.quantity
            : int.tryParse(values['QUANTITE INITIALE'] ?? '0') ?? 0,
        minStock: int.tryParse(values['STOCK MINIMUM'] ?? '0') ?? 0,
        location: values['EMPLACEMENT'],
        description: values['DESCRIPTION'],
        createdAt: widget.product?.createdAt ?? now,
        updatedAt: now,
      );

      if (_isEdit) {
        await DatabaseHelper.instance.updateProduct(product);
      } else {
        final existing =
            await DatabaseHelper.instance.getProductByCode(product.code);
        if (existing != null) {
          if (mounted) {
            await DosDialog.error(
              context,
              title: 'Erreur',
              message: 'Le code "${product.code}" existe déjà.',
            );
          }
          return;
        }
        await DatabaseHelper.instance.insertProduct(product);
      }

      SoundService.instance.beepOk();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        await DosDialog.error(
          context,
          title: 'Erreur',
          message: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catList = _categories
        .map((c) => '  ${c.id}: ${c.name}')
        .join('\n');
    final supList = _suppliers
        .map((s) => '  ${s.id}: ${s.name}')
        .join('\n');

    final stockLine = _isEdit
        ? 'Stock actuel: ${widget.product!.quantity} ${widget.product!.unit}\n\n'
        : '';

    return DosScreen(
      title: _isEdit ? 'MODIFIER PRODUIT' : 'NOUVEAU PRODUIT',
      subtitle: '$stockLine'
          'Catégories:\n$catList\n\nFournisseurs:\n$supList',
      captureKeyboard: false,
      helpLines: const [
        'F10 ou ENTREE (dernier champ): Enregistrer | ECHAP: Annuler',
      ],
      child: DosBox(
        title: 'FICHE PRODUIT',
        child: SingleChildScrollView(
          child: DosForm(
            onCancel: () => Navigator.pop(context),
            onSubmit: _save,
            fields: [
              DosFormField(
                label: 'CODE',
                controller: _code,
                required: true,
                maxLength: 20,
              ),
              DosFormField(
                label: 'DESIGNATION',
                controller: _name,
                required: true,
              ),
              if (!_isEdit)
                DosFormField(
                  label: 'QUANTITE INITIALE',
                  controller: _quantity,
                  keyboardType: TextInputType.number,
                  digitsOnly: true,
                ),
              DosFormField(
                label: 'STOCK MINIMUM',
                controller: _minStock,
                keyboardType: TextInputType.number,
                digitsOnly: true,
              ),
              DosFormField(
                label: 'UNITE',
                controller: _unit,
                hint: 'UN, KG, L, PCS… (vide = UN)',
                maxLength: 12,
              ),
              DosFormField(
                label: 'ID CATEGORIE',
                controller: _categoryId,
                keyboardType: TextInputType.number,
                digitsOnly: true,
              ),
              DosFormField(
                label: 'ID FOURNISSEUR',
                controller: _supplierId,
                keyboardType: TextInputType.number,
                digitsOnly: true,
              ),
              DosFormField(
                label: 'PRIX ACHAT',
                controller: _purchasePrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              DosFormField(
                label: 'PRIX VENTE',
                controller: _salePrice,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              DosFormField(label: 'EMPLACEMENT', controller: _location),
              DosFormField(label: 'DESCRIPTION', controller: _description),
            ],
          ),
        ),
      ),
    );
  }
}
