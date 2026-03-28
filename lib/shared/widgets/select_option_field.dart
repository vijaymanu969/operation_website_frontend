import 'package:flutter/material.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

enum SelectOptionColor { purple, pink, blue, green, orange, gray }

class SelectOption {
  final String            id;
  final String            name;
  final SelectOptionColor color;

  const SelectOption({
    required this.id,
    required this.name,
    required this.color,
  });

  SelectOption copyWith({String? name, SelectOptionColor? color}) => SelectOption(
    id:    id,
    name:  name  ?? this.name,
    color: color ?? this.color,
  );
}

// ─── Color pairs: (background, text) ─────────────────────────────────────────

const _kColorPairs = <SelectOptionColor, (Color, Color)>{
  SelectOptionColor.purple: (Color(0xFFF7E8FF), Color(0xFF9327FF)),
  SelectOptionColor.pink:   (Color(0xFFFFE8F0), Color(0xFFFF2D78)),
  SelectOptionColor.blue:   (Color(0xFFE8F5FF), Color(0xFF0085FF)),
  SelectOptionColor.green:  (Color(0xFFE8FFF0), Color(0xFF00B847)),
  SelectOptionColor.orange: (Color(0xFFFFF5E8), Color(0xFFFF8A00)),
  SelectOptionColor.gray:   (Color(0xFFF0F0F0), Color(0xFF606060)),
};

(Color, Color) _colorsFor(SelectOptionColor c) =>
    _kColorPairs[c] ?? (const Color(0xFFF0F0F0), const Color(0xFF606060));

// ─── Public widget ────────────────────────────────────────────────────────────

class SelectOptionField extends StatefulWidget {
  final String             label;
  final List<SelectOption> options;
  final List<String>       selectedOptions; // list of selected option ids

  final void Function(String id)                        onOptionSelected;
  final void Function(String name)                      onOptionCreated;
  final void Function(String id)                        onOptionDeleted;
  final void Function(String id, String name)?          onOptionRenamed;
  final void Function(String id, SelectOptionColor c)?  onOptionColorChanged;

  const SelectOptionField({
    super.key,
    required this.label,
    required this.options,
    required this.selectedOptions,
    required this.onOptionSelected,
    required this.onOptionCreated,
    required this.onOptionDeleted,
    this.onOptionRenamed,
    this.onOptionColorChanged,
  });

  @override
  State<SelectOptionField> createState() => _SelectOptionFieldState();
}

class _SelectOptionFieldState extends State<SelectOptionField> {
  final _rowKey = GlobalKey();
  OverlayEntry? _overlay;
  bool          _isOpen = false;

  // Internal mutable copies — source of truth while the dropdown is alive.
  // Updated by the parent via didUpdateWidget when the dropdown is closed.
  late List<SelectOption> _opts   = List.from(widget.options);
  late List<String>       _selIds = List.from(widget.selectedOptions);

  @override
  void didUpdateWidget(covariant SelectOptionField old) {
    super.didUpdateWidget(old);
    // Only sync from parent when the popup is closed to avoid flickering.
    if (!_isOpen) {
      if (old.options != widget.options) {
        _opts = List.from(widget.options);
      }
      if (old.selectedOptions != widget.selectedOptions) {
        _selIds = List.from(widget.selectedOptions);
      }
    }
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
  }

  // ── Open / close ────────────────────────────────────────────────────────────

  void _open() {
    if (_isOpen) return;
    final rb = _rowKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb == null) return;
    final pos  = rb.localToGlobal(Offset.zero);
    final size = rb.size;

    setState(() => _isOpen = true);

    _overlay = OverlayEntry(
      builder: (_) => _DropdownPopup(
        anchorPos:     Offset(pos.dx, pos.dy + size.height + 6),
        anchorRight:   pos.dx + size.width,
        options:       _opts,
        selIds:        _selIds,
        onClose:       _close,
        onSelect:      _handleSelect,
        onCreate:      _handleCreate,
        onDelete:      _handleDelete,
        onRename:      _handleRename,
        onColorChange: _handleColorChange,
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  void _close() {
    if (!_isOpen) return;
    setState(() => _isOpen = false);
    _removeOverlay();
  }

  // Tells the overlay to re-run its builder so it reflects updated _opts/_selIds.
  void _refresh() {
    _overlay?.markNeedsBuild();
    setState(() {});
  }

  // ── Callbacks (update internal state → notify parent → refresh overlay) ─────

  void _handleSelect(String id) {
    if (_selIds.contains(id)) {
      _selIds.remove(id);
    } else {
      _selIds.add(id);
    }
    widget.onOptionSelected(id);
    _refresh();
  }

  void _handleCreate(String name) {
    final colors = SelectOptionColor.values;
    final newId  = '${DateTime.now().millisecondsSinceEpoch}_$name';
    final newOpt = SelectOption(
      id:    newId,
      name:  name,
      color: colors[_opts.length % colors.length],
    );
    _opts.add(newOpt);
    _selIds.add(newId);
    widget.onOptionCreated(name);
    _refresh();
  }

  void _handleDelete(String id) {
    _opts.removeWhere((o) => o.id == id);
    _selIds.remove(id);
    widget.onOptionDeleted(id);
    _refresh();
  }

  void _handleRename(String id, String name) {
    final idx = _opts.indexWhere((o) => o.id == id);
    if (idx != -1) _opts[idx] = _opts[idx].copyWith(name: name);
    widget.onOptionRenamed?.call(id, name);
    _refresh();
  }

  void _handleColorChange(String id, SelectOptionColor color) {
    final idx = _opts.indexWhere((o) => o.id == id);
    if (idx != -1) _opts[idx] = _opts[idx].copyWith(color: color);
    widget.onOptionColorChanged?.call(id, color);
    _refresh();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final selOpts = _opts.where((o) => _selIds.contains(o.id)).toList();

    return GestureDetector(
      key:      _rowKey,
      behavior: HitTestBehavior.opaque,
      onTap:    _isOpen ? _close : _open,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Label column — matches the width of _PanelRow's label area
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.label_outline_rounded,
                  size: 14, color: Color(0xFF9CA3AF)),
              const SizedBox(width: 8),
              SizedBox(
                width: 62,
                child: Text(widget.label,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ),
            ],
          ),
          // Selected pills or "Empty" placeholder
          Expanded(
            child: selOpts.isEmpty
                ? const Text('Empty',
                    style: TextStyle(fontSize: 12, color: Color(0xFFD1D5DB)))
                : Wrap(
                    spacing:    4,
                    runSpacing: 4,
                    children: selOpts
                        .map((o) => OptionPill(option: o))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Dropdown popup (lives in OverlayEntry) ───────────────────────────────────

class _DropdownPopup extends StatefulWidget {
  final Offset             anchorPos;
  final double             anchorRight; // right edge of the trigger row (for RTL clamping)
  final List<SelectOption> options;
  final List<String>       selIds;
  final VoidCallback       onClose;
  final void Function(String)                    onSelect;
  final void Function(String)                    onCreate;
  final void Function(String)                    onDelete;
  final void Function(String, String)            onRename;
  final void Function(String, SelectOptionColor) onColorChange;

  const _DropdownPopup({
    required this.anchorPos,
    required this.anchorRight,
    required this.options,
    required this.selIds,
    required this.onClose,
    required this.onSelect,
    required this.onCreate,
    required this.onDelete,
    required this.onRename,
    required this.onColorChange,
  });

  @override
  State<_DropdownPopup> createState() => _DropdownPopupState();
}

class _DropdownPopupState extends State<_DropdownPopup> {
  final _searchCtrl  = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) setState(() => _query = _searchCtrl.text.toLowerCase().trim());
    });
    // Auto-focus the search field as soon as the popup is rendered.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _searchFocus.requestFocus());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.name.toLowerCase().contains(_query))
            .toList();

    final noMatch    = filtered.isEmpty;
    final showCreate = _query.isNotEmpty;

    // Clamp horizontally: prefer left-aligned with the anchor,
    // but if that overflows the right edge, right-align to anchorRight instead.
    const popupW  = 280.0;
    final screenW = MediaQuery.of(context).size.width;
    double left   = widget.anchorPos.dx;
    if (left + popupW > screenW - 8) {
      left = widget.anchorRight - popupW; // right-align to the row's right edge
    }
    left = left.clamp(8.0, screenW - popupW - 8);

    return Stack(children: [
      // ── Transparent barrier — tapping outside closes the popup ──────────────
      Positioned.fill(
        child: GestureDetector(
          onTap:    widget.onClose,
          behavior: HitTestBehavior.opaque,
        ),
      ),

      // ── Popup card ──────────────────────────────────────────────────────────
      Positioned(
        left: left,
        top:  widget.anchorPos.dy,
        child: GestureDetector(
          // Absorb taps inside so they never reach the barrier above.
          onTap:    () {},
          behavior: HitTestBehavior.opaque,
          child: Material(
            color:        Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width:       280,
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color:        Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color:      Colors.black12,
                    blurRadius: 8,
                    offset:     Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize:        MainAxisSize.min,
                crossAxisAlignment:  CrossAxisAlignment.stretch,
                children: [
                  // ── Search / create input ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode:  _searchFocus,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A1A2E)),
                      decoration: InputDecoration(
                        hintText:  'Search for an option...',
                        hintStyle: const TextStyle(
                            fontSize: 13, color: Color(0xFF9CA3AF)),
                        isDense:        true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 8),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide:
                              const BorderSide(color: Color(0xFFE8ECF3)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          // Light-blue outline when focused — AppFlowy style
                          borderSide: const BorderSide(
                              color: Color(0xFF60A5FA), width: 1.5),
                        ),
                      ),
                      onSubmitted: (v) {
                        final text = v.trim();
                        if (text.isEmpty) return;
                        if (noMatch) {
                          widget.onCreate(text);
                        } else if (filtered.length == 1) {
                          widget.onSelect(filtered.first.id);
                        }
                        _searchCtrl.clear();
                      },
                    ),
                  ),

                  // ── Hint ──────────────────────────────────────────────────
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 6),
                    child: Text(
                      'Select an option or create one',
                      style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8ECF3)),

                  // ── Options list ───────────────────────────────────────────
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // "Create X" row — shown when query has no full match
                          if (showCreate)
                            _CreateRow(
                              text:    _searchCtrl.text.trim(),
                              onCreate: () {
                                widget.onCreate(_searchCtrl.text.trim());
                                _searchCtrl.clear();
                              },
                            ),
                          if (showCreate && widget.options.isNotEmpty)
                            const Divider(height: 1, color: Color(0xFFE8ECF3)),

                          // Filtered option rows
                          ...filtered.map((opt) => _OptionRow(
                            key:        ValueKey(opt.id),
                            option:     opt,
                            isSelected: widget.selIds.contains(opt.id),
                            onTap:      () => widget.onSelect(opt.id),
                            onDelete:   () => widget.onDelete(opt.id),
                            onRename:   (n) => widget.onRename(opt.id, n),
                            onColor:    (c) => widget.onColorChange(opt.id, c),
                          )),

                          // Empty state
                          if (!showCreate && widget.options.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text(
                                'No options yet.\nType above to create one.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF9CA3AF)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

// ─── "Create X" row ──────────────────────────────────────────────────────────

class _CreateRow extends StatelessWidget {
  final String       text;
  final VoidCallback onCreate;
  const _CreateRow({required this.text, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCreate,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          const Icon(Icons.add, size: 14, color: Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          const Text('Create ',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          Flexible(
            child: Text(
              '"$text"',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize:   12,
                  fontWeight: FontWeight.w500,
                  color:      Color(0xFF1A1A2E)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Option row (drag handle | pill | … menu) ─────────────────────────────────

class _OptionRow extends StatefulWidget {
  final SelectOption                     option;
  final bool                             isSelected;
  final VoidCallback                     onTap;
  final VoidCallback                     onDelete;
  final void Function(String)            onRename;
  final void Function(SelectOptionColor) onColor;

  const _OptionRow({
    super.key,
    required this.option,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
    required this.onRename,
    required this.onColor,
  });

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _renaming = false;
  late final _renameCtrl  = TextEditingController(text: widget.option.name);
  final       _renameFocus = FocusNode();

  @override
  void didUpdateWidget(covariant _OptionRow old) {
    super.didUpdateWidget(old);
    if (old.option.name != widget.option.name && !_renaming) {
      _renameCtrl.text = widget.option.name;
    }
  }

  @override
  void dispose() {
    _renameCtrl.dispose();
    _renameFocus.dispose();
    super.dispose();
  }

  void _commitRename() {
    final name = _renameCtrl.text.trim();
    if (name.isNotEmpty && name != widget.option.name) {
      widget.onRename(name);
    }
    if (mounted) setState(() => _renaming = false);
  }

  Future<void> _openContextMenu(BuildContext ctx) async {
    final rb  = ctx.findRenderObject() as RenderBox;
    final pos = rb.localToGlobal(Offset.zero);

    final result = await showMenu<String>(
      context:  ctx,
      position: RelativeRect.fromLTRB(
          pos.dx, pos.dy, pos.dx + 160, pos.dy + 120),
      shape:    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color:    Colors.white,
      elevation: 4,
      items: [
        PopupMenuItem(
          value:  'rename',
          height: 36,
          child:  _MenuItemRow(Icons.edit_outlined, 'Rename'),
        ),
        PopupMenuItem(
          value:  'delete',
          height: 36,
          child:  _MenuItemRow(Icons.delete_outline_rounded, 'Delete'),
        ),
        const PopupMenuDivider(height: 1),
        // Color swatches row
        PopupMenuItem(
          enabled: false,
          height:  48,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Wrap(
            spacing: 8,
            children: SelectOptionColor.values.map((c) {
              final (bg, text) = _colorsFor(c);
              final isCurrent  = c == widget.option.color;
              return GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  widget.onColor(c);
                },
                child: Container(
                  width:  22, height: 22,
                  decoration: BoxDecoration(
                    color:  bg,
                    shape:  BoxShape.circle,
                    border: Border.all(
                      color: isCurrent ? text : text.withValues(alpha: 0.35),
                      width: isCurrent ? 2    : 1,
                    ),
                  ),
                  child: isCurrent
                      ? Icon(Icons.check_rounded, size: 11, color: text)
                      : null,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );

    if (!mounted) return;
    if (result == 'rename') {
      setState(() {
        _renaming        = true;
        _renameCtrl.text = widget.option.name;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _renameFocus.requestFocus();
        _renameCtrl.selection = TextSelection(
            baseOffset: 0, extentOffset: _renameCtrl.text.length);
      });
    } else if (result == 'delete') {
      widget.onDelete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: _renaming ? null : widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(children: [
          // ⠿ Drag handle (visual only for now)
          const Icon(Icons.drag_indicator,
              size: 16, color: Color(0xFFD1D5DB)),
          const SizedBox(width: 6),

          // Pill or inline rename field
          Expanded(
            child: _renaming
                ? TextField(
                    controller:        _renameCtrl,
                    focusNode:         _renameFocus,
                    style:             const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      border:         InputBorder.none,
                      isDense:        true,
                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                    ),
                    onSubmitted:       (_) => _commitRename(),
                    onEditingComplete: _commitRename,
                  )
                : OptionPill(
                    option:     widget.option,
                    isSelected: widget.isSelected,
                  ),
          ),
          const SizedBox(width: 6),

          // Right action button
          if (_renaming)
            // ✓ confirm rename
            GestureDetector(
              onTap: _commitRename,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.check_rounded,
                    size: 16, color: Color(0xFF10B981)),
              ),
            )
          else
            // … three-dot context menu
            Builder(
              builder: (ctx) => GestureDetector(
                onTap: () => _openContextMenu(ctx),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.more_horiz_rounded,
                      size: 16, color: Colors.grey[400]),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}

// ─── Reusable pill chip ───────────────────────────────────────────────────────
// Public so tasks_screen can reuse it on the kanban cards if needed.

class OptionPill extends StatelessWidget {
  final SelectOption option;
  final bool         isSelected;
  const OptionPill({super.key, required this.option, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    final (bg, text) = _colorsFor(option.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Checkmark for selected state inside the pill
          if (isSelected) ...[
            Icon(Icons.check_rounded, size: 11, color: text),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              option.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w500,
                  color:      text),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Menu item row ────────────────────────────────────────────────────────────

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _MenuItemRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 14, color: const Color(0xFF6B7280)),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E))),
    ]);
  }
}
