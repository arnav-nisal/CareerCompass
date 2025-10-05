import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';

// A class to manage the state and shape of a single blob.
class Blob {
  Offset position;
  Offset velocity;
  final double radius;
  final int numPoints;
  final Random random;
  // State for smoothly transitioning opacity.
  double currentOpacity = 0.8;
  double targetOpacity = 0.8;

  late List<double> _radiusOffsets;
  late List<double> _targetRadiusOffsets;

  Blob({
    required this.position,
    required this.velocity,
    required this.radius,
    required this.random,
    this.numPoints = 12,
  }) {
    // Initialize the blob's shape.
    _radiusOffsets = List.generate(numPoints, (i) => radius);
    _targetRadiusOffsets = List.generate(numPoints, (i) => radius);
    _generateNewTargetShape(); // Create the first target shape.
  }

  // Generates a new random, irregular shape for the blob to morph into.
  void _generateNewTargetShape() {
    for (int i = 0; i < numPoints; i++) {
      _targetRadiusOffsets[i] =
          random.nextDouble() * radius * 0.8 + radius * 0.6;
    }
  }

  // Updates the blob's shape and opacity smoothly each frame.
  void update() {
    for (int i = 0; i < numPoints; i++) {
      _radiusOffsets[i] += (_targetRadiusOffsets[i] - _radiusOffsets[i]) * 0.03;
    }
    // Smoothly animate the opacity towards its target.
    currentOpacity += (targetOpacity - currentOpacity) * 0.05;
  }
}

// The main reusable widget for the animated background.
class SharedAnimatedBackground extends StatefulWidget {
  // A builder function that provides the current color to the child widget.
  final Widget Function(BuildContext context, Color color) builder;
  // A list of rectangular bounds for UI elements to avoid.
  final List<Rect?> uiElementBounds;

  const SharedAnimatedBackground({
    super.key,
    required this.builder,
    this.uiElementBounds = const [],
  });

  @override
  State<SharedAnimatedBackground> createState() =>
      _SharedAnimatedBackgroundState();
}

class _SharedAnimatedBackgroundState extends State<SharedAnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _backgroundController;
  late AnimationController _colorController;
  late Animation<Color?> _colorAnimation;

  int _colorIndex = 0;
  final List<Color> _glowColors = [
    Colors.cyan,
    Colors.purple,
    Colors.greenAccent,
    Colors.orange,
    Colors.pink,
  ];

  final List<Blob> _blobs = [];
  final _random = Random();
  Timer? _shapeChangeTimer;

  @override
  void initState() {
    super.initState();

    // Controller for the blob movement animation.
    _backgroundController =
        AnimationController(vsync: this, duration: const Duration(seconds: 10))
          ..addListener(_updateBlobs);

    // Controller for the smooth color transition.
    _colorController =
        AnimationController(vsync: this, duration: const Duration(seconds: 12));
    _colorAnimation = ColorTween(
      begin: _glowColors[_colorIndex],
      end: _glowColors[(_colorIndex + 1) % _glowColors.length],
    ).animate(_colorController);

    _colorController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _colorIndex = (_colorIndex + 1) % _glowColors.length;
          _colorAnimation = ColorTween(
            begin: _glowColors[_colorIndex],
            end: _glowColors[(_colorIndex + 1) % _glowColors.length],
          ).animate(_colorController);
        });
        _colorController.forward(from: 0.0);
      }
    });
    _colorController.forward();

    // Timer to trigger blob shape changes periodically.
    _shapeChangeTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      for (final blob in _blobs) {
        blob._generateNewTargetShape();
      }
    });

    // Initialize blobs after the first frame is rendered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      for (int i = 0; i < 3; i++) {
        _blobs.add(Blob(
          position: Offset(_random.nextDouble() * size.width,
              _random.nextDouble() * size.height),
          velocity: Offset(_random.nextDouble() * 0.8 - 0.4,
              _random.nextDouble() * 0.8 - 0.4),
          radius: size.width / 3.5,
          random: _random,
        ));
      }
      _backgroundController.repeat();
    });
  }

  // The main animation loop for updating blob positions and opacity.
  void _updateBlobs() {
    if (!mounted) return;
    final size = MediaQuery.of(context).size;
    setState(() {
      for (final blob in _blobs) {
        // Check for overlap with any of the provided UI element bounds.
        bool isOverlapping = false;
        final blobRect =
            Rect.fromCircle(center: blob.position, radius: blob.radius * 0.8);
        for (final bounds in widget.uiElementBounds) {
          if (bounds != null && bounds.overlaps(blobRect)) {
            isOverlapping = true;
            break;
          }
        }
        // Set the target opacity based on whether the blob is overlapping.
        blob.targetOpacity = isOverlapping ? 0.2 : 0.8;

        blob.update(); // Update shape and opacity.

        // Add random wandering motion.
        blob.velocity += Offset(_random.nextDouble() * 0.1 - 0.05,
            _random.nextDouble() * 0.1 - 0.05);
        blob.velocity = Offset(
          blob.velocity.dx.clamp(-0.5, 0.5),
          blob.velocity.dy.clamp(-0.5, 0.5),
        );
        blob.position += blob.velocity;

        // Bounce off the screen edges.
        if (blob.position.dx < blob.radius * 0.5 ||
            blob.position.dx > size.width - blob.radius * 0.5) {
          blob.velocity = Offset(-blob.velocity.dx, blob.velocity.dy);
        }
        if (blob.position.dy < blob.radius * 0.5 ||
            blob.position.dy > size.height - blob.radius * 0.5) {
          blob.velocity = Offset(blob.velocity.dx, -blob.velocity.dy);
        }
      }
    });
  }

  @override
  void dispose() {
    _backgroundController.removeListener(_updateBlobs);
    _backgroundController.dispose();
    _colorController.dispose();
    _shapeChangeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        final currentColor = _colorAnimation.value ?? _glowColors[0];
        return Scaffold(
          body: Stack(
            children: [
              // The custom painter that draws the animated blobs.
              Positioned.fill(
                child: CustomPaint(
                  painter: AnimatedBackgroundPainter(
                    blobs: _blobs,
                    glowColor: currentColor,
                  ),
                ),
              ),
              // Use the builder to pass the current color to the page content.
              widget.builder(context, currentColor),
            ],
          ),
        );
      },
    );
  }
}

// Custom Painter for the glowing blob animation.
class AnimatedBackgroundPainter extends CustomPainter {
  final List<Blob> blobs;
  final Color glowColor;

  AnimatedBackgroundPainter({required this.blobs, required this.glowColor});

  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in blobs) {
      final glowPaint = Paint()
        ..color = glowColor
            .withAlpha((255 * blob.currentOpacity).toInt()) // Use withAlpha
        ..style = PaintingStyle.fill
        // A less intensive blur to prevent performance issues.
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60.0);

      final path = Path();
      final points = <Offset>[];
      for (int i = 0; i < blob.numPoints; i++) {
        final angle = (i / blob.numPoints) * 2 * pi;
        final radius = blob._radiusOffsets[i];
        points.add(Offset(
          blob.position.dx + cos(angle) * radius,
          blob.position.dy + sin(angle) * radius,
        ));
      }

      if (points.isEmpty) continue;

      // Create a smooth, closed curve from the points.
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 1; i < points.length; i++) {
        final p2 = points[i];
        final p1 = points[i - 1];
        path.quadraticBezierTo(
            p1.dx, p1.dy, (p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      }
      final firstPoint = points.first;
      final lastPoint = points.last;
      path.quadraticBezierTo(
          lastPoint.dx,
          lastPoint.dy,
          (lastPoint.dx + firstPoint.dx) / 2,
          (lastPoint.dy + firstPoint.dy) / 2);

      canvas.drawPath(path, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
