import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Select em formato de dropdown ancorado, com filtro no proprio campo.
///
/// Mantem a mesma API dos selects atuais. Ao tocar no campo, o menu abre
/// abaixo dele e o texto digitado filtra as opcoes em tempo real.
class SearchableSelectFormField<T> extends FormField<T> {
  SearchableSelectFormField({
    super.key,
    required InputDecoration decoration,
    required List<DropdownMenuItem<T>> items,
    super.initialValue,
    ValueChanged<T?>? onChanged,
    super.validator,
  }) : super(
         builder: (field) {
           final entries = [
             for (final item in items)
               if (item.value != null)
                 DropdownMenuEntry<T>(
                   value: item.value as T,
                   label: _textFromWidget(item.child),
                   labelWidget: item.child,
                   enabled: item.enabled,
                 ),
           ];

           return DropdownMenu<T>(
             enabled: onChanged != null,
             expandedInsets: EdgeInsets.zero,
             menuHeight: 360,
             enableFilter: true,
             enableSearch: true,
             requestFocusOnTap: true,
             initialSelection: field.value,
             label: decoration.labelText == null
                 ? null
                 : Text(decoration.labelText!),
             hintText: decoration.hintText,
             helperText: decoration.helperText,
             errorText: field.errorText,
             leadingIcon: decoration.prefixIcon,
             trailingIcon: decoration.suffixIcon,
             dropdownMenuEntries: entries,
             onSelected: (value) {
               field.didChange(value);
               onChanged?.call(value);
             },
           );
         },
       );
}

String _textFromWidget(Widget widget) {
  if (widget is Text) {
    return widget.data ?? widget.textSpan?.toPlainText() ?? '';
  }
  if (widget is Icon) return '';
  if (widget is MultiChildRenderObjectWidget) {
    return widget.children.map(_textFromWidget).join(' ');
  }
  if (widget is SingleChildRenderObjectWidget) {
    // Espaçadores e containers sem filho não devem vazar o tipo do widget
    // para o texto selecionado (ex.: "SizedBox Acompanhamento").
    return widget.child == null ? '' : _textFromWidget(widget.child!);
  }
  return '';
}

/// Menu de filtro pesquisavel usado nos chips de listagens.
class SearchableMenuOption<T> {
  const SearchableMenuOption({required this.value, required this.label});

  final T value;
  final String label;
}

class SearchableFilterButton<T> extends StatefulWidget {
  const SearchableFilterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
  });

  final IconData icon;
  final String label;
  final bool active;
  final List<SearchableMenuOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  State<SearchableFilterButton<T>> createState() =>
      _SearchableFilterButtonState<T>();
}

class _SearchableFilterButtonState<T> extends State<SearchableFilterButton<T>> {
  final _menuController = MenuController();

  @override
  Widget build(BuildContext context) {
    final color = widget.active ? Colors.white : AppColors.primary;
    return MenuAnchor(
      controller: _menuController,
      crossAxisUnconstrained: false,
      style: MenuStyle(
        minimumSize: const WidgetStatePropertyAll(Size(280, 0)),
        maximumSize: WidgetStatePropertyAll(
          Size(320, MediaQuery.sizeOf(context).height * 0.65),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
      ),
      menuChildren: [
        _SearchableFilterMenu<T>(
          label: widget.label,
          options: widget.options,
          onSelected: (value) {
            _menuController.close();
            widget.onSelected(value);
          },
        ),
      ],
      builder: (context, controller, child) => InkWell(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        borderRadius: BorderRadius.circular(AppTokens.pill),
        child: Chip(
          avatar: Icon(widget.icon, size: 18, color: color),
          label: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.active ? Colors.white : AppColors.ink,
            ),
          ),
          backgroundColor: widget.active
              ? AppColors.primary
              : AppColors.surface,
          side: BorderSide(
            color: widget.active ? AppColors.primary : AppColors.border,
          ),
        ),
      ),
    );
  }
}

class _SearchableFilterMenu<T> extends StatefulWidget {
  const _SearchableFilterMenu({
    required this.label,
    required this.options,
    required this.onSelected,
  });

  final String label;
  final List<SearchableMenuOption<T>> options;
  final ValueChanged<T> onSelected;

  @override
  State<_SearchableFilterMenu<T>> createState() =>
      _SearchableFilterMenuState<T>();
}

class _SearchableFilterMenuState<T> extends State<_SearchableFilterMenu<T>> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<SearchableMenuOption<T>> get filtered {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return widget.options;
    return widget.options
        .where((option) => option.label.toLowerCase().contains(query))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 296,
      height: 280,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Filtrar ${widget.label}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Digite para filtrar...',
              prefixIcon: Icon(Icons.search_rounded),
              isDense: true,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Nenhuma opcao encontrada.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final option = filtered[index];
                      return ListTile(
                        dense: true,
                        title: Text(option.label),
                        onTap: () => widget.onSelected(option.value),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
