import 'package:adaptive_career_roadmap_builder/screens/auth_page.dart';
import 'package:flutter/material.dart';
import '../shared/animated_background.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  // Keys to identify the UI widgets.
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _buttonKey = GlobalKey();

  // Variables to store the position and size of the widgets.
  Rect? _headerBounds;
  Rect? _buttonBounds;

  @override
  void initState() {
    super.initState();
    // Calculate the bounds of the UI elements after the first frame is drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) => _getUIBounds());
  }

  void _getUIBounds() {
    if (!mounted) return;
    final RenderBox? headerBox =
        _headerKey.currentContext?.findRenderObject() as RenderBox?;
    final RenderBox? buttonBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;

    if (headerBox != null && buttonBox != null) {
      setState(() {
        // Store the bounds, inflating them slightly to create a buffer zone.
        _headerBounds = (headerBox.localToGlobal(Offset.zero) & headerBox.size)
            .inflate(20.0);
        _buttonBounds = (buttonBox.localToGlobal(Offset.zero) & buttonBox.size)
            .inflate(20.0);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // This page uses the reusable animated background component.
    return SharedAnimatedBackground(
      // Pass the bounds of the UI elements to the background.
      uiElementBounds: [_headerBounds, _buttonBounds],
      // The builder provides the dynamic color from the animation.
      builder: (context, color) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 40.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(flex: 2),
                    _buildHeader(color),
                    const Spacer(flex: 3),
                    _buildGetStartedButton(context, color),
                    const Spacer(flex: 1),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color color) {
    return Column(
      key: _headerKey, // Assign the key to the header widget.
      children: [
        Icon(
          Icons.auto_graph_rounded,
          size: 80,
          color: color,
        ),
        const SizedBox(height: 24),
        const Text(
          'CareerCompass',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Color(0xFFE0E1DD),
              height: 1.2,
              shadows: [
                Shadow(
                    color: Colors.black38, blurRadius: 10, offset: Offset(0, 2))
              ]),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your Adaptive Career Roadmap Builder',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 19,
              color: Color(0xFFE0E1DD),
              height: 1.5),
        ),
        const SizedBox(height: 20),
        const Text(
          'Craft your unique path to success. We analyze your interests and skills to generate a personalized roadmap to set you on the highway to making your dream into your ',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              color: Color.fromARGB(171, 224, 225, 221),
              height: 1.5),
        ),
        const Text(
          'career.',
          textAlign: TextAlign.center,
          style: TextStyle(
              fontFamily: 'Inter-bold',
              fontSize: 17,
              color: Color.fromARGB(255, 224, 225, 221),
              height: 1.5),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildGetStartedButton(BuildContext context, Color color) {
    return Container(
      key: _buttonKey, // Assign the key to the button's container.
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withAlpha(153), // 0.6 opacity
          foregroundColor: const Color(0xFFE0E1DD),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30.0)),
          elevation: 8,
          shadowColor: color.withAlpha(128), // 0.5 opacity
        ),
        onPressed: () {
          // Navigate to the authentication page.
          Navigator.of(context)
              .push(MaterialPageRoute(builder: (context) => const AuthPage()));
        },
        child: const Text('Get Started',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
