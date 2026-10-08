import 'package:flutter/material.dart';

import '../theme/dos_theme.dart';
import '../utils/focus_utils.dart';
import 'dos_status_bar.dart';

/// Écran de base plein écran style BIOS/DOS.
class DosScreen extends StatelessWidget {
  const DosScreen({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.helpLines = const [],
    this.onKey,
    this.focusNode,
    this.captureKeyboard = true,
    this.menuBar,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final List<String> helpLines;
  final KeyEventResult Function(FocusNode, KeyEvent)? onKey;
  final FocusNode? focusNode;
  /// Si false, ne capture pas le clavier (écrans avec formulaires).
  final bool captureKeyboard;
  /// Barre de menus horizontale (style BIOS) sous le bandeau STORA.
  final Widget? menuBar;

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (onKey == null) return KeyEventResult.ignored;
    if (isTextInputFocused()) return KeyEventResult.ignored;
    return onKey!(node, event);
  }

  @override
  Widget build(BuildContext context) {
    final body = Scaffold(
      backgroundColor: DosColors.background,
      body: Column(
        children: [
          _Header(title: title, subtitle: subtitle, menuBar: menuBar),
          Expanded(child: child),
          DosStatusBar(helpLines: helpLines),
        ],
      ),
    );

    if (!captureKeyboard || onKey == null) {
      return body;
    }

    return Focus(
      focusNode: focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: body,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.subtitle, this.menuBar});

  final String title;
  final String? subtitle;
  final Widget? menuBar;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: DosColors.backgroundAlt,
        border: Border(
          bottom: BorderSide(color: DosColors.border, width: 2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '╔══ STORA ══════════════════════════════════════════════════════════════╗',
              style: DosTheme.dim(size: 12),
            ),
          ),
          if (menuBar != null) menuBar!,
          Padding(
            padding: EdgeInsets.fromLTRB(16, menuBar != null ? 4 : 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: DosTheme.title(size: 22),
                ),
                if (subtitle != null)
                  Text(subtitle!, style: DosTheme.dim(size: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cadre avec bordure ASCII.
class DosBox extends StatelessWidget {
  const DosBox({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(12),
    this.expand = true,
  });

  final Widget child;
  final String? title;
  final EdgeInsets padding;
  /// Si true, le contenu remplit la hauteur (requis pour DosTable / Expanded).
  /// Mettre false pour un DosBox imbriqué dans un ScrollView.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: DosColors.border, width: 1),
        color: DosColors.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: DosColors.border, width: 1),
                ),
              ),
              child: Text(' $title ',
                  style: DosTheme.text(weight: FontWeight.bold)),
            ),
          if (expand) Expanded(child: body) else body,
        ],
      ),
    );
  }
}
