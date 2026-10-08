import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/dos_theme.dart';

/// Tableau scrollable navigable au clavier.
class DosTable extends StatefulWidget {
  const DosTable({
    super.key,
    required this.headers,
    required this.rows,
    this.onSelect,
    this.onCancel,
    this.onSelectionChanged,
    this.emptyMessage = 'Aucune donnée.',
    this.initialIndex = 0,
    this.autofocus = true,
    this.onMoveUpFromTop,
  });

  final List<String> headers;
  final List<List<String>> rows;
  final void Function(int index)? onSelect;
  final VoidCallback? onCancel;
  final void Function(int index)? onSelectionChanged;
  final String emptyMessage;
  final int initialIndex;
  final bool autofocus;

  /// Flèche ↑ sur la 1re ligne : remonter vers la barre de recherche.
  final VoidCallback? onMoveUpFromTop;

  @override
  State<DosTable> createState() => DosTableState();
}

class DosTableState extends State<DosTable> {
  late int _selected;
  late final ScrollController _scrollController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _selected = widget.rows.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.rows.length - 1);
    _scrollController = ScrollController();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.autofocus) {
        _focusNode.requestFocus();
      }
      _notifySelection();
    });
  }

  /// Donne le focus clavier au tableau (depuis la barre RECH>).
  void focusTable() {
    if (!mounted) return;
    _focusNode.requestFocus();
  }

  int get selectedIndex => _selected;

  @override
  void didUpdateWidget(DosTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.rows.length != oldWidget.rows.length) {
      _selected = widget.rows.isEmpty
          ? 0
          : _selected.clamp(0, widget.rows.length - 1);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _notifySelection() {
    widget.onSelectionChanged?.call(_selected);
  }

  void _move(int delta) {
    if (widget.rows.isEmpty) return;
    setState(() {
      _selected = (_selected + delta).clamp(0, widget.rows.length - 1);
    });
    _scrollToSelected();
    _notifySelection();
  }

  void _scrollToSelected() {
    final offset = _selected * 28.0;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp:
        if (_selected == 0 && widget.onMoveUpFromTop != null) {
          widget.onMoveUpFromTop!();
          return KeyEventResult.handled;
        }
        _move(-1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _move(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        _move(-10);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        _move(10);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        setState(() => _selected = 0);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        setState(() => _selected = widget.rows.length - 1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.numpadEnter:
        if (widget.rows.isNotEmpty) {
          widget.onSelect?.call(_selected);
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
        widget.onCancel?.call();
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return Text(widget.emptyMessage, style: DosTheme.text());
    }

    return Focus(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bounded = constraints.hasBoundedHeight &&
              constraints.maxHeight < double.infinity;

          final list = ListView.builder(
            controller: _scrollController,
            shrinkWrap: !bounded,
            physics: bounded
                ? const AlwaysScrollableScrollPhysics()
                : const NeverScrollableScrollPhysics(),
            itemCount: widget.rows.length,
            itemBuilder: (context, i) {
              final selected = i == _selected;
              return Container(
                color: selected ? DosColors.highlight : Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        selected ? '►' : '',
                        style: DosTheme.text(size: 14),
                      ),
                    ),
                    Expanded(
                      child: _buildDataRow(widget.rows[i], selected),
                    ),
                  ],
                ),
              );
            },
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: bounded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              _buildHeaderRow(),
              const Divider(color: DosColors.border, height: 1),
              if (bounded) Expanded(child: list) else list,
              Text(
                'Ligne ${_selected + 1}/${widget.rows.length}',
                style: DosTheme.dim(size: 12),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 4),
      child: Row(
        children: widget.headers
            .map((h) => Expanded(
                  child: Text(
                    h,
                    style: DosTheme.text(weight: FontWeight.bold, size: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildDataRow(List<String> cells, bool selected) {
    return Row(
      children: cells
          .map((c) => Expanded(
                child: Text(
                  c,
                  style: DosTheme.text(
                    size: 14,
                    color: selected ? DosColors.highlightText : DosColors.text,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ))
          .toList(),
    );
  }
}
