import 'dart:async';
import 'package:adaptive_career_roadmap_builder/shared/animated_background.dart';
import 'package:flutter/material.dart';

class LoadingRoadPage extends StatefulWidget {
  final Future<String> Function() taskFactory;
  final void Function(String result) onDone;

  const LoadingRoadPage({
    super.key,
    required this.taskFactory,
    required this.onDone,
  });

  @override
  State<LoadingRoadPage> createState() => LoadingRoadPageState();
}

class LoadingRoadPageState extends State<LoadingRoadPage>
    with TickerProviderStateMixin {
  late final AnimationController dashCtrl;
  late final Timer cycleTimer;
  int quoteIndex = 0;
  int iconIndex = 0;

  int _attempts = 0;
  String? _errorMsg;
  bool _isRunning = false;

  final List<String> quotes = const [
    'Constructing the future...',
    'Paving a path forward...',
    'Mapping the next turn...',
    'Setting milestones ahead...',
    'Fueling the journey...',
    'Calibrating the compass...',
    'Merging ideas into motion...',
    'Clearing roadblocks...',
    'Switching lanes to opportunity...',
    'Cruising toward clarity...',
    'Drafting the blueprint...',
    'Navigating the unknown...',
    'Tuning the engine of growth...',
  ];

  final List<IconData> icons = const [
    Icons.construction,
    Icons.map,
    Icons.timeline,
    Icons.bolt,
    Icons.explore,
    Icons.merge,
    Icons.cleaning_services,
    Icons.alt_route,
    Icons.directions_car,
    Icons.draw,
    Icons.travel_explore,
    Icons.build_circle,
  ];

  @override
  void initState() {
    super.initState();

    dashCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    cycleTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      setState(() {
        quoteIndex = (quoteIndex + 1) % quotes.length;
        iconIndex = (iconIndex + 1) % icons.length;
      });
    });

    _runTask();
  }

  Future<void> _runTask() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _errorMsg = null;
    });

    _attempts += 1;

    try {
      final res = await widget.taskFactory();
      if (!mounted) return;
      widget.onDone(res);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  void dispose() {
    dashCtrl.dispose();
    cycleTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canRetry = _attempts < 7;
    final showGiveItTime = !canRetry && _errorMsg != null;

    return SharedAnimatedBackground(
      builder: (context, color) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icons[iconIndex],
                        size: 56,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        quotes[quoteIndex],
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 4,
                        child: AnimatedBuilder(
                          animation: dashCtrl,
                          builder: (context, _) {
                            return LinearProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white.withValues(alpha: 0.9),
                              ),
                              backgroundColor:
                                  Colors.white.withValues(alpha: 0.2),
                            );
                          },
                        ),
                      ),
                      if (_errorMsg != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.15),
                            border: Border.all(
                                color: Colors.redAccent.withValues(alpha: 0.6)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Model overloaded or request failed.',
                                style: TextStyle(
                                  color:
                                      Colors.redAccent.withValues(alpha: 0.9),
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              if (showGiveItTime)
                                Text(
                                  'Please try again after a few minutes.',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  textAlign: TextAlign.center,
                                )
                              else
                                Text(
                                  'Tap Retry to try again. Attempts: $_attempts/7',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: (!_isRunning && canRetry)
                                        ? _runTask
                                        : null,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
