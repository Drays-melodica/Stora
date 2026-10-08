import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/supplier.dart';
import '../../services/sound_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_search_bar.dart' show dosMatchesQuery;
import '../../widgets/dos_searchable_table.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Supplier> _all = [];
  List<Supplier> _suppliers = [];
  int _selected = 0;
  final _searchCtrl = TextEditingController();

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
    final list = await DatabaseHelper.instance.getSuppliers();
    if (!mounted) return;
    setState(() {
      _all = list;
      _applyFilter(_searchCtrl.text);
    });
  }

  void _applyFilter(String query) {
    _suppliers = _all
        .where((s) => dosMatchesQuery(query, [
              '${s.id}',
              s.name,
              s.contact,
              s.phone,
              s.email,
              s.address,
            ]))
        .toList();
    if (_suppliers.isNotEmpty) {
      _selected = _selected.clamp(0, _suppliers.length - 1);
    } else {
      _selected = 0;
    }
  }

  Future<void> _openForm({Supplier? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final contactCtrl = TextEditingController(text: existing?.contact ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final addressCtrl = TextEditingController(text: existing?.address ?? '');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DosScreen(
          title: isEdit ? 'MODIFIER FOURNISSEUR' : 'NOUVEAU FOURNISSEUR',
          captureKeyboard: false,
          helpLines: const ['F10: Valider | ECHAP: Annuler'],
          child: DosBox(
            title: 'FICHE FOURNISSEUR',
            child: DosForm(
              onCancel: () => Navigator.pop(ctx),
              onSubmit: (values) async {
                try {
                  if (isEdit) {
                    await DatabaseHelper.instance.updateSupplier(
                      existing.copyWith(
                        name: values['NOM']!.trim(),
                        contact: _nullIfEmpty(values['CONTACT']),
                        phone: _nullIfEmpty(values['TELEPHONE']),
                        email: _nullIfEmpty(values['EMAIL']),
                        address: _nullIfEmpty(values['ADRESSE']),
                      ),
                    );
                  } else {
                    await DatabaseHelper.instance.insertSupplier(Supplier(
                      name: values['NOM']!.trim(),
                      contact: _nullIfEmpty(values['CONTACT']),
                      phone: _nullIfEmpty(values['TELEPHONE']),
                      email: _nullIfEmpty(values['EMAIL']),
                      address: _nullIfEmpty(values['ADRESSE']),
                      createdAt: DateTime.now(),
                    ));
                  }
                  SoundService.instance.beepOk();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    await DosDialog.error(
                        ctx, title: 'Erreur', message: e.toString());
                  }
                }
              },
              fields: [
                DosFormField(
                    label: 'NOM', controller: nameCtrl, required: true),
                DosFormField(label: 'CONTACT', controller: contactCtrl),
                DosFormField(label: 'TELEPHONE', controller: phoneCtrl),
                DosFormField(label: 'EMAIL', controller: emailCtrl),
                DosFormField(label: 'ADRESSE', controller: addressCtrl),
              ],
            ),
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    contactCtrl.dispose();
    phoneCtrl.dispose();
    emailCtrl.dispose();
    addressCtrl.dispose();
    await _load();
  }

  String? _nullIfEmpty(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  Future<void> _edit() async {
    if (_suppliers.isEmpty) return;
    await _openForm(existing: _suppliers[_selected]);
  }

  Future<void> _add() => _openForm();

  Future<void> _delete() async {
    if (_suppliers.isEmpty) return;
    final s = _suppliers[_selected];
    final confirm = await DosDialog.confirm(
      context,
      title: 'Supprimer',
      message: 'Supprimer le fournisseur "${s.name}" ?',
    );
    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteSupplier(s.id!);
        await _load();
      } catch (e) {
        if (mounted) {
          await DosDialog.error(
            context,
            title: 'Erreur',
            message: 'Impossible de supprimer (fournisseur peut-être utilisé).',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'FOURNISSEURS',
      subtitle: '${_suppliers.length}/${_all.length} fournisseur(s)',
      helpLines: const [
        'RECH> : taper | ↓ : tableau | ↑ ligne 1 : recherche',
        'ENTREE: Modifier | F2: Nouveau | F3: Supprimer | ECHAP: Retour',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        switch (event.logicalKey) {
          case LogicalKeyboardKey.f2:
            _add();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f3:
            _delete();
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
        child: DosSearchableTable(
          searchController: _searchCtrl,
          searchHint: 'Nom, contact, tél, email…',
          onSearchChanged: (q) => setState(() => _applyFilter(q)),
          headers: const ['ID', 'NOM', 'CONTACT', 'TÉLÉPHONE', 'EMAIL'],
          rows: _suppliers
              .map((s) => [
                    '${s.id}',
                    s.name,
                    s.contact ?? '',
                    s.phone ?? '',
                    s.email ?? '',
                  ])
              .toList(),
          onSelectionChanged: (i) => setState(() => _selected = i),
          onSelect: (_) => _edit(),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
