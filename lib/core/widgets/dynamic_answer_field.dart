import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'app_dropdown_form_field.dart';

/// Renders one dynamic, backend-configured question/field.
///
/// The API models every answer as a single `string`, and the field's
/// `FieldType` decides how it should be captured:
///
/// | value | type        | widget                | stored answer          |
/// |-------|-------------|-----------------------|------------------------|
/// | 0     | Text        | text box              | free text              |
/// | 1     | Numeric     | numeric text box      | digits                 |
/// | 2     | Boolean     | switch                | `true` / `false`       |
/// | 3     | Date        | date picker           | `yyyy-MM-dd`           |
/// | 4     | Attachment  | URL text box          | file URL               |
/// | 5     | Option      | dropdown              | the chosen option      |
/// | 6     | MultiOption | filter chips          | options joined by `,`  |
///
/// The wire format for Boolean, Date and MultiOption is not pinned down by the
/// backend contract yet (see `BACKEND_QUESTIONS_R2.md` #6); the values above
/// are the conventional defaults, and each is still a strict improvement over
/// the free-text box these types used to fall back to.
///
/// `Option`/`MultiOption` need an [options] list. When the backend supplies
/// none (today `PersonInfoFieldResponse` has no options field), the widget
/// degrades to a plain text box rather than showing an empty picker.
class DynamicAnswerField extends StatelessWidget {
  const DynamicAnswerField({
    super.key,
    required this.label,
    required this.fieldType,
    required this.controller,
    this.isRequired = false,
    this.options = const [],
    this.enabled = true,
  });

  final String label;
  final int fieldType;

  /// Holds the answer exactly as it will be sent to the API.
  final TextEditingController controller;
  final bool isRequired;
  final List<String> options;
  final bool enabled;

  static const _boolean = 2;
  static const _date = 3;
  static const _attachment = 4;
  static const _option = 5;
  static const _multiOption = 6;

  static const multiOptionSeparator = ',';

  String get _label => isRequired ? '$label *' : label;

  String? _requiredValidator(String? value) =>
      isRequired && (value == null || value.trim().isEmpty)
          ? 'هذا الحقل مطلوب'
          : null;

  @override
  Widget build(BuildContext context) => switch (fieldType) {
        _boolean => _BooleanAnswer(
            label: _label,
            controller: controller,
            enabled: enabled,
          ),
        _date => _DateAnswer(
            label: _label,
            controller: controller,
            enabled: enabled,
            validator: _requiredValidator,
          ),
        _option when options.isNotEmpty => _OptionAnswer(
            label: _label,
            controller: controller,
            options: options,
            enabled: enabled,
            validator: _requiredValidator,
          ),
        _multiOption when options.isNotEmpty => _MultiOptionAnswer(
            label: _label,
            controller: controller,
            options: options,
            enabled: enabled,
            isRequired: isRequired,
          ),
        _ => _TextAnswer(
            label: _label,
            controller: controller,
            fieldType: fieldType,
            enabled: enabled,
            validator: _requiredValidator,
          ),
      };
}

class _TextAnswer extends StatelessWidget {
  const _TextAnswer({
    required this.label,
    required this.controller,
    required this.fieldType,
    required this.enabled,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final int fieldType;
  final bool enabled;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    final isNumeric = fieldType == 1;
    final isAttachment = fieldType == DynamicAnswerField._attachment;
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: isNumeric
          ? TextInputType.number
          : isAttachment
              ? TextInputType.url
              : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: isAttachment ? const Icon(Icons.link) : null,
        helperText: isAttachment ? 'ألصق رابط الملف بعد رفعه' : null,
      ),
      validator: validator,
    );
  }
}

class _BooleanAnswer extends StatefulWidget {
  const _BooleanAnswer({
    required this.label,
    required this.controller,
    required this.enabled,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;

  @override
  State<_BooleanAnswer> createState() => _BooleanAnswerState();
}

class _BooleanAnswerState extends State<_BooleanAnswer> {
  static const _truthy = {'true', '1', 'yes', 'نعم'};

  bool get _value => _truthy.contains(widget.controller.text.trim().toLowerCase());

  @override
  void initState() {
    super.initState();
    // A boolean is never "unanswered": normalise whatever came back so the
    // switch state and the submitted value can never disagree.
    widget.controller.text = _value.toString();
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(widget.label),
        value: _value,
        onChanged: widget.enabled
            ? (checked) =>
                setState(() => widget.controller.text = checked.toString())
            : null,
      );
}

class _DateAnswer extends StatefulWidget {
  const _DateAnswer({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool enabled;
  final FormFieldValidator<String> validator;

  @override
  State<_DateAnswer> createState() => _DateAnswerState();
}

class _DateAnswerState extends State<_DateAnswer> {
  static final _format = DateFormat('yyyy-MM-dd');

  Future<void> _pick() async {
    final current = DateTime.tryParse(widget.controller.text.trim());
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked == null) return;
    setState(() => widget.controller.text = _format.format(picked));
  }

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: widget.controller,
        enabled: widget.enabled,
        readOnly: true,
        onTap: widget.enabled ? _pick : null,
        decoration: InputDecoration(
          labelText: widget.label,
          prefixIcon: const Icon(Icons.event_outlined),
        ),
        validator: widget.validator,
      );
}

class _OptionAnswer extends StatefulWidget {
  const _OptionAnswer({
    required this.label,
    required this.controller,
    required this.options,
    required this.enabled,
    required this.validator,
  });

  final String label;
  final TextEditingController controller;
  final List<String> options;
  final bool enabled;
  final FormFieldValidator<String> validator;

  @override
  State<_OptionAnswer> createState() => _OptionAnswerState();
}

class _OptionAnswerState extends State<_OptionAnswer> {
  @override
  Widget build(BuildContext context) {
    final current = widget.controller.text.trim();
    return AppDropdownFormField<String>(
      // Guard against a stored answer that is no longer a valid option.
      initialValue: widget.options.contains(current) ? current : null,
      decoration: InputDecoration(labelText: widget.label),
      items: [
        for (final option in widget.options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      validator: widget.validator,
      onChanged: widget.enabled
          ? (value) => setState(() => widget.controller.text = value ?? '')
          : null,
    );
  }
}

class _MultiOptionAnswer extends StatefulWidget {
  const _MultiOptionAnswer({
    required this.label,
    required this.controller,
    required this.options,
    required this.enabled,
    required this.isRequired,
  });

  final String label;
  final TextEditingController controller;
  final List<String> options;
  final bool enabled;
  final bool isRequired;

  @override
  State<_MultiOptionAnswer> createState() => _MultiOptionAnswerState();
}

class _MultiOptionAnswerState extends State<_MultiOptionAnswer> {
  Set<String> get _selected => widget.controller.text
      .split(DynamicAnswerField.multiOptionSeparator)
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();

  void _toggle(String option, bool selected) {
    final next = _selected;
    selected ? next.add(option) : next.remove(option);
    setState(
      () => widget.controller.text =
          next.join(DynamicAnswerField.multiOptionSeparator),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: (_) => widget.isRequired && selected.isEmpty
          ? 'اختر خياراً واحداً على الأقل'
          : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final option in widget.options)
                FilterChip(
                  label: Text(option),
                  selected: selected.contains(option),
                  onSelected: widget.enabled
                      ? (value) {
                          _toggle(option, value);
                          state.didChange(widget.controller.text);
                        }
                      : null,
                ),
            ],
          ),
          if (state.hasError) ...[
            const SizedBox(height: 6),
            Text(
              state.errorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
