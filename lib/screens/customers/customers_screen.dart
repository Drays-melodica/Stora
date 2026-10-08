import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/customer.dart';
import '../../services/sound_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_search_bar.dart' show dosMatchesQuery;
import '../../widgets/dos_searchable_table.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Customer> _all = [];
  List<Customer> _customers = [];
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
    final list = await DatabaseHelper.instance.getCustomers();
    if (!mounted) return;
    setState(() {
      _all = list;
      _applyFilter(_searchCtrl.text);
    });
  }

  void _applyFilter(String query) {
    final filtered = _all
        .where((c) => dosMatchesQuery(query, [
              c.code,
              c.name,
              c.contact,
              c.phone,
              c.email,
              c.city,
              c.address,
            ]))
        .toList();
    _customers = filtered;
    if (_customers.isNotEmpty) {
      _selected = _selected.clamp(0, _customers.length - 1);
    } else {
      _selected = 0;
    }
  }

  Future<void> _openForm({Customer? existing}) async {
    final isEdit = existing != null;
    final nextCode = isEdit
        ? existing.code
        : await DatabaseHelper.instance.nextCustomerCode();
    if (!mounted) return;

    final name = TextEditingController(text: existing?.name ?? '');
    final contact = TextEditingController(text: existing?.contact ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final city = TextEditingController(text: existing?.city ?? '');
    final address = TextEditingController(text: existing?.address ?? '');

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DosScreen(
          title: isEdit ? 'MODIFIER CLIENT' : 'NOUVEAU CLIENT',
          captureKeyboard: false,
          subtitle: isEdit
              ? 'Code client: $nextCode'
              : 'Code automatique attribué: $nextCode',
          helpLines: const ['F10: Enregistrer | ECHAP: Annuler'],
          child: DosBox(
            title: 'FICHE CLIENT',
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CODE CLIENT: $nextCode'
                    '${isEdit ? '' : ' (généré automatiquement)'}',
                    style: DosTheme.text(weight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  DosForm(
                    onCancel: () => Navigator.pop(ctx),
                    onSubmit: (values) async {
                      try {
                        if (isEdit) {
                          await DatabaseHelper.instance.updateCustomer(
                            existing.copyWith(
                              name: values['NOM']!.trim(),
                              contact: _nullIfEmpty(values['CONTACT']),
                              phone: _nullIfEmpty(values['TELEPHONE']),
                              email: _nullIfEmpty(values['EMAIL']),
                              city: _nullIfEmpty(values['VILLE']),
                              address: _nullIfEmpty(values['ADRESSE']),
                            ),
                          );
                          SoundService.instance.beepOk();
                        } else {
                          final code =
                              await DatabaseHelper.instance.nextCustomerCode();
                          await DatabaseHelper.instance.insertCustomer(Customer(
                            code: code,
                            name: values['NOM']!.trim(),
                            contact: _nullIfEmpty(values['CONTACT']),
                            phone: _nullIfEmpty(values['TELEPHONE']),
                            email: _nullIfEmpty(values['EMAIL']),
                            city: _nullIfEmpty(values['VILLE']),
                            address: _nullIfEmpty(values['ADRESSE']),
                            createdAt: DateTime.now(),
                          ));
                          if (ctx.mounted) {
                            await DosDialog.success(
                              ctx,
                              title: 'Client créé',
                              message: 'Client enregistré sous le code $code.',
                            );
                          }
                        }
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
                          label: 'NOM', controller: name, required: true),
                      DosFormField(label: 'CONTACT', controller: contact),
                      DosFormField(label: 'TELEPHONE', controller: phone),
                      DosFormField(label: 'EMAIL', controller: email),
                      DosFormField(label: 'VILLE', controller: city),
                      DosFormField(label: 'ADRESSE', controller: address),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    name.dispose();
    contact.dispose();
    phone.dispose();
    email.dispose();
    city.dispose();
    address.dispose();
    await _load();
  }

  String? _nullIfEmpty(String? v) {
    final t = v?.trim() ?? '';
    return t.isEmpty ? null : t;
  }

  Future<void> _edit() async {
    if (_customers.isEmpty) return;
    await _openForm(existing: _customers[_selected]);
  }

  Future<void> _add() => _openForm();

  Future<void> _delete() async {
    if (_customers.isEmpty) return;
    final c = _customers[_selected];
    final ok = await DosDialog.confirm(
      context,
      title: 'Supprimer',
      message: 'Supprimer le client ${c.name} (${c.code}) ?',
    );
    if (ok == true) {
      await DatabaseHelper.instance.deleteCustomer(c.id!);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'CLIENTS',
      subtitle:
          '${_customers.length}/${_all.length} client(s) — recherche instantanée',
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
        title: 'LISTE CLIENTS',
        child: DosSearchableTable(
          searchController: _searchCtrl,
          searchHint: 'Code, nom, contact, tél, ville…',
          onSearchChanged: (q) => setState(() => _applyFilter(q)),
          headers: const ['CODE', 'NOM', 'CONTACT', 'TÉL', 'VILLE'],
          rows: _customers
              .map((c) => [
                    c.code,
                    c.name,
                    c.contact ?? '',
                    c.phone ?? '',
                    c.city ?? '',
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
