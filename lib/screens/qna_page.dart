// lib/screens/qna_page.dart
import 'package:adaptive_career_roadmap_builder/screens/roadmap_page.dart';
import 'package:adaptive_career_roadmap_builder/shared/animated_background.dart';
import 'package:adaptive_career_roadmap_builder/screens/loading_road_page.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:adaptive_career_roadmap_builder/shared/local_store.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- Data Models ---
abstract class Question {
  final String text;
  const Question(this.text);
}

class TextQuestion extends Question {
  const TextQuestion(super.text);
}

class McqQuestion extends Question {
  final List<String> options;
  const McqQuestion(super.text, this.options);
}

// --- Page ---
class QnaPage extends StatefulWidget {
  const QnaPage({super.key});

  @override
  State<QnaPage> createState() => _QnaPageState();
}

class _QnaPageState extends State<QnaPage> with TickerProviderStateMixin {
  final List<Question> _questions = const [
    McqQuestion(
      "First, which of these best describes your current stage?",
      [
        "High School Student",
        "University Student",
        "Early Career Professional (0-5 years)",
        "Mid-Career Professional (Exploring a change)",
        "Experienced Professional (5+ years)",
      ],
    ),
    TextQuestion(
      "If you could spend a whole day completely absorbed in a topic (forgetting to eat or sleep), what would that topic be?",
    ),
    McqQuestion(
      "When faced with a major project, you are most likely to...",
      [
        "Organize and plan every step in detail first.",
        "Brainstorm creative, out-of-the-box ideas.",
        "Collaborate and delegate tasks within a team.",
        "Jump in and start building or experimenting right away.",
      ],
    ),
    TextQuestion(
      "Describe an achievement that made you feel genuinely proud. What was it, and what made it so satisfying?",
    ),
    McqQuestion(
      "Looking ahead, which of these is your most important long-term career value?",
      [
        "Financial Security & Stability",
        "Making a Positive Social Impact",
        "Creative Freedom & Expression",
        "Leadership & Influence",
      ],
    ),
    TextQuestion(
      "Finally, imagine your life in 10 years. What problem are you passionate about solving, for yourself or for others?",
    ),
  ];

  int _currentQuestionIndex = 0;
  bool _isReviewing = false;

  final Map<int, String> _answers = {};
  final TextEditingController _textController = TextEditingController();
  bool _isLoading = false;

  // Saved panel state
  bool _showSavedPanel = false;
  List<SavedRoadmap> _saved = [];
  late final AnimationController _panelCtrl;
  late final Animation<double> _panelAnim;

  @override
  void initState() {
    super.initState();
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _panelAnim = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeInOut);
    _refreshSaved();
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    _textController.dispose();
    super.dispose();
  }

  Future<void> _refreshSaved() async {
    final list = await LocalStore.listAll();
    if (!mounted) return;
    setState(() => _saved = list);
  }

  void _toggleSavedPanel() async {
    if (_showSavedPanel) {
      await _panelCtrl.reverse();
    } else {
      await _refreshSaved();
      await _panelCtrl.forward();
    }
    if (!mounted) return;
    setState(() => _showSavedPanel = !_showSavedPanel);
  }

  Future<void> _logout() async {
    try {
      // 1) Close the panel to avoid overlay remnants
      if (_showSavedPanel) {
        await _panelCtrl.reverse();
        if (mounted) setState(() => _showSavedPanel = false);
      }

      // 2) Sign out providers
      await FirebaseAuth.instance.signOut();
      // If Supabase auth is used anywhere, also sign it out:
      // await Supabase.instance.client.auth.signOut();

      if (!mounted) return;

      // 3) Return to the root so AuthGate (StreamBuilder) can rebuild to WelcomePage
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Optional: show feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signed out')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to sign out: $e')),
      );
    }
  }

  Future<void> _deleteRoadmap(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        title: const Text('Delete this roadmap?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await LocalStore.deleteById(id);
      await _refreshSaved();
    }
  }

  void _nextQuestion() {
    _saveCurrentAnswer();
    if (_currentQuestionIndex < _questions.length - 1) {
      setState(() {
        _currentQuestionIndex++;
        _textController.text = _answers[_currentQuestionIndex] ?? '';
      });
    } else {
      setState(() {
        _isReviewing = true;
      });
    }
  }

  void _previousQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _saveCurrentAnswer();
        _currentQuestionIndex--;
        _textController.text = _answers[_currentQuestionIndex] ?? '';
      });
    }
  }

  void _selectMcqOption(String option) {
    setState(() {
      _answers[_currentQuestionIndex] = option;
    });
  }

  void _editSpecificAnswer(int index) {
    setState(() {
      _isReviewing = false;
      _currentQuestionIndex = index;
      _textController.text = _answers[index] ?? '';
    });
  }

  void _saveCurrentAnswer() {
    final currentQuestion = _questions[_currentQuestionIndex];
    if (currentQuestion is TextQuestion) {
      _answers[_currentQuestionIndex] = _textController.text;
    }
  }

  String _buildPrompt() {
    final formattedAnswers = _questions.asMap().entries.map((entry) {
      final index = entry.key;
      final question = entry.value;
      final answer = _answers[index] ?? "No answer provided.";
      return "Question: ${question.text}\nAnswer: $answer";
    }).join("\n\n");

    return """
You are an expert career counselor. Based on the following Q&A, create a personalized career roadmap with concrete, actionable steps.

USER'S ANSWERS:
$formattedAnswers

Output policy (must follow exactly):
- Produce between 8 and 10 steps total (no fewer than 8, no more than 10).
- Do not use markdown headers (#), horizontal rules (---), or code blocks.
- Use this exact structure and nothing else, repeating for each step (Step 1, Step 2, ..., Step N):
Step N: <Title>
Description: <one short paragraph>
Tasks:
- <task 1>
- <task 2>
- <task 3>
""";
  }

  Future<String> _invokeGenerate(String prompt) async {
    final response = await Supabase.instance.client.functions.invoke(
      'generate-roadmap',
      body: {'prompt': prompt},
    );
    if (response.status != 200) {
      throw Exception('Model overloaded or request failed: ${response.data}');
    }
    return response.data.toString();
  }

  Future<void> _generateRoadmap() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final prompt = _buildPrompt();
    Future<String> taskFactory() => _invokeGenerate(prompt);

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => LoadingRoadPage(
          taskFactory: taskFactory,
          onDone: (rawResponse) async {
            // Close loader if visible
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
            // Save new entry and open
            await LocalStore.saveNew(rawResponse);
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => RoadmapPage(roadmapText: rawResponse),
              ),
            );
          },
        ),
      ),
    );

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return SharedAnimatedBackground(builder: (context, color) {
      final view =
          _isReviewing ? _buildReviewView(color) : _buildQuestionView(color);
      return Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text("Tell us about you"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: ActionChip(
                avatar: const Icon(Icons.folder_open,
                    size: 18, color: Color(0xFFE0E1DD)),
                label: const Text('Your roadmaps'),
                labelStyle: const TextStyle(color: Color(0xFFE0E1DD)),
                backgroundColor: Colors.white.withAlpha(26),
                side: BorderSide(color: color.withAlpha(120)),
                onPressed: _toggleSavedPanel,
              ),
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizeTransition(
                      sizeFactor: _panelAnim,
                      axisAlignment: -1.0,
                      child: _SavedPanel(
                        items: _saved,
                        accent: color,
                        onRefresh: _refreshSaved,
                        onOpen: (text) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => RoadmapPage(roadmapText: text)),
                          );
                        },
                        onDelete: _deleteRoadmap,
                        onLogout: _logout, // sign out here
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: view,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildQuestionView(Color color) {
    final question = _questions[_currentQuestionIndex];
    return Column(
      key: ValueKey('question_$_currentQuestionIndex'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          question.text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFFE0E1DD),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 40),
        if (question is TextQuestion)
          TextField(
            controller: _textController,
            maxLines: 5,
            style: const TextStyle(color: Color(0xFFE0E1DD)),
            decoration: InputDecoration(
              hintText: "Your thoughts here...",
              hintStyle: const TextStyle(color: Color(0xFFB0B3B8)),
              filled: true,
              fillColor: Colors.black.withAlpha(76),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        if (question is McqQuestion)
          Column(
            children: question.options.map((option) {
              final isSelected = _answers[_currentQuestionIndex] == option;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: OutlinedButton(
                  onPressed: () => _selectMcqOption(option),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        isSelected ? color : const Color(0xFFE0E1DD),
                    backgroundColor: isSelected
                        ? color.withAlpha(40)
                        : Colors.white.withAlpha(26),
                    side: BorderSide(
                        color: isSelected ? color : Colors.white.withAlpha(51)),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0)),
                  ),
                  child: Text(option),
                ),
              );
            }).toList(),
          ),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentQuestionIndex > 0)
              TextButton.icon(
                onPressed: _previousQuestion,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Back"),
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFE0E1DD)),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: _currentQuestionIndex == _questions.length - 1
                  ? _generateRoadmap
                  : _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: color.withAlpha(153),
                foregroundColor: const Color(0xFFE0E1DD),
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30.0)),
              ),
              child: Text(
                _currentQuestionIndex == _questions.length - 1
                    ? "Generate"
                    : "Next",
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewView(Color color) {
    return Column(
      key: const ValueKey('review'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _questions.length,
          itemBuilder: (context, index) {
            final question = _questions[index];
            final answer = _answers[index] ?? "Not answered";
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            question.text,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE0E1DD),
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.white70),
                          onPressed: () => _editSpecificAnswer(index),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      answer,
                      style: TextStyle(
                        color: color,
                        fontSize: 16,
                        fontStyle: answer == "Not answered"
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _generateRoadmap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color.withAlpha(153),
              foregroundColor: const Color(0xFFE0E1DD),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30.0)),
            ),
            icon: _isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(
              _isLoading ? 'Generating...' : 'Generate Roadmap',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedPanel extends StatelessWidget {
  final List<SavedRoadmap> items;
  final Color accent;
  final VoidCallback onRefresh;
  final void Function(String text) onOpen;
  final Future<void> Function(String id) onDelete;
  final Future<void> Function() onLogout;

  const _SavedPanel({
    required this.items,
    required this.accent,
    required this.onRefresh,
    required this.onOpen,
    required this.onDelete,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(64),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withAlpha(120)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your roadmaps',
                  style: TextStyle(
                    color: Color(0xFFE0E1DD),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout, size: 18, color: Colors.white70),
                label: const Text('Logout',
                    style: TextStyle(color: Colors.white70)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text(
                'No saved roadmaps yet.',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else ...[
            for (final r in items) ...[
              _SavedItem(
                item: r,
                accent: accent,
                onOpen: onOpen,
                onDelete: onDelete,
              ),
              const SizedBox(height: 8),
            ],
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Refresh'),
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SavedItem extends StatelessWidget {
  final SavedRoadmap item;
  final Color accent;
  final void Function(String text) onOpen;
  final Future<void> Function(String id) onDelete;

  const _SavedItem({
    required this.item,
    required this.accent,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final ts =
        '${item.createdAt.year}-${item.createdAt.month.toString().padLeft(2, '0')}-${item.createdAt.day.toString().padLeft(2, '0')} '
        '${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withAlpha(100)),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFE0E1DD),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ts,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open',
            onPressed: () => onOpen(item.text),
            icon: const Icon(Icons.open_in_new, color: Colors.white70),
          ),
          IconButton(
            tooltip: 'Delete',
            onPressed: () => onDelete(item.id),
            icon: const Icon(Icons.delete, color: Colors.redAccent),
          ),
        ],
      ),
    );
  }
}
