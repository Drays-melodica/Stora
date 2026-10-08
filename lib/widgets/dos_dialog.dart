import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/sound_service.dart';
import '../theme/dos_theme.dart';

/// Boîte de dialogue modale style DOS.
class DosDialog {
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'OUI [O]',
    String cancelLabel = 'NON [N]',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DosDialogWidget(
        title: title,
        message: message,
        actions: [
          _DialogAction('O', confirmLabel, true),
          _DialogAction('N', cancelLabel, false),
        ],
      ),
    );
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DosDialogWidget(
        title: title,
        message: message,
        actions: [
          _DialogAction('ENTREE', 'OK [ENTRÉE]', null),
        ],
      ),
    );
  }

  /// Confirmation d'ajout / enregistrement : bip puis dialogue.
  static Future<void> success(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    SoundService.instance.beepOk();
    return info(context, title: title, message: message);
  }

  static Future<void> error(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DosDialogWidget(
        title: title,
        message: message,
        isError: true,
        actions: [
          _DialogAction('ENTREE', 'OK [ENTRÉE]', null),
        ],
      ),
    );
  }
}

class _DialogAction {
  _DialogAction(this.key, this.label, this.value);
  final String key;
  final String label;
  final bool? value;
}

class _DosDialogWidget extends StatefulWidget {
  const _DosDialogWidget({
    required this.title,
    required this.message,
    required this.actions,
    this.isError = false,
  });

  final String title;
  final String message;
  final List<_DialogAction> actions;
  final bool isError;

  @override
  State<_DosDialogWidget> createState() => _DosDialogWidgetState();
}

class _DosDialogWidgetState extends State<_DosDialogWidget> {
  int _selected = 0;
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

  void _activate(int index) {
    final action = widget.actions[index];
    Navigator.of(context).pop(action.value);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        setState(() {
          _selected = (_selected - 1).clamp(0, widget.actions.length - 1);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight:
        setState(() {
          _selected = (_selected + 1).clamp(0, widget.actions.length - 1);
        });
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        _activate(_selected);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        Navigator.of(context).pop(false);
        return KeyEventResult.handled;
      default:
        final label = event.logicalKey.keyLabel.toUpperCase();
        for (var i = 0; i < widget.actions.length; i++) {
          if (widget.actions[i].key == label ||
              (label == 'O' && widget.actions[i].key == 'O') ||
              (label == 'N' && widget.actions[i].key == 'N')) {
            _activate(i);
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 500,
            decoration: BoxDecoration(
              color: DosColors.background,
              border: Border.all(
                color: widget.isError ? DosColors.error : DosColors.border,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title.toUpperCase(),
                  style: DosTheme.title(
                    size: 18,
                  ).copyWith(
                    color: widget.isError ? DosColors.error : DosColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(widget.message, style: DosTheme.text()),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: List.generate(widget.actions.length, (i) {
                    final selected = i == _selected;
                    return Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      color: selected ? DosColors.highlight : Colors.transparent,
                      child: Text(
                        widget.actions[i].label,
                        style: DosTheme.text(
                          weight:
                              selected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Message flash en bas d'écran.
class DosMessage extends StatelessWidget {
  const DosMessage({super.key, required this.text, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: DosColors.backgroundAlt,
      child: Text(
        text,
        style: DosTheme.text(color: color ?? DosColors.success),
      ),
    );
  }
}
