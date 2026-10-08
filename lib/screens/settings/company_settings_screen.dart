import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/company_profile.dart';
import '../../services/auth_service.dart';
import '../../services/company_service.dart';
import '../../theme/dos_theme.dart';
import '../../widgets/dos_dialog.dart';
import '../../widgets/dos_form.dart';
import '../../widgets/dos_menu.dart';
import '../../widgets/dos_screen.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _companyService = CompanyService.instance;
  CompanyProfile? _profile;
  bool _showLogoMenu = false;

  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (!AuthService.instance.isAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pop(context);
      });
      return;
    }
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _taxIdCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final profile = await _companyService.getProfile();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _nameCtrl.text = profile.companyName;
      _addressCtrl.text = profile.address ?? '';
      _cityCtrl.text = profile.city ?? '';
      _phoneCtrl.text = profile.phone ?? '';
      _emailCtrl.text = profile.email ?? '';
      _taxIdCtrl.text = profile.taxId ?? '';
      _websiteCtrl.text = profile.website ?? '';
    });
  }

  Future<void> _save(Map<String, String> values) async {
    final name = values['NOM SOCIETE']?.trim() ?? '';
    if (name.isEmpty) {
      await DosDialog.error(
        context,
        title: 'Erreur',
        message: 'Le nom de la société est obligatoire.',
      );
      return;
    }

    final profile = CompanyProfile(
      companyName: name,
      address: values['ADRESSE'],
      city: values['VILLE / PAYS'],
      phone: values['TELEPHONE'],
      email: values['EMAIL'],
      taxId: values['NIF / RC'],
      website: values['SITE WEB'],
      logoPath: _profile?.logoPath,
      updatedAt: DateTime.now(),
    );

    await _companyService.saveProfile(profile);
    if (mounted) {
      await DosDialog.info(
        context,
        title: 'Enregistré',
        message:
            'Informations société mises à jour.\nElles apparaîtront sur les documents imprimés.',
      );
      _load();
    }
  }

  Future<void> _pickLogo() async {
    try {
      final updated = await _companyService.pickAndSetLogo();
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _profile = updated;
          _showLogoMenu = false;
        });
        await DosDialog.info(
          context,
          title: 'Logo',
          message: 'Logo enregistré avec succès.',
        );
      }
    } catch (e) {
      if (mounted) {
        await DosDialog.error(
          context,
          title: 'Logo',
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    }
  }

  Future<void> _removeLogo() async {
    if (_profile?.logoPath == null) return;
    final confirm = await DosDialog.confirm(
      context,
      title: 'Supprimer logo',
      message: 'Supprimer le logo de la société ?',
    );
    if (confirm == true) {
      final updated = await _companyService.removeLogo();
      if (mounted) {
        setState(() {
          _profile = updated;
          _showLogoMenu = false;
        });
      }
    }
  }

  String get _logoStatus {
    final path = _profile?.logoPath;
    if (path == null || path.isEmpty) return 'Aucun logo';
    if (!File(path).existsSync()) return 'Logo introuvable';
    return 'Logo: ${path.split(Platform.pathSeparator).last}';
  }

  @override
  Widget build(BuildContext context) {
    if (!AuthService.instance.isAdmin) {
      return const SizedBox.shrink();
    }

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f3): _pickLogo,
        const SingleActivator(LogicalKeyboardKey.f4): _removeLogo,
        const SingleActivator(LogicalKeyboardKey.f2): () {
          setState(() => _showLogoMenu = !_showLogoMenu);
        },
      },
      child: Focus(
        autofocus: false,
        child: DosScreen(
          title: 'INFORMATIONS SOCIÉTÉ',
          subtitle: 'En-tête des documents imprimés (rapports, étiquettes)',
          captureKeyboard: false,
          helpLines: const [
            'F2: Menu logo | F3: Choisir logo | F4: Supprimer | F10: Enregistrer | ECHAP: Retour',
          ],
          child: DosBox(
            title: 'FICHE SOCIÉTÉ',
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_logoStatus,
                      style: DosTheme.text(weight: FontWeight.bold)),
                  if (_profile?.logoPath != null &&
                      File(_profile!.logoPath!).existsSync()) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: DosColors.border),
                        color: DosColors.backgroundAlt,
                      ),
                      child: Image.file(
                        File(_profile!.logoPath!),
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Logo: F2 (menu) ou F3 (choisir fichier PNG/JPG)',
                    style: DosTheme.dim(size: 12),
                  ),
                  if (_showLogoMenu) ...[
                    const SizedBox(height: 8),
                    DosBox(
                      expand: false,
                      title: 'LOGO',
                      child: DosMenu(
                        items: const [
                          'CHOISIR / CHANGER LE LOGO',
                          'SUPPRIMER LE LOGO',
                          'RETOUR À LA FICHE',
                        ],
                        onSelect: (i) async {
                          switch (i) {
                            case 0:
                              await _pickLogo();
                            case 1:
                              await _removeLogo();
                            case 2:
                              setState(() => _showLogoMenu = false);
                          }
                        },
                        onCancel: () =>
                            setState(() => _showLogoMenu = false),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  DosForm(
                    submitLabel: 'ENREGISTRER [F10]',
                    onCancel: () => Navigator.pop(context),
                    onSubmit: _save,
                    fields: [
                      DosFormField(
                        label: 'NOM SOCIETE',
                        controller: _nameCtrl,
                        required: true,
                      ),
                      DosFormField(label: 'ADRESSE', controller: _addressCtrl),
                      DosFormField(
                          label: 'VILLE / PAYS', controller: _cityCtrl),
                      DosFormField(label: 'TELEPHONE', controller: _phoneCtrl),
                      DosFormField(label: 'EMAIL', controller: _emailCtrl),
                      DosFormField(label: 'NIF / RC', controller: _taxIdCtrl),
                      DosFormField(label: 'SITE WEB', controller: _websiteCtrl),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
