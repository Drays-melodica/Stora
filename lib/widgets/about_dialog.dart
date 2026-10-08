import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';
import '../theme/stora_brand.dart';

/// Fenêtre À propos avec logo STORA, nom, slogan et contacts.
class StoraAboutDialog {
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _StoraAboutDialogWidget(),
    );
  }
}

class _StoraAboutDialogWidget extends StatefulWidget {
  const _StoraAboutDialogWidget();

  @override
  State<_StoraAboutDialogWidget> createState() =>
      _StoraAboutDialogWidgetState();
}

class _StoraAboutDialogWidgetState extends State<_StoraAboutDialogWidget> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey == LogicalKeyboardKey.enter ||
            event.logicalKey == LogicalKeyboardKey.numpadEnter ||
            event.logicalKey == LogicalKeyboardKey.escape) {
          _close();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 560,
            decoration: BoxDecoration(
              color: DosColors.background,
              border: Border.all(color: DosColors.border, width: 2),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Image.asset(
                      StoraBrand.assetLogoPng,
                      width: 72,
                      height: 72,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        width: 72,
                        height: 72,
                        color: DosColors.backgroundAlt,
                        alignment: Alignment.center,
                        child: Text('S', style: DosTheme.title(size: 28)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(StoraBrand.name, style: DosTheme.title(size: 26)),
                          const SizedBox(height: 4),
                          Text(StoraBrand.slogan, style: DosTheme.dim()),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: DosColors.border, height: 1),
                const SizedBox(height: 16),
                Text('À PROPOS', style: DosTheme.text(weight: FontWeight.bold)),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: DosColors.backgroundAlt,
                    border: Border.all(color: DosColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        StoraBrand.licenseTitle,
                        style: DosTheme.text(weight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...StoraBrand.licenseLines.map(
                        (line) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(line, style: DosTheme.text()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _line('Développeur', StoraBrand.developer),
                _line('Num / WhatsApp', StoraBrand.phoneWhatsapp),
                _line('Website', StoraBrand.website),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    color: DosColors.highlight,
                    child: Text('OK [ENTRÉE]',
                        style: DosTheme.text(weight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label:', style: DosTheme.dim()),
          ),
          Expanded(
            child: Text(value, style: DosTheme.text(weight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
