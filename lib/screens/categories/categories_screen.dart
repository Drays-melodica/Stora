import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../database/database_helper.dart';
import '../../models/category.dart';
import '../../services/sound_service.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_screen.dart';
import '../../widgets/dos_search_bar.dart' show dosMatchesQuery;
import '../../widgets/dos_searchable_table.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _all = [];
  List<Category> _categories = [];
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
    final cats = await DatabaseHelper.instance.getCategories();
    if (!mounted) return;
    setState(() {
      _all = cats;
      _applyFilter(_searchCtrl.text);
    });
  }

  void _applyFilter(String query) {
    _categories = _all
        .where((c) => dosMatchesQuery(query, [
              '${c.id}',
              c.name,
              c.description,
            ]))
        .toList();
    if (_categories.isNotEmpty) {
      _selected = _selected.clamp(0, _categories.length - 1);
    } else {
      _selected = 0;
    }
  }

  Future<void> _add() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => DosScreen(
          title: 'NOUVELLE CATÉGORIE',
          captureKeyboard: false,
          helpLines: const ['F10: Valider | ECHAP: Annuler'],
          child: DosBox(
            title: 'SAISIE',
            child: DosForm(
              onCancel: () => Navigator.pop(ctx),
              onSubmit: (values) async {
                try {
                  await DatabaseHelper.instance.insertCategory(Category(
                    name: values['NOM']!.toUpperCase(),
                    description: values['DESCRIPTION'],
                    createdAt: DateTime.now(),
                  ));
                  SoundService.instance.beepOk();
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  if (ctx.mounted) {
                    await DosDialog.error(
                      ctx,
                      title: 'Erreur',
                      message:
                          'Impossible d\'enregistrer (nom peut-être déjà utilisé).',
                    );
                  }
                }
              },
              fields: [
                DosFormField(label: 'NOM', controller: nameCtrl, required: true),
                DosFormField(label: 'DESCRIPTION', controller: descCtrl),
              ],
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
    descCtrl.dispose();
    await _load();
  }

  Future<void> _delete() async {
    if (_categories.isEmpty) return;
    final cat = _categories[_selected];
    final confirm = await DosDialog.confirm(
      context,
      title: 'Supprimer',
      message: 'Supprimer la catégorie "${cat.name}" ?',
    );
    if (confirm == true) {
      try {
        await DatabaseHelper.instance.deleteCategory(cat.id!);
        await _load();
      } catch (e) {
        if (mounted) {
          await DosDialog.error(
            context,
            title: 'Erreur',
            message: 'Catégorie utilisée par des produits.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DosScreen(
      title: 'CATÉGORIES',
      subtitle: '${_categories.length}/${_all.length} catégorie(s)',
      helpLines: const [
        'RECH> : taper | ↓ : tableau | ↑ ligne 1 : recherche',
        'F2: Nouvelle | F3: Supprimer | ECHAP: Retour',
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
          searchHint: 'Nom, description…',
          onSearchChanged: (q) => setState(() => _applyFilter(q)),
          headers: const ['ID', 'NOM', 'DESCRIPTION'],
          rows: _categories
              .map((c) => [
                    '${c.id}',
                    c.name,
                    c.description ?? '',
                  ])
              .toList(),
          onSelectionChanged: (i) => setState(() => _selected = i),
          onSelect: (_) => _delete(),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }
}
