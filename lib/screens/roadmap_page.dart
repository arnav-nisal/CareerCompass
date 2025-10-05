// lib/screens/roadmap_page.dart
import 'dart:async';
import 'package:adaptive_career_roadmap_builder/shared/animated_background.dart';
import 'package:flutter/material.dart';
import 'package:adaptive_career_roadmap_builder/shared/local_store.dart';
import 'package:adaptive_career_roadmap_builder/screens/qna_page.dart';

class RoadmapPage extends StatefulWidget {
  final String roadmapText;
  const RoadmapPage({super.key, required this.roadmapText});

  @override
  State<RoadmapPage> createState() => _RoadmapPageState();
}

class _RoadmapPageState extends State<RoadmapPage>
    with TickerProviderStateMixin {
  late final List<String> _blocks; // Step blocks
  final ScrollController _scroll = ScrollController();

  final List<AnimationController> _controllers = [];
  final List<Animation<double>> _fadeAnims = [];
  final List<Animation<Offset>> _slideAnims = [];

  bool _allShown = false;

  static const double _cardsMaxWidth = 800.0;
  static const double _horizontalPagePadding = 16.0;

  @override
  void initState() {
    super.initState();
    final cleaned = _cleanText(widget.roadmapText);
    _blocks = _splitIntoBlocks(cleaned);
    _setupStepAnimations();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _waitForAttachThenRun());
  }

  void _waitForAttachThenRun() {
    if (!mounted) return;
    if (_scroll.hasClients) {
      _runSequence();
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _waitForAttachThenRun());
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  void _setupStepAnimations() {
    final count = _blocks.length;
    for (int i = 0; i < count; i++) {
      final c = AnimationController(
          vsync: this, duration: const Duration(milliseconds: 500));
      final fade = CurvedAnimation(parent: c, curve: Curves.easeInOut);
      final slide =
          Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero)
              .animate(fade);
      _controllers.add(c);
      _fadeAnims.add(fade);
      _slideAnims.add(slide);
    }
  }

  Future<void> _runSequence() async {
    for (int i = 0; i < _blocks.length; i++) {
      if (!mounted) return;
      _controllers[i].forward();
      await Future.delayed(const Duration(milliseconds: 200));
      await _autoScrollBy(stepIndex: i);
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (mounted) setState(() => _allShown = true);
  }

  Future<void> _autoScrollBy({required int stepIndex}) async {
    if (!_scroll.hasClients) return;
    final maxExtent = _scroll.position.maxScrollExtent;
    if (maxExtent <= 0) return;
    final target = (_scroll.offset + 180).clamp(0.0, maxExtent);
    if (target == _scroll.offset) return;
    await _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  String _cleanText(String input) {
    final lines = input
        .replaceAll('\r', '')
        .split('\n')
        .map((l) => l
            .replaceFirst(
                RegExp(r'^\s*(#{1,6}|\*|>|\-|\u2022|\u25CF|\u25E6|\u2043)\s*'),
                '')
            .trimRight())
        .toList();

    final filtered = lines
        .where((l) => !RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(l.trim()))
        .toList();

    final collapsed = <String>[];
    bool lastBlank = false;
    for (final l in filtered) {
      final isBlank = l.trim().isEmpty;
      if (isBlank && lastBlank) continue;
      collapsed.add(l);
      lastBlank = isBlank;
    }

    return collapsed.join('\n').trim();
  }

  List<String> _splitIntoBlocks(String text) {
    if (text.isEmpty) return [];
    final blocks = text
        .split(RegExp(r'\n\s*\n'))
        .map((b) => b.trim())
        .where((b) => b.isNotEmpty)
        .toList();

    final merged = <String>[];
    for (final b in blocks) {
      if (merged.isEmpty || b.toLowerCase().startsWith('step ')) {
        merged.add(b);
      } else {
        merged.last = '${merged.last}\n\n$b';
      }
    }
    return merged;
  }

  Future<void> _handleSaveAndStartNew() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        title: const Text('Save and start new?'),
        content: const Text(
            'This will save the current roadmap and then start a fresh one.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save & start')),
        ],
      ),
    );

    if (confirmed == true) {
      await LocalStore.saveNew(widget.roadmapText);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const QnaPage()),
      );
    }
  }

  Future<void> _confirmStartFresh() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        title: const Text('Start a new roadmap?'),
        content: const Text('This will discard changes and start fresh.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Start fresh')),
        ],
      ),
    );
    if (confirmed == true) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const QnaPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SharedAnimatedBackground(builder: (context, color) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Your Career Roadmap"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            PopupMenuButton<String>(
              tooltip: 'Roadmap options',
              icon: const Icon(Icons.more_vert),
              onSelected: (v) async {
                if (v == 'save_new') {
                  await _handleSaveAndStartNew();
                } else if (v == 'start_new') {
                  await _confirmStartFresh();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'save_new',
                  child: ListTile(
                    leading: Icon(Icons.save_alt),
                    title: Text('Save & start new'),
                  ),
                ),
                PopupMenuItem(
                  value: 'start_new',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Start fresh'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _VerticalRoadPainter(
                  laneColor: Colors.black.withValues(alpha: 0.35),
                  dashColor: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ),
            SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPagePadding, vertical: 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: _cardsMaxWidth),
                  child: Column(
                    children: [
                      const SizedBox(height: 80),
                      for (int i = 0; i < _blocks.length; i++) ...[
                        _RoadStepCard(
                          index: i + 1,
                          text: _blocks[i],
                          fade: _fadeAnims[i],
                          slide: _slideAnims[i],
                        ),
                        const SizedBox(height: 120),
                      ],
                      const SizedBox(height: 140),
                    ],
                  ),
                ),
              ),
            ),
            if (_allShown)
              Positioned(
                right: 16,
                bottom: 16,
                child: _AdaptiveFab(
                  onPressed: () => _showFullDialog(context),
                  baseColor: color,
                ),
              ),
          ],
        ),
      );
    });
  }

  void _showFullDialog(BuildContext context) {
    final fullText = _blocks.join('\n\n');
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 600),
          child: SingleChildScrollView(
            child: SelectableText(
              fullText,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 16, height: 1.6),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoadStepCard extends StatelessWidget {
  final int index;
  final String text;
  final Animation<double> fade;
  final Animation<Offset> slide;

  const _RoadStepCard({
    required this.index,
    required this.text,
    required this.fade,
    required this.slide,
  });

  @override
  Widget build(BuildContext context) {
    final themeColor =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.6);
    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: themeColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _buildStepContent(context, text),
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, String t) {
    final lines = t.split('\n');
    final titleLine = lines.isNotEmpty ? lines.first.trim() : 'Step $index';
    final rest = lines.length > 1 ? lines.sublist(1).join('\n').trim() : '';

    final themeColor =
        Theme.of(context).colorScheme.primary.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleLine.isNotEmpty ? titleLine : 'Step $index',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE0E1DD),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 1.5,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                themeColor.withAlpha(80),
                themeColor,
                themeColor.withAlpha(80),
              ],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          rest,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15.5,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _VerticalRoadPainter extends CustomPainter {
  final Color laneColor;
  final Color dashColor;

  _VerticalRoadPainter({required this.laneColor, required this.dashColor});

  @override
  void paint(Canvas canvas, Size size) {
    const double pagePad = _RoadmapPageState._horizontalPagePadding;
    const double maxCards = _RoadmapPageState._cardsMaxWidth;

    final usableWidth = (size.width - pagePad * 2).clamp(0.0, double.infinity);
    final cardsWidth = usableWidth < maxCards ? usableWidth : maxCards;
    final cardsLeft = (size.width - cardsWidth) / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(cardsLeft, 0, cardsWidth, size.height),
      const Radius.circular(18),
    );

    final roadPaint = Paint()..color = laneColor;
    canvas.drawRRect(rect, roadPaint);

    final dashPaint = Paint()
      ..color = dashColor
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final centerX = cardsLeft + cardsWidth / 2;
    const dashHeight = 16.0;
    const dashGap = 12.0;

    double y = 12;
    while (y < size.height) {
      canvas.drawLine(
          Offset(centerX, y), Offset(centerX, y + dashHeight), dashPaint);
      y += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalRoadPainter oldDelegate) {
    return oldDelegate.laneColor != laneColor ||
        oldDelegate.dashColor != dashColor;
  }
}

class _AdaptiveFab extends StatelessWidget {
  final VoidCallback onPressed;
  final Color baseColor;

  const _AdaptiveFab({required this.onPressed, required this.baseColor});

  @override
  Widget build(BuildContext context) {
    final bg = baseColor.withValues(alpha: 0.6);
    final isDark = bg.computeLuminance() < 0.5;
    final fg = isDark ? const Color(0xFFE0E1DD) : Colors.black87;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: Colors.transparent,
            foregroundColor: fg,
            extendedTextStyle:
                TextStyle(color: fg, fontWeight: FontWeight.w600),
          ),
        ),
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: Colors.transparent,
          foregroundColor: fg,
          icon: const Icon(Icons.text_snippet),
          label: const Text("Full roadmap"),
          elevation: 0,
        ),
      ),
    );
  }
}
