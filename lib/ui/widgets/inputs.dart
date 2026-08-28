import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';

/// Minus / value / plus. Used for days, people and room occupancy — the three
/// numbers that get adjusted most often.
class CounterRow extends StatelessWidget {
  const CounterRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.caption,
    this.min = 1,
    this.max = 40,
    this.icon,
    this.suffix,
  });

  final String label;
  final String? caption;
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final IconData? icon;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: AppRadius.md,
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.line),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 19, color: AppColors.primary),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                ],
              ],
            ),
          ),
          _RoundButton(
            icon: Icons.remove_rounded,
            enabled: value > min,
            onTap: () => onChanged(value - 1),
          ),
          SizedBox(
            width: 54,
            child: Text(
              suffix == null ? '$value' : '$value$suffix',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 17),
            ),
          ),
          _RoundButton(
            icon: Icons.add_rounded,
            enabled: value < max,
            onTap: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.enabled, required this.onTap});

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.primary.withValues(alpha: 0.10) : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.primary : AppColors.line,
          ),
        ),
      ),
    );
  }
}

/// Numeric field with an inline unit. Every assumption in the planner is
/// editable through one of these rather than hidden in a constant.
class NumberField extends StatefulWidget {
  const NumberField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.prefix,
    this.suffix,
    this.helper,
    this.decimals = 0,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final String? prefix;
  final String? suffix;
  final String? helper;
  final int decimals;

  @override
  State<NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<NumberField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));
  late final FocusNode _focus = FocusNode();

  String _format(double v) =>
      widget.decimals == 0 ? v.round().toString() : v.toStringAsFixed(widget.decimals);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit();
    });
  }

  @override
  void didUpdateWidget(covariant NumberField old) {
    super.didUpdateWidget(old);
    // Only overwrite the box when the value changed elsewhere and the user is
    // not mid-edit, so typing is never fought by a rebuild.
    if (!_focus.hasFocus && widget.value != old.value) {
      _controller.text = _format(widget.value);
    }
  }

  void _commit() {
    final parsed = double.tryParse(_controller.text.replaceAll(',', '').trim());
    if (parsed == null || parsed < 0) {
      _controller.text = _format(widget.value);
      return;
    }
    _controller.text = _format(parsed);
    widget.onChanged(parsed);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimals > 0),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          widget.decimals > 0 ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
        ),
      ],
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _commit(),
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        helperMaxLines: 3,
        prefixText: widget.prefix,
        suffixText: widget.suffix,
      ),
    );
  }
}

class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    required this.labelOf,
    this.iconOf,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) labelOf;
  final IconData Function(T)? iconOf;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.canvas,
        borderRadius: AppRadius.md,
        border: Border.all(color: theme.dividerTheme.color ?? AppColors.line),
      ),
      child: Row(
        children: options.map((option) {
          final selected = option == value;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: AppRadius.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconOf != null) ...[
                      Icon(
                        iconOf!(option),
                        size: 16,
                        color: selected ? Colors.white : AppColors.inkSoft,
                      ),
                      const SizedBox(width: 7),
                    ],
                    Flexible(
                      child: Text(
                        labelOf(option),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: selected ? Colors.white : AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Card-style radio used for the stay and meal tiers, where each option needs a
/// price beside it to be a real choice.
class TierOption extends StatelessWidget {
  const TierOption({
    super.key,
    required this.title,
    required this.blurb,
    required this.price,
    required this.selected,
    required this.onTap,
    required this.icon,
  });

  final String title;
  final String blurb;
  final String price;
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? AppColors.primary.withValues(alpha: 0.06) : theme.cardTheme.color,
      borderRadius: AppRadius.md,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.md,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: AppRadius.md,
            border: Border.all(
              color: selected ? AppColors.primary : (theme.dividerTheme.color ?? AppColors.line),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: selected ? AppColors.primary : AppColors.inkSoft),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
                    const SizedBox(height: 2),
                    Text(blurb, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(price, style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class SliderRow extends StatelessWidget {
  const SliderRow({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.helper,
  });

  final String label;
  final String valueLabel;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
            ),
            Text(valueLabel, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14.5)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
        if (helper != null)
          Text(helper!, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
      ],
    );
  }
}
