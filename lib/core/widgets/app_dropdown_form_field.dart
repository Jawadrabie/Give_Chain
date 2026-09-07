import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// قائمة منسدلة للنماذج: تفتح مباشرة تحت الحقل بحواف ناعمة وظل خفيف.
class AppDropdownFormField<T> extends FormField<T> {
  AppDropdownFormField({
    super.key,
    required List<DropdownMenuItem<T>> items,
    T? initialValue,
    @Deprecated('Use initialValue instead.') T? value,
    required ValueChanged<T?>? onChanged,
    InputDecoration? decoration,
    super.validator,
    super.onSaved,
    AutovalidateMode? autovalidateMode,
    Widget? hint,
    bool isExpanded = true,
    double menuMaxHeight = 280,
  }) : assert(
         items.isEmpty ||
             (initialValue == null && value == null) ||
             items
                     .where((item) => item.value == (initialValue ?? value))
                     .length ==
                 1,
         'There should be exactly one item with AppDropdownFormField value.',
       ),
       super(
         initialValue: initialValue ?? value,
         autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
         builder: (field) {
           final theme = Theme.of(field.context);
           final scheme = theme.colorScheme;
           final isDark = theme.brightness == Brightness.dark;
           final enabled = onChanged != null;
           final baseDecoration = (decoration ?? const InputDecoration())
               .applyDefaults(InputDecorationTheme.of(field.context))
               .copyWith(errorText: field.errorText, enabled: enabled);

           DropdownMenuItem<T>? selected;
           for (final item in items) {
             if (item.value == field.value) {
               selected = item;
               break;
             }
           }

           final menuColor = isDark ? AppTheme.darkSurface : AppTheme.background;
           final menuBorder = isDark ? AppTheme.darkBorder : AppTheme.border;

           return MenuAnchor(
             crossAxisUnconstrained: false,
             alignmentOffset: const Offset(0, 6),
             consumeOutsideTap: true,
             style: MenuStyle(
               backgroundColor: WidgetStatePropertyAll(menuColor),
               elevation: const WidgetStatePropertyAll(8),
               shadowColor: WidgetStatePropertyAll(
                 Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
               ),
               surfaceTintColor: const WidgetStatePropertyAll(
                 Colors.transparent,
               ),
               shape: WidgetStatePropertyAll(
                 RoundedRectangleBorder(
                   borderRadius: BorderRadius.circular(AppTheme.menuRadius),
                   side: BorderSide(color: menuBorder),
                 ),
               ),
               padding: const WidgetStatePropertyAll(
                 EdgeInsets.symmetric(vertical: 6),
               ),
               maximumSize: WidgetStatePropertyAll(
                 Size(double.infinity, menuMaxHeight),
               ),
             ),
             builder: (context, controller, _) {
               final open = controller.isOpen;
               final display = _labelOf(
                 selected?.child,
                 overflow: TextOverflow.ellipsis,
               );

               return InkWell(
                 borderRadius: BorderRadius.circular(AppTheme.radius),
                 onTap: !enabled
                     ? null
                     : () {
                         FocusScope.of(context).unfocus();
                         if (open) {
                           controller.close();
                         } else {
                           controller.open();
                         }
                       },
                 child: InputDecorator(
                   isFocused: open,
                   isEmpty: selected == null && hint == null,
                   decoration: baseDecoration.copyWith(
                     suffixIcon: AnimatedRotation(
                       turns: open ? 0.5 : 0,
                       duration: const Duration(milliseconds: 180),
                       curve: Curves.easeOutCubic,
                       child: Icon(
                         Icons.keyboard_arrow_down_rounded,
                         color: enabled
                             ? (open
                                   ? scheme.primary
                                   : scheme.onSurface.withValues(alpha: 0.55))
                             : scheme.onSurface.withValues(alpha: 0.28),
                       ),
                     ),
                   ),
                   child: DefaultTextStyle.merge(
                     style: theme.textTheme.bodyLarge?.copyWith(
                       color: enabled
                           ? scheme.onSurface
                           : scheme.onSurface.withValues(alpha: 0.38),
                     ),
                     child: SizedBox(
                       width: isExpanded ? double.infinity : null,
                       child: display ?? hint ?? const SizedBox(height: 24),
                     ),
                   ),
                 ),
               );
             },
             menuChildren: [
               for (final item in items)
                 MenuItemButton(
                   onPressed: !enabled || !item.enabled
                       ? null
                       : () {
                           field.didChange(item.value);
                           onChanged(item.value);
                         },
                   style: ButtonStyle(
                     backgroundColor: WidgetStateProperty.resolveWith((
                       states,
                     ) {
                       if (item.value == field.value) {
                         return scheme.primary.withValues(alpha: 0.12);
                       }
                       if (states.contains(WidgetState.hovered) ||
                           states.contains(WidgetState.focused)) {
                         return scheme.primary.withValues(alpha: 0.06);
                       }
                       return Colors.transparent;
                     }),
                     foregroundColor: WidgetStatePropertyAll(scheme.onSurface),
                     padding: const WidgetStatePropertyAll(
                       EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                     ),
                     textStyle: WidgetStatePropertyAll(
                       theme.textTheme.bodyLarge?.copyWith(
                         fontWeight: item.value == field.value
                             ? FontWeight.w700
                             : FontWeight.w500,
                       ),
                     ),
                   ),
                   child: SizedBox(
                     width: double.infinity,
                     child:
                         _labelOf(item.child) ??
                         const SizedBox(height: 20),
                   ),
                 ),
             ],
           );
         },
       );
}

/// ينسخ تسمية العنصر كـ [Text] مستقل حتى لا يُعاد استخدام نفس الـ Widget
/// في الحقل والقائمة معاً.
Widget? _labelOf(Widget? child, {TextOverflow? overflow}) {
  if (child == null) return null;
  if (child is Text) {
    return Text(
      child.data ?? '',
      style: child.style,
      textAlign: child.textAlign,
      maxLines: overflow != null ? 1 : child.maxLines,
      overflow: overflow ?? child.overflow,
      softWrap: overflow != null ? false : child.softWrap,
    );
  }
  return child;
}
