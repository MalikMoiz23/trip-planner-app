import 'package:flutter/material.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../models/expense_breakdown.dart';

/// Where the money goes: one stacked bar plus a legend that doubles as the
/// value table.
///
/// Every segment is labelled in the legend with its rupee figure and share, so
/// identity never rests on colour alone, and the low-contrast slots in the
/// series palette always have a text label carrying the same information.
class CostBreakdownChart extends StatefulWidget {
  const CostBreakdownChart({super.key, required this.breakdown});

  final ExpenseBreakdown breakdown;

  @override
  State<CostBreakdownChart> createState() => _CostBreakdownChartState();
}

class _CostBreakdownChartState extends State<CostBreakdownChart> {
  int? _focused;
  bool _asTable = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lines = widget.breakdown.visibleLines;
    if (lines.isEmpty) {
      return Text('Nothing to break down yet.', style: theme.textTheme.bodySmall);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Where the money goes',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5),
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(() => _asTable = !_asTable),
              icon: Icon(_asTable ? Icons.bar_chart_rounded : Icons.table_rows_rounded, size: 17),
              label: Text(_asTable ? 'Chart' : 'Table'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_asTable)
          _CostTable(lines: lines, total: widget.breakdown.total)
        else ...[
          LayoutBuilder(
            builder: (context, constraints) => GestureDetector(
              onTapDown: (details) {
                final index = _hitTest(
                  details.localPosition.dx,
                  constraints.maxWidth,
                  lines,
                );
                setState(() => _focused = _focused == index ? null : index);
              },
              child: SizedBox(
                height: 26,
                width: double.infinity,
                child: CustomPaint(
                  painter: _StackedBarPainter(
                    lines: lines,
                    total: widget.breakdown.total,
                    focused: _focused,
                    brightness: theme.brightness,
                    surface: theme.cardTheme.color ?? Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(lines.length, (i) {
            final line = lines[i];
            return _LegendRow(
              line: line,
              share: widget.breakdown.shareOf(line),
              focused: _focused == i,
              onTap: () => setState(() => _focused = _focused == i ? null : i),
            );
          }),
        ],
      ],
    );
  }

  int? _hitTest(double dx, double width, List<ExpenseLine> lines) {
    final total = widget.breakdown.total;
    if (total <= 0) return null;
    var x = 0.0;
    for (var i = 0; i < lines.length; i++) {
      final w = width * (lines[i].amount / total);
      if (dx >= x && dx <= x + w) return i;
      x += w;
    }
    return null;
  }
}

class _StackedBarPainter extends CustomPainter {
  _StackedBarPainter({
    required this.lines,
    required this.total,
    required this.focused,
    required this.brightness,
    required this.surface,
  });

  final List<ExpenseLine> lines;
  final double total;
  final int? focused;
  final Brightness brightness;
  final Color surface;

  /// Segments are separated by a 2px gap in the surface colour rather than a
  /// stroke, so adjacent fills never blend into one another.
  static const double _gap = 2.0;
  static const double _radius = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0 || lines.isEmpty) return;

    final gaps = _gap * (lines.length - 1);
    final usable = size.width - gaps;
    var x = 0.0;

    for (var i = 0; i < lines.length; i++) {
      final w = usable * (lines[i].amount / total);
      if (w <= 0) continue;

      final dim = focused != null && focused != i;
      final paint = Paint()
        ..color = AppColors.series(lines[i].slot, brightness).withValues(alpha: dim ? 0.28 : 1.0)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(x, 0, w, size.height);
      final rrect = RRect.fromRectAndCorners(
        rect,
        topLeft: i == 0 ? const Radius.circular(_radius) : Radius.zero,
        bottomLeft: i == 0 ? const Radius.circular(_radius) : Radius.zero,
        topRight: i == lines.length - 1 ? const Radius.circular(_radius) : Radius.zero,
        bottomRight: i == lines.length - 1 ? const Radius.circular(_radius) : Radius.zero,
      );
      canvas.drawRRect(rrect, paint);

      if (focused == i) {
        canvas.drawRRect(
          rrect.inflate(1.5),
          Paint()
            ..color = surface
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }

      x += w + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _StackedBarPainter old) =>
      old.total != total ||
      old.focused != focused ||
      old.brightness != brightness ||
      old.lines.length != lines.length ||
      !_sameAmounts(old.lines);

  bool _sameAmounts(List<ExpenseLine> other) {
    for (var i = 0; i < lines.length; i++) {
      if (other[i].amount != lines[i].amount || other[i].slot != lines[i].slot) return false;
    }
    return true;
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.line,
    required this.share,
    required this.focused,
    required this.onTap,
  });

  final ExpenseLine line;
  final double share;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.sm,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 11,
              height: 11,
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.seriesOf(context, line.slot),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          line.label,
                          style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        money(line.amount),
                        style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '${(share * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
                        ),
                      ),
                    ],
                  ),
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 160),
                    crossFadeState:
                        focused ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                    firstChild: Padding(
                      padding: const EdgeInsets.only(top: 4, right: 40),
                      child: Text(
                        line.detail,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2),
                      ),
                    ),
                    secondChild: const SizedBox(width: double.infinity),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Plain value table. Present because three slots in the series palette fall
/// below 3:1 against the light surface, and a text alternative is the required
/// relief for that.
class _CostTable extends StatelessWidget {
  const _CostTable({required this.lines, required this.total});

  final List<ExpenseLine> lines;
  final double total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 7),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(line.label, style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                    ),
                    Text(money(line.amount), style: theme.textTheme.titleSmall?.copyWith(fontSize: 14)),
                    SizedBox(
                      width: 46,
                      child: Text(
                        total <= 0 ? '0%' : '${(line.amount / total * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(line.detail, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.2)),
              ],
            ),
          ),
        const Divider(height: 22),
        Row(
          children: [
            Expanded(child: Text('Total', style: theme.textTheme.titleMedium)),
            Text(money(total), style: theme.textTheme.titleMedium),
            const SizedBox(width: 46),
          ],
        ),
      ],
    );
  }
}
