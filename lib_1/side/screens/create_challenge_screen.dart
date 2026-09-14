import 'package:flutter/material.dart';
import '../services/code_execution_service.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _hintCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _testInputCtrls = <TextEditingController>[];
  final _testOutputCtrls = <TextEditingController>[];
  bool _isCreating = false;

  String _difficulty = 'Easy';
  String _language = 'python';
  String _challengeType = 'open';

  final _difficulties = ['Easy', 'Medium', 'Hard'];
  final _languages = ['python', 'javascript', 'c', 'java'];
  final _types = [
    {'id': 'open', 'label': 'Open (any solution)'},
    {'id': 'fixed', 'label': 'Fixed (exact output)'},
    {'id': 'competitive', 'label': 'Competitive (hidden tests)'},
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _hintCtrl.dispose();
    _codeCtrl.dispose();
    for (final c in _testInputCtrls) c.dispose();
    for (final c in _testOutputCtrls) c.dispose();
    super.dispose();
  }

  void _addTestCase() {
    setState(() {
      _testInputCtrls.add(TextEditingController());
      _testOutputCtrls.add(TextEditingController());
    });
  }

  void _removeTestCase(int i) {
    setState(() {
      _testInputCtrls[i].dispose();
      _testOutputCtrls[i].dispose();
      _testInputCtrls.removeAt(i);
      _testOutputCtrls.removeAt(i);
    });
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) {
      _showError('Title is required');
      return;
    }

    setState(() => _isCreating = true);

    final tests = _testInputCtrls.map((c) => c.text).toList();
    final outputs = _testOutputCtrls.map((c) => c.text).toList();
    while (tests.length > outputs.length) outputs.add('');
    while (outputs.length > tests.length) tests.add('');

    final challenge = await CodeExecutionService.createChallenge(
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      difficulty: _difficulty,
      language: _language,
      hint: _hintCtrl.text.trim(),
      starterCode: _codeCtrl.text,
      testCases: tests,
      expectedOutputs: outputs,
      challengeType: _challengeType,
    );

    setState(() => _isCreating = false);

    if (challenge != null && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      _showError('Failed to create challenge');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFFF5555)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF282A36),
        foregroundColor: const Color(0xFFF8F8F2),
        elevation: 0,
        title: const Text('Create Challenge',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        actions: [
          GestureDetector(
            onTap: _isCreating ? null : _create,
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _isCreating ? const Color(0xFFFFB86C) : const Color(0xFF50FA7B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isCreating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E1E2E)))
                  : const Text('Create',
                      style: TextStyle(color: Color(0xFF1E1E2E), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _label('Title'),
            _field(_titleCtrl, 'e.g. Two Sum'),
            const SizedBox(height: 14),
            _label('Description'),
            _field(_descCtrl, 'Describe the challenge...', maxLines: 4),
            const SizedBox(height: 14),
            _label('Hint'),
            _field(_hintCtrl, 'Optional hint for solvers'),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: _dropdown('Difficulty', _difficulty, _difficulties, (v) => _difficulty = v)),
              const SizedBox(width: 12),
              Expanded(child: _dropdown('Language', _language, _languages, (v) => _language = v)),
            ]),
            const SizedBox(height: 14),
            _dropdown('Challenge Type', _challengeType, _types.map((t) => t['id']!).toList(), (v) => _challengeType = v),
            const SizedBox(height: 14),
            _label('Starter Code'),
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: const Color(0xFF282A36),
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextField(
                controller: _codeCtrl,
                maxLines: null,
                expands: true,
                style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 13, fontFamily: 'monospace', height: 1.5),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(12),
                ),
                cursorColor: const Color(0xFF50FA7B),
              ),
            ),
            const SizedBox(height: 18),
            Row(children: [
              _label('Test Cases'),
              const Spacer(),
              GestureDetector(
                onTap: _addTestCase,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBD93F9).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.add, size: 14, color: Color(0xFFBD93F9)),
                    SizedBox(width: 4),
                    Text('Add Test',
                        style: TextStyle(color: Color(0xFFBD93F9), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (_testInputCtrls.isEmpty)
              GestureDetector(
                onTap: _addTestCase,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282A36),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF44475A)),
                  ),
                  child: const Center(
                    child: Text('+ Add test case',
                        style: TextStyle(color: Color(0xFF6272A4), fontSize: 12, fontFamily: 'monospace')),
                  ),
                ),
              ),
            ...List.generate(_testInputCtrls.length, (i) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF282A36),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text('Test ${i + 1}',
                          style: const TextStyle(
                              color: Color(0xFFBD93F9), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _removeTestCase(i),
                        child: const Icon(Icons.close, size: 16, color: Color(0xFFFF5555)),
                      ),
                    ]),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _testInputCtrls[i],
                      style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 12, fontFamily: 'monospace'),
                      decoration: _inputDec(hint: 'Input (stdin)'),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _testOutputCtrls[i],
                      style: const TextStyle(color: Color(0xFF50FA7B), fontSize: 12, fontFamily: 'monospace'),
                      decoration: _inputDec(hint: 'Expected output'),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                color: Color(0xFFBD93F9), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
      );

  Widget _field(TextEditingController c, String hint, {int maxLines = 1}) => TextField(
        controller: c,
        maxLines: maxLines,
        style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 13, fontFamily: 'monospace'),
        decoration: _inputDec(hint: hint),
        cursorColor: const Color(0xFF50FA7B),
      );

  InputDecoration _inputDec({String hint = ''}) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF44475A), fontSize: 13),
        filled: true,
        fillColor: const Color(0xFF282A36),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  Widget _dropdown(String label, String value, List<String> items, void Function(String) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF282A36),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF282A36),
              style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 13, fontFamily: 'monospace'),
              items: items.map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
              onChanged: (v) {
                if (v != null) setState(() => onChanged(v));
              },
            ),
          ),
        ),
      ],
    );
  }
}
