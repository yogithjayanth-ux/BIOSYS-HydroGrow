import 'dart:math' as math;

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class MoistureReading {
  const MoistureReading({
    required this.time,
    required this.moisture,
  });

  final DateTime time;
  final double moisture;
}

class MoistureHistoryChart extends StatefulWidget {
  const MoistureHistoryChart({
    super.key,
    required this.systemId,
    this.limit,
    this.height = 220,
  });

  final String systemId;
  final int? limit;
  final double height;

  @override
  State<MoistureHistoryChart> createState() => _MoistureHistoryChartState();
}

class _MoistureHistoryChartState extends State<MoistureHistoryChart> {
  int? _hoverIndex;

  bool get _hoverEnabled => widget.limit == 10 || widget.limit == 50;

  @override
  Widget build(BuildContext context) {
    final trimmedId = widget.systemId.trim();
    if (trimmedId.isEmpty) {
      return MoistureHistoryChart._placeholder(context, 'No system selected.');
    }

    Query query;
    try {
      query = FirebaseDatabase.instance
          .ref('devices/$trimmedId/readings')
          .orderByChild('ts');
      if (widget.limit != null) query = query.limitToLast(widget.limit!);
    } catch (_) {
      return MoistureHistoryChart._placeholder(
        context,
        'Firebase not configured.',
      );
    }

    return StreamBuilder<DatabaseEvent>(
      stream: query.onValue,
      builder: (context, snapshot) {
        final readings =
            MoistureHistoryChart._parseReadings(snapshot.data?.snapshot.value);
        if (readings.isEmpty) {
          return MoistureHistoryChart._placeholder(context, 'No history yet.');
        }

        final primary = Theme.of(context).colorScheme.primary;
        final labelStyle = TextStyle(color: Colors.grey.shade700, fontSize: 10);

        return SizedBox(
          height: widget.height,
          width: double.infinity,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(
                constraints.maxWidth.isFinite ? constraints.maxWidth : 0,
                widget.height,
              );

              final scaler = _MoistureChartScaler.tryCreate(readings, size);
              if (scaler == null) {
                return MoistureHistoryChart._placeholder(
                  context,
                  'Not enough space for chart.',
                );
              }

              final points = readings
                  .map(scaler.point)
                  .toList(growable: false);

              void setHoverIndex(int? next) {
                if (!_hoverEnabled) return;
                if (next == _hoverIndex) return;
                setState(() => _hoverIndex = next);
              }

              int? hitTest(Offset localPosition) {
                const threshold = 10.0;
                final threshold2 = threshold * threshold;
                int? bestIndex;
                var bestDist2 = threshold2;

                for (var i = 0; i < points.length; i += 1) {
                  final p = points[i];
                  final dx = p.dx - localPosition.dx;
                  final dy = p.dy - localPosition.dy;
                  final d2 = (dx * dx) + (dy * dy);
                  if (d2 <= bestDist2) {
                    bestDist2 = d2;
                    bestIndex = i;
                  }
                }
                return bestIndex;
              }

              final highlightIndex = _hoverEnabled ? _hoverIndex : null;
              final painter = _MoistureChartPainter(
                readings: readings,
                lineColor: primary,
                gridColor: Colors.black12,
                labelStyle: labelStyle,
                highlightIndex: highlightIndex,
              );

              final paint = CustomPaint(painter: painter);
              if (!_hoverEnabled) return paint;

              Widget? tooltip;
              if (highlightIndex != null &&
                  highlightIndex >= 0 &&
                  highlightIndex < readings.length) {
                final anchor = points[highlightIndex];
                final value = readings[highlightIndex].moisture;
                const tooltipW = 60.0;
                const tooltipH = 24.0;
                final left = (anchor.dx - (tooltipW / 2))
                    .clamp(0.0, size.width - tooltipW);
                final top = (anchor.dy - tooltipH - 10)
                    .clamp(0.0, size.height - tooltipH);

                tooltip = Positioned(
                  left: left,
                  top: top,
                  width: tooltipW,
                  height: tooltipH,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        value.toStringAsFixed(0),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return MouseRegion(
                onExit: (_) => setHoverIndex(null),
                onHover: (event) => setHoverIndex(hitTest(event.localPosition)),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: paint),
                    if (tooltip != null) tooltip,
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

extension on MoistureHistoryChart {
  static Widget _placeholder(BuildContext context, String text) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          text,
          style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  static List<MoistureReading> _parseReadings(Object? raw) {
    if (raw is! Map) return const [];
    final readings = <MoistureReading>[];

    for (final entry in raw.entries) {
      final v = entry.value;
      if (v is! Map) continue;

      final moistureRaw = v['moisture'];
      final tsRaw = v['ts'];

      final moisture = switch (moistureRaw) {
        num n => n.toDouble(),
        String s => double.tryParse(s),
        _ => null,
      };
      if (moisture == null) continue;

      final ts = switch (tsRaw) {
        num n => n.toInt(),
        String s => int.tryParse(s),
        _ => null,
      };
      if (ts == null) continue;

      final tsMs = ts < 1000000000000 ? ts * 1000 : ts;
      readings.add(
        MoistureReading(
          time: DateTime.fromMillisecondsSinceEpoch(tsMs),
          moisture: moisture,
        ),
      );
    }

    readings.sort((a, b) => a.time.compareTo(b.time));
    return readings;
  }
}

class _MoistureChartScaler {
  const _MoistureChartScaler._({
    required this.chartRect,
    required this.minMoisture,
    required this.maxMoisture,
    required this.moistureRange,
    required this.minT,
    required this.tRange,
  });

  final Rect chartRect;
  final double minMoisture;
  final double maxMoisture;
  final double moistureRange;
  final int minT;
  final int tRange;

  static _MoistureChartScaler? tryCreate(
    List<MoistureReading> readings,
    Size size,
  ) {
    final chartRect = Rect.fromLTWH(
      44,
      12,
      math.max(0, size.width - 56),
      math.max(0, size.height - 42),
    );
    if (chartRect.width <= 1 || chartRect.height <= 1) return null;
    if (readings.isEmpty) return null;

    final minMoisture =
        readings.map((r) => r.moisture).reduce((a, b) => a < b ? a : b);
    final maxMoisture =
        readings.map((r) => r.moisture).reduce((a, b) => a > b ? a : b);
    final moistureRange = (maxMoisture - minMoisture).abs() < 0.0001
        ? 1.0
        : (maxMoisture - minMoisture);

    final minT = readings.first.time.millisecondsSinceEpoch;
    final maxT = readings.last.time.millisecondsSinceEpoch;
    final tRange = math.max(1, maxT - minT);

    return _MoistureChartScaler._(
      chartRect: chartRect,
      minMoisture: minMoisture,
      maxMoisture: maxMoisture,
      moistureRange: moistureRange,
      minT: minT,
      tRange: tRange,
    );
  }

  Offset point(MoistureReading r) {
    final x = chartRect.left +
        ((r.time.millisecondsSinceEpoch - minT) / tRange) * chartRect.width;
    final y = chartRect.bottom -
        ((r.moisture - minMoisture) / moistureRange) * chartRect.height;
    return Offset(x, y);
  }
}

class _MoistureChartPainter extends CustomPainter {
  _MoistureChartPainter({
    required this.readings,
    required this.lineColor,
    required this.gridColor,
    required this.labelStyle,
    required this.highlightIndex,
  });

  final List<MoistureReading> readings;
  final Color lineColor;
  final Color gridColor;
  final TextStyle labelStyle;
  final int? highlightIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final scaler = _MoistureChartScaler.tryCreate(readings, size);
    if (scaler == null) return;
    final chartRect = scaler.chartRect;
    final minMoisture = scaler.minMoisture;
    final maxMoisture = scaler.maxMoisture;

    final gridPaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Border
    canvas.drawRect(chartRect, gridPaint);

    // Horizontal grid lines
    for (var i = 1; i <= 3; i += 1) {
      final y = chartRect.top + (chartRect.height * i / 4);
      canvas.drawLine(
        Offset(chartRect.left, y),
        Offset(chartRect.right, y),
        gridPaint,
      );
    }

    Offset pt(MoistureReading r) {
      return scaler.point(r);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(pt(readings.first).dx, pt(readings.first).dy);
    for (final r in readings.skip(1)) {
      final p = pt(r);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);

    final pointPaint = Paint()..color = lineColor;
    for (var i = 0; i < readings.length; i += 1) {
      final r = readings[i];
      final p = pt(r);
      final isHighlight = highlightIndex != null && highlightIndex == i;
      canvas.drawCircle(p, isHighlight ? 4.5 : 2.5, pointPaint);
      if (isHighlight) {
        final ring = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;
        canvas.drawCircle(p, 3.0, ring);
        canvas.drawCircle(p, 4.5, pointPaint);
      }
    }

    // Labels: min/max moisture and start/end time.
    _paintText(
      canvas,
      maxMoisture.toStringAsFixed(0),
      Offset(6, chartRect.top - 4),
      labelStyle,
      alignRight: false,
    );
    _paintText(
      canvas,
      minMoisture.toStringAsFixed(0),
      Offset(6, chartRect.bottom - 12),
      labelStyle,
      alignRight: false,
    );

    final start = _formatTime(readings.first.time);
    final end = _formatTime(readings.last.time);

    _paintText(
      canvas,
      start,
      Offset(chartRect.left, chartRect.bottom + 6),
      labelStyle,
      alignRight: false,
    );
    _paintText(
      canvas,
      end,
      Offset(chartRect.right, chartRect.bottom + 6),
      labelStyle,
      alignRight: true,
    );
  }

  static void _paintText(
    Canvas canvas,
    String text,
    Offset origin,
    TextStyle style, {
    required bool alignRight,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 200);

    final offset =
        alignRight ? Offset(origin.dx - tp.width, origin.dy) : origin;
    tp.paint(canvas, offset);
  }

  static String _formatTime(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.month)}/${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }

  @override
  bool shouldRepaint(covariant _MoistureChartPainter oldDelegate) {
    return oldDelegate.readings != readings ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelStyle != labelStyle ||
        oldDelegate.highlightIndex != highlightIndex;
  }
}
