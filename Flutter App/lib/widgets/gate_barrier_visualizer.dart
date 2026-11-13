import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Ultra-smooth 60fps Custom Painter & Animated Visualizer for the Gate Barrier.
/// Accurately mirrors physical servo motor rotation (0° closed to 90° raised).
class GateBarrierVisualizer extends StatelessWidget {
  final bool isOpen;
  final int servoAngle;
  final double autoCloseRemaining;
  final bool isControlling;

  const GateBarrierVisualizer({
    super.key,
    required this.isOpen,
    required this.servoAngle,
    this.autoCloseRemaining = 0.0,
    this.isControlling = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targetValue = isOpen ? 1.0 : 0.0;

    return AspectRatio(
      aspectRatio: 16 / 9.5,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    const Color(0xFF131A2A),
                    const Color(0xFF0C111C),
                  ]
                : [
                    const Color(0xFFF1F5F9),
                    const Color(0xFFE2E8F0),
                  ],
          ),
          border: Border.all(
            color: isOpen
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.locked.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: (isOpen ? AppColors.success : AppColors.locked)
                  .withValues(alpha: isDark ? 0.12 : 0.06),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(21),
          child: Stack(
            children: [
              // 1. Vector Drawn Road, Pedestal and Rotating Boom
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: targetValue, end: targetValue),
                duration: const Duration(milliseconds: 650),
                curve: Curves.easeInOutCubic,
                builder: (context, animValue, _) {
                  return CustomPaint(
                    painter: _GateBarrierPainter(
                      openProgress: animValue,
                      isDark: isDark,
                    ),
                    size: Size.infinite,
                  );
                },
              ),

              // 2. Top-Left Gate State Badge
              Positioned(
                top: 12,
                left: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isOpen ? AppColors.success : AppColors.locked)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: (isOpen ? AppColors.success : AppColors.locked)
                          .withValues(alpha: 0.5),
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isOpen ? AppColors.success : AppColors.locked,
                          boxShadow: [
                            BoxShadow(
                              color: isOpen ? AppColors.success : AppColors.locked,
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOpen ? 'BARRIER OPEN' : 'BARRIER CLOSED',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                          color: isOpen ? AppColors.success : AppColors.locked,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 3. Top-Right Servo Angle & Countdown Overlay
              Positioned(
                top: 12,
                right: 14,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Servo Angle Chip
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.rotate_right_rounded,
                            size: 13,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$servoAngle°',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Auto-close countdown circular badge (shown when open)
                    if (isOpen && autoCloseRemaining > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warningBg.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning, width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.warning),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Auto-close ${autoCloseRemaining.toStringAsFixed(1)}s',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // 4. Loading Shimmer Overlay when gate command is in-flight
              if (isControlling)
                Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GateBarrierPainter extends CustomPainter {
  final double openProgress; // 0.0 (closed) to 1.0 (fully open 90 deg)
  final bool isDark;

  _GateBarrierPainter({
    required this.openProgress,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // Baseline road surface
    final groundY = height * 0.78;

    // Draw Asphalt Road Surface
    final roadPaint = Paint()
      ..color = isDark ? const Color(0xFF182234) : const Color(0xFFCBD5E1);
    canvas.drawRect(Rect.fromLTWH(0, groundY, width, height - groundY), roadPaint);

    // Draw Curb / Safety Line
    final curbPaint = Paint()
      ..color = isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8)
      ..strokeWidth = 3;
    canvas.drawLine(Offset(0, groundY), Offset(width, groundY), curbPaint);

    // Draw Road Dashed Centerlines
    final dashPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFF475569)).withValues(alpha: 0.25)
      ..strokeWidth = 2.5;
    const dashWidth = 14.0;
    const dashSpace = 10.0;
    double startX = width * 0.32;
    final dashY = groundY + (height - groundY) * 0.5;
    while (startX < width - 10) {
      canvas.drawLine(Offset(startX, dashY), Offset(startX + dashWidth, dashY), dashPaint);
      startX += dashWidth + dashSpace;
    }

    // Pedestal dimensions (Left side housing)
    final pedestalW = width * 0.15;
    final pedestalH = height * 0.44;
    final pedestalX = width * 0.10;
    final pedestalY = groundY - pedestalH;

    // Pedestal Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(pedestalX - 4, groundY - 4, pedestalW + 8, 8),
        const Radius.circular(4),
      ),
      shadowPaint,
    );

    // Pedestal Body Gradient
    final pedestalRect = Rect.fromLTWH(pedestalX, pedestalY, pedestalW, pedestalH);
    final pedestalPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF334155), const Color(0xFF1E293B)]
            : [const Color(0xFF64748B), const Color(0xFF334155)],
      ).createShader(pedestalRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(pedestalRect, const Radius.circular(10)),
      pedestalPaint,
    );

    // Pedestal Status LED on cabinet
    final ledY = pedestalY + pedestalH * 0.32;
    final ledX = pedestalX + pedestalW * 0.5;
    final ledColor = openProgress > 0.5 ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final ledPaint = Paint()..color = ledColor;
    canvas.drawCircle(Offset(ledX, ledY), 4, ledPaint);

    final ledGlow = Paint()
      ..color = ledColor.withValues(alpha: 0.4)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(Offset(ledX, ledY), 8, ledGlow);

    // Pivot Point on Cabinet
    final pivotX = pedestalX + pedestalW * 0.65;
    final pivotY = pedestalY + pedestalH * 0.22;

    // Draw Articulated Barrier Arm
    // Closed: angle = 0 rad. Open: angle = -pi / 2 rad (-90 deg)
    final currentAngle = -openProgress * (math.pi / 2);

    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.rotate(currentAngle);

    final boomLength = width * 0.62;
    const boomThickness = 12.0;

    // Boom arm drop shadow
    final boomShadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 4, 0, 0),
        const Radius.circular(3),
      ),
      boomShadow,
    );

    // Boom Main Background (White)
    final boomWhite = Paint()..color = Colors.white;
    final boomRect = const Rect.fromLTWH(0, -boomThickness / 2, 0, boomThickness);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, -boomThickness / 2, boomLength, boomThickness),
        const Radius.circular(5),
      ),
      boomWhite,
    );

    // Boom High-Visibility Red Reflective Stripes (Diagonal)
    final stripePaint = Paint()..color = const Color(0xFFDC2626);
    const stripeWidth = 18.0;
    const stripeInterval = 32.0;
    double s = 16.0;
    while (s + stripeWidth < boomLength - 8) {
      final stripePath = Path()
        ..moveTo(s, -boomThickness / 2)
        ..lineTo(s + 10, -boomThickness / 2)
        ..lineTo(s + 10 - 6, boomThickness / 2)
        ..lineTo(s - 6, boomThickness / 2)
        ..close();
      canvas.drawPath(stripePath, stripePaint);
      s += stripeInterval;
    }

    // Boom Arm Tip End Cap & LED Warning Dot
    final tipCap = Paint()..color = const Color(0xFF1E293B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(boomLength - 8, -boomThickness / 2, 8, boomThickness),
        const Radius.circular(2),
      ),
      tipCap,
    );

    final tipLed = Paint()..color = ledColor;
    canvas.drawCircle(Offset(boomLength - 4, 0), 2.5, tipLed);

    canvas.restore();

    // Draw Pivot Cap Hub (Metallic ring over pivot)
    final hubBorder = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pivotX, pivotY), 9, hubBorder);

    final hubCenter = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawCircle(Offset(pivotX, pivotY), 5.5, hubCenter);
  }

  @override
  bool shouldRepaint(covariant _GateBarrierPainter oldDelegate) {
    return oldDelegate.openProgress != openProgress || oldDelegate.isDark != isDark;
  }
}
