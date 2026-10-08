import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/app_exit.dart';
import '../services/auth_service.dart';
import '../services/stock_service.dart';
import '../theme/dos_theme.dart';
import '../widgets/about_dialog.dart';
import '../widgets/dos_menu_bar.dart';
import '../widgets/dos_screen.dart' show DosBox, DosScreen;
import '../widgets/dos_dialog.dart';
import '../widgets/dos_menu.dart';
import 'agents/agents_screen.dart';
import 'auth/login_screen.dart';
import 'batches/batches_screen.dart';
import 'categories/categories_screen.dart';
import 'customers/customers_screen.dart';
import 'inventory/inventory_screen.dart';
import 'movements/movements_screen.dart';
import 'orders/purchase_orders_screen.dart';
import 'orders/sales_orders_screen.dart';
import 'products/products_screen.dart';
import 'reports/reports_screen.dart';
import 'stock/returns_screen.dart';
import 'stock/stock_entry_screen.dart';
import 'stock/stock_exit_screen.dart';
import 'stock/transfer_screen.dart';
import 'suppliers/suppliers_screen.dart';
import 'settings/backup_screen.dart';
import 'settings/company_settings_screen.dart';
import 'settings/settings_screen.dart';
import 'warehouses/warehouses_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Map<String, dynamic>? _kpis;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm:ss');
  final _auth = AuthService.instance;
  final _menuBarKey = GlobalKey<DosMenuBarState>();
  final _stockMenuKey = GlobalKey<DosMenuState>();

  void _restoreStockMenuFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
      _stockMenuKey.currentState?.focusMenu();
    });
  }

  Future<void> _openAndRestore(Future<void> Function() open) async {
    await open();
    if (!mounted) return;
    await _loadKpis();
    _restoreStockMenuFocus();
  }
  List<String> get _menuItems {
    final items = <String>[
      'GESTION DES PRODUITS',
      'CATÉGORIES',
      'FOURNISSEURS',
      'CLIENTS',
      'ENTREPÔTS / EMPLACEMENTS',
      'ENTRÉE DE STOCK',
      'SORTIE DE STOCK',
      'TRANSFERT INTER-ENTREPÔTS',
      'RETOURS CLIENT / FOURNISSEUR',
      'LOTS / PÉREMPTION',
      'COMMANDES D\'ACHAT',
      'COMMANDES DE VENTE',
      'INVENTAIRE / AJUSTEMENT',
      'JOURNAL DES MOUVEMENTS',
      'RAPPORTS / EXPORT / IMPRESSION',
    ];
    if (_auth.isAdmin) {
      items.add('GESTION DES AGENTS');
    }
    items.addAll([
      'DÉCONNEXION',
      'QUITTER STORA',
    ]);
    return items;
  }

  List<DosMenuBarItem> get _topBarItems {
    final items = <DosMenuBarItem>[];

    if (_auth.isAdmin) {
      items.add(
        DosMenuBarItem(
          label: 'Société',
          hotkey: 'S',
          onSelect: () => _openAndRestore(() async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CompanySettingsScreen()),
            );
          }),
        ),
      );
    }

    items.addAll([
      DosMenuBarItem(
        label: 'Restauration',
        hotkey: 'R',
        onSelect: () => _openAndRestore(() async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BackupScreen()),
          );
        }),
      ),
      DosMenuBarItem(
        label: 'Système',
        hotkey: 'Y',
        onSelect: () => _openAndRestore(() async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          );
        }),
      ),
      DosMenuBarItem(
        label: 'À propos',
        hotkey: 'A',
        onSelect: () => _openAndRestore(() async {
          await StoraAboutDialog.show(context);
        }),
      ),
    ]);

    return items;
  }

  @override
  void initState() {
    super.initState();
    _loadKpis();
  }

  Future<void> _loadKpis() async {
    final kpis = await StockService.instance.getEnterpriseKpis();
    if (mounted) setState(() => _kpis = kpis);
  }

  Future<void> _logout() async {
    _auth.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _onSelect(int index) async {
    final label = _menuItems[index];

    switch (label) {
      case 'GESTION DES PRODUITS':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ProductsScreen()));
      case 'CATÉGORIES':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CategoriesScreen()));
      case 'FOURNISSEURS':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SuppliersScreen()));
      case 'CLIENTS':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const CustomersScreen()));
      case 'ENTREPÔTS / EMPLACEMENTS':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const WarehousesScreen()));
      case 'ENTRÉE DE STOCK':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const StockEntryScreen()));
      case 'SORTIE DE STOCK':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const StockExitScreen()));
      case 'TRANSFERT INTER-ENTREPÔTS':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const TransferScreen()));
      case 'RETOURS CLIENT / FOURNISSEUR':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ReturnsScreen()));
      case 'LOTS / PÉREMPTION':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const BatchesScreen()));
      case 'COMMANDES D\'ACHAT':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const PurchaseOrdersScreen()));
      case 'COMMANDES DE VENTE':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const SalesOrdersScreen()));
      case 'INVENTAIRE / AJUSTEMENT':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const InventoryScreen()));
      case 'JOURNAL DES MOUVEMENTS':
        await Navigator.push(context,
            MaterialPageRoute(builder: (_) => const MovementsScreen()));
      case 'RAPPORTS / EXPORT / IMPRESSION':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
      case 'GESTION DES AGENTS':
        await Navigator.push(
            context, MaterialPageRoute(builder: (_) => const AgentsScreen()));
      case 'DÉCONNEXION':
        await _logout();
        return;
      case 'QUITTER STORA':
        final quit = await DosDialog.confirm(
          context,
          title: 'Quitter',
          message: 'Voulez-vous vraiment quitter STORA ?',
        );
        if (quit == true) await AppExit.quit();
        return;
    }
    await _loadKpis();
    _restoreStockMenuFocus();
  }

  @override
  Widget build(BuildContext context) {
    final now = _dateFormat.format(DateTime.now());
    final k = _kpis;
    final user = _auth.currentUser;

    return DosScreen(
      title: 'MENU PRINCIPAL STORA',
      subtitle:
          'Connecté: ${user?.fullName ?? "?"} (${user?.roleLabel ?? "?"}) — $now',
      menuBar: DosMenuBar(
        key: _menuBarKey,
        items: _topBarItems,
        onBlur: _restoreStockMenuFocus,
      ),
      helpLines: const [
        '↑↓ : Modules | ENTREE : Ouvrir | ECHAP : Quitter | F10 : Barre BIOS',
        'Alt+S/R/Y/A : Société / Restauration / sYstème / À propos',
        'F1: Produits | F2: Entrée | F3: Sortie | F4: Rapports',
      ],
      onKey: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;

        final bar = _menuBarKey.currentState;
        if (bar != null && bar.isActive) {
          final result = bar.handleKey(event);
          if (result == KeyEventResult.handled) return result;
          // Flèches ↑↓ hors barre : rendre le focus au menu stock.
          if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            bar.blurBar();
            _restoreStockMenuFocus();
            return KeyEventResult.ignored;
          }
          return result;
        }

        final alt = HardwareKeyboard.instance.isAltPressed;
        if (bar != null && bar.tryHotkey(event.logicalKey, altPressed: alt)) {
          return KeyEventResult.handled;
        }

        final items = _menuItems;
        int indexFor(String label) => items.indexOf(label);

        switch (event.logicalKey) {
          case LogicalKeyboardKey.f10:
            bar?.focusBar();
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f1:
            _onSelect(indexFor('GESTION DES PRODUITS'));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f2:
            _onSelect(indexFor('ENTRÉE DE STOCK'));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f3:
            _onSelect(indexFor('SORTIE DE STOCK'));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.f4:
            _onSelect(indexFor('RAPPORTS / EXPORT / IMPRESSION'));
            return KeyEventResult.handled;
          case LogicalKeyboardKey.escape:
            _onSelect(indexFor('QUITTER STORA'));
            return KeyEventResult.handled;
          default:
            return KeyEventResult.ignored;
        }
      },
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DosBox(
              title: 'GESTIONNAIRE DE STOCK',
              child: DosMenu(
                key: _stockMenuKey,
                items: _menuItems,
                onSelect: _onSelect,
                onCancel: () =>
                    _onSelect(_menuItems.indexOf('QUITTER STORA')),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: DosBox(
              title: 'TABLEAU DE BORD',
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statLine('Produits', '${k?['total_products'] ?? '...'}'),
                    _statLine('Qté totale', '${k?['total_quantity'] ?? '...'}'),
                    _statLine(
                        'Valeur achat', _formatValue(k?['total_value'])),
                    _statLine(
                        'Valeur vente', _formatValue(k?['total_sale_value'])),
                    _statLine(
                      'Stock bas',
                      '${k?['low_stock_count'] ?? '...'}',
                      alert: (k?['low_stock_count'] as int? ?? 0) > 0,
                    ),
                    _statLine(
                      'Ruptures',
                      '${k?['out_of_stock_count'] ?? '...'}',
                      alert: (k?['out_of_stock_count'] as int? ?? 0) > 0,
                    ),
                    _statLine(
                      'Lots à risque',
                      '${k?['expiring_lots'] ?? '...'}',
                      alert: (k?['expiring_lots'] as int? ?? 0) > 0,
                    ),
                    _statLine('Clients', '${k?['customers_count'] ?? '...'}'),
                    _statLine('Entrepôts', '${k?['warehouses_count'] ?? '...'}'),
                    _statLine('CA ouvertes', '${k?['open_po'] ?? '...'}'),
                    _statLine('CV ouvertes', '${k?['open_so'] ?? '...'}'),
                    const SizedBox(height: 12),
                    Text('─' * 36, style: DosTheme.dim(size: 12)),
                    const SizedBox(height: 6),
                    Text('STORA Enterprise v2.0', style: DosTheme.dim()),
                    Text('Agent: ${user?.fullName ?? "?"}',
                        style: DosTheme.dim(size: 12)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statLine(String label, String value, {bool alert = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(child: Text('$label:', style: DosTheme.text(size: 13))),
          Text(
            value,
            style: DosTheme.text(
              size: 13,
              weight: FontWeight.bold,
              color: alert ? DosColors.warning : DosColors.text,
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(dynamic v) {
    if (v == null) return '...';
    final n = (v as num).toDouble();
    return NumberFormat.currency(locale: 'fr_FR', symbol: '').format(n);
  }
}
