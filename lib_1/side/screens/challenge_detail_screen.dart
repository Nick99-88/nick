import 'package:flutter/material.dart';
import '../models/execution_result.dart';
import '../services/code_execution_service.dart';
import '../widgets/interactive_execution_terminal.dart';

class ChallengeDetailScreen extends StatefulWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  CodingChallenge? _challenge;
  bool _isLoading = true;
  bool _isSaved = false;

  // Reply editor
  final _replyCtrl = TextEditingController();
  bool _showReplyEditor = false;
  String? _editingReplyId;
  Key? _terminalKey;
  String? _lastRunCode;

  // Reply posting
  bool _isPosting = false;

  List<ChallengeReply> _replies = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadChallenge();
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadChallenge() async {
    setState(() => _isLoading = true);
    _challenge = await CodeExecutionService.getChallenge(widget.challengeId);
    if (_challenge != null) {
      _replyCtrl.text = _challenge!.starterCode.isNotEmpty
          ? _challenge!.starterCode
          : _defaultCode(_challenge!.language);
      _isSaved = _challenge!.isSaved;
      _loadReplies();
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadReplies() async {
    final r = await CodeExecutionService.getReplies(widget.challengeId);
    if (mounted) setState(() => _replies = r);
  }

  String _defaultCode(String lang) {
    switch (lang) {
      case 'python': return '# Write your solution here\n';
      case 'javascript': return '// Write your solution here\n';
      case 'java': return 'public class Main {\n    public static void main(String[] args) {\n        \n    }\n}\n';
      case 'c': return '#include <stdio.h>\n\nint main() {\n    \n    return 0;\n}\n';
      default: return '';
    }
  }

  Future<void> _toggleSave() async {
    if (_challenge == null) return;
    final ok = _isSaved
        ? await CodeExecutionService.unsaveChallenge(widget.challengeId)
        : await CodeExecutionService.saveChallenge(widget.challengeId);
    if (ok && mounted) setState(() => _isSaved = !_isSaved);
  }

  void _onRun() {
    setState(() {
      _lastRunCode = _replyCtrl.text;
      _terminalKey = UniqueKey();
    });
  }

  Future<void> _postReply() async {
    if (_challenge == null || _replyCtrl.text.trim().isEmpty) return;
    setState(() => _isPosting = true);

    final ChallengeReply? reply;
    if (_editingReplyId != null) {
      reply = await CodeExecutionService.updateReply(
        challengeId: widget.challengeId,
        replyId: _editingReplyId!,
        code: _replyCtrl.text,
        language: _challenge!.language,
        status: 'submitted',
      );
    } else {
      reply = await CodeExecutionService.saveReplyOnly(
        challengeId: widget.challengeId,
        code: _replyCtrl.text,
        language: _challenge!.language,
        status: 'submitted',
      );
    }

    if (mounted) {
      setState(() {
        _isPosting = false;
        if (reply != null) {
          _showReplyEditor = false;
          _editingReplyId = null;
          _terminalKey = null;
          _lastRunCode = null;
        }
      });
      if (reply != null) {
        _loadReplies();
        _tabController.animateTo(1);
      } else {
        _showError(_editingReplyId != null ? 'Failed to update reply' : 'Failed to post reply');
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: const Color(0xFFFF5555)),
    );
  }

  void _runReply(ChallengeReply reply) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      builder: (ctx) => _ReplyRunSheet(code: reply.code, language: reply.language),
    );
  }

  void _loadReplyInEditor(ChallengeReply reply) {
    _replyCtrl.text = reply.code;
    setState(() {
      _showReplyEditor = true;
      _editingReplyId = reply.id;
    });
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF282A36),
        foregroundColor: const Color(0xFFF8F8F2),
        elevation: 0,
        title: Text(_challenge?.title ?? 'Challenge',
            style: const TextStyle(fontSize: 14, fontFamily: 'monospace')),
        actions: [
          if (_challenge != null) ...[
            IconButton(
              icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: const Color(0xFFFFB86C), size: 20),
              onPressed: _toggleSave,
              tooltip: _isSaved ? 'Unsave' : 'Save',
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF50FA7B),
          labelColor: const Color(0xFF50FA7B),
          unselectedLabelColor: const Color(0xFF6272A4),
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
          tabs: const [
            Tab(text: 'Problem'),
            Tab(text: 'Solutions'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF50FA7B)))
          : _challenge == null
              ? const Center(child: Text('Challenge not found',
                  style: TextStyle(color: Color(0xFF6272A4), fontFamily: 'monospace')))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProblemTab(),
                    _buildRepliesTab(),
                  ],
                ),
    );
  }

  // ── Problem Tab ──

  Widget _buildProblemTab() {
    return Column(
      children: [
        Expanded(
          flex: _showReplyEditor ? 2 : 4,
          child: _buildProblemPanel(),
        ),
        if (!_showReplyEditor)
          _buildStartReplyButton()
        else
          Expanded(
            flex: 3,
            child: _buildReplySection(),
          ),
      ],
    );
  }

  Widget _buildReplySection() {
    return Column(
      children: [
        Expanded(
          flex: _terminalKey != null ? 1 : 2,
          child: _buildReplyEditor(),
        ),
        _buildReplyActions(),
        if (_terminalKey != null)
          Expanded(
            flex: 2,
            child: _buildReplyTerminal(),
          ),
      ],
    );
  }

  Widget _buildProblemPanel() {
    final c = _challenge!;
    final diffColor = c.difficulty == 'Easy'
        ? const Color(0xFF50FA7B)
        : c.difficulty == 'Medium'
            ? const Color(0xFFFFB86C)
            : const Color(0xFFFF5555);

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF282A36),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _badge(c.difficulty, diffColor),
              const SizedBox(width: 6),
              _badge(c.language.toUpperCase(), const Color(0xFFBD93F9)),
            ]),
            const SizedBox(height: 12),
            const Text('Description',
                style: TextStyle(color: Color(0xFF8BE9FD), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            const SizedBox(height: 6),
            Text(c.description,
                style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 13, height: 1.5, fontFamily: 'monospace')),
            if (c.hint.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Hint',
                  style: TextStyle(color: Color(0xFFFFB86C), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(height: 6),
              Text(c.hint,
                  style: TextStyle(color: Color(0xFFF8F8F2).withOpacity(0.7), fontSize: 12, fontFamily: 'monospace', height: 1.4)),
            ],
            if (c.testCases.isNotEmpty && c.testCases.any((t) => t.isNotEmpty)) ...[
              const SizedBox(height: 14),
              const Text('Test Cases',
                  style: TextStyle(color: Color(0xFFBD93F9), fontSize: 11, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const SizedBox(height: 6),
              ...List.generate(c.testCases.length, (i) {
                if (c.testCases[i].isEmpty) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2E),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Test ${i + 1}',
                          style: const TextStyle(color: Color(0xFF6272A4), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                      const SizedBox(height: 4),
                      Text('Input: ${c.testCases[i]}',
                          style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 11, fontFamily: 'monospace')),
                      if (i < c.expectedOutputs.length && c.expectedOutputs[i].isNotEmpty)
                        Text('Expected: ${c.expectedOutputs[i]}',
                            style: const TextStyle(color: Color(0xFF50FA7B), fontSize: 11, fontFamily: 'monospace')),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStartReplyButton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: GestureDetector(
        onTap: () => setState(() {
          _showReplyEditor = true;
          _editingReplyId = null;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF50FA7B).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF50FA7B).withOpacity(0.3)),
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.code, size: 16, color: Color(0xFF50FA7B)),
                SizedBox(width: 8),
                Text('Write a Solution',
                    style: TextStyle(color: Color(0xFF50FA7B), fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyEditor() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF44475A)),
      ),
      child: TextField(
        controller: _replyCtrl,
        maxLines: null,
        expands: true,
        style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 13, fontFamily: 'monospace', height: 1.5),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(12),
        ),
        cursorColor: const Color(0xFF50FA7B),
      ),
    );
  }

  Widget _buildReplyActions() {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Row(children: [
        GestureDetector(
          onTap: _replyCtrl.text.trim().isEmpty ? null : _onRun,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF50FA7B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow, size: 16, color: Color(0xFF1E1E2E)),
              SizedBox(width: 6),
              Text('Run',
                  style: TextStyle(color: Color(0xFF1E1E2E), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: _isPosting || _replyCtrl.text.trim().isEmpty ? null : _postReply,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _isPosting ? const Color(0xFFFFB86C) : const Color(0xFFBD93F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isPosting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1E1E2E)))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.send, size: 16, color: Color(0xFF1E1E2E)),
                    SizedBox(width: 6),
                    Text(_editingReplyId != null ? 'Update Reply' : 'Post Reply',
                        style: TextStyle(color: Color(0xFF1E1E2E), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                  ]),
          ),
        ),
        const SizedBox(width: 8),
        Text('${_challenge!.language.toUpperCase()}',
            style: const TextStyle(color: Color(0xFF6272A4), fontSize: 11, fontFamily: 'monospace')),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() {
            _showReplyEditor = false;
            _editingReplyId = null;
            _terminalKey = null;
            _lastRunCode = null;
          }),
          child: const Icon(Icons.close, size: 18, color: Color(0xFF6272A4)),
        ),
      ]),
    );
  }

  Widget _buildReplyTerminal() {
    final code = _lastRunCode ?? _replyCtrl.text;
    return InteractiveExecutionTerminal(
      key: _terminalKey,
      code: code,
      language: _challenge!.language,
    );
  }

  // ── Solutions Tab ──

  Widget _buildRepliesTab() {
    if (_replies.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 50, color: Color(0xFF44475A)),
            const SizedBox(height: 16),
            const Text('No solutions yet',
                style: TextStyle(color: Color(0xFF6272A4), fontSize: 14, fontFamily: 'monospace')),
            const SizedBox(height: 8),
            Text('Tap "Write a Solution" to submit one',
                style: const TextStyle(color: Color(0xFF44475A), fontSize: 12, fontFamily: 'monospace')),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _replies.length,
      itemBuilder: (_, i) => _buildReplyCard(_replies[i]),
    );
  }

  Widget _buildReplyCard(ChallengeReply r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF282A36),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(children: [
              Icon(Icons.person, size: 14, color: const Color(0xFFBD93F9)),
              const SizedBox(width: 6),
              Text(r.username,
                  style: const TextStyle(color: Color(0xFFF8F8F2), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
              const Spacer(),
              Text(_formatTime(r.createdAt),
                  style: const TextStyle(color: Color(0xFF44475A), fontSize: 10, fontFamily: 'monospace')),
            ]),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(6),
            ),
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: SelectableText(r.code,
                  style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 12, fontFamily: 'monospace', height: 1.4)),
            ),
          ),
          if (r.output != null && r.output!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF50FA7B).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Output',
                      style: TextStyle(color: Color(0xFF6272A4), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  SelectableText(r.output!,
                      style: const TextStyle(color: Color(0xFF50FA7B), fontSize: 12, fontFamily: 'monospace', height: 1.3)),
                ],
              ),
            ),
          if (r.error != null && r.error!.isNotEmpty)
            Container(
              margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF5555).withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Error',
                      style: TextStyle(color: Color(0xFF6272A4), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(height: 4),
                  SelectableText(r.error!,
                      style: const TextStyle(color: Color(0xFFFF5555), fontSize: 12, fontFamily: 'monospace', height: 1.3)),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(children: [
              GestureDetector(
                onTap: () => _runReply(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF50FA7B).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow, size: 12, color: Color(0xFF50FA7B)),
                    SizedBox(width: 4),
                    Text('Run',
                        style: TextStyle(color: Color(0xFF50FA7B), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _loadReplyInEditor(r),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFBD93F9).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit, size: 12, color: Color(0xFFBD93F9)),
                    SizedBox(width: 4),
                    Text('Edit',
                        style: TextStyle(color: Color(0xFFBD93F9), fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  ]),
                ),
              ),
              if (r.executionTimeMs > 0) ...[
                const Spacer(),
                Text('${r.executionTimeMs}ms',
                    style: const TextStyle(color: Color(0xFF6272A4), fontSize: 10, fontFamily: 'monospace')),
              ],
            ]),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
    );
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ── Bottom Sheet for running a reply ──

class _ReplyRunSheet extends StatefulWidget {
  final String code;
  final String language;

  const _ReplyRunSheet({required this.code, required this.language});

  @override
  State<_ReplyRunSheet> createState() => _ReplyRunSheetState();
}

class _ReplyRunSheetState extends State<_ReplyRunSheet> {
  Key _runKey = UniqueKey();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: const BoxDecoration(
              color: Color(0xFF282A36),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(children: [
              const Text('Run Solution',
                  style: TextStyle(color: Color(0xFFF8F8F2), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: const Icon(Icons.close, size: 20, color: Color(0xFF6272A4)),
              ),
            ]),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF282A36),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(maxHeight: 150),
            child: SingleChildScrollView(
              child: SelectableText(widget.code,
                  style: const TextStyle(color: Color(0xFFF8F8F2), fontSize: 12, fontFamily: 'monospace', height: 1.4)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(children: [
              GestureDetector(
                onTap: () => setState(() => _runKey = UniqueKey()),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF50FA7B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.play_arrow, size: 14, color: Color(0xFF1E1E2E)),
                    SizedBox(width: 4),
                    Text('Run',
                        style: TextStyle(color: Color(0xFF1E1E2E), fontWeight: FontWeight.bold, fontSize: 12, fontFamily: 'monospace')),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Text(widget.language.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF6272A4), fontSize: 11, fontFamily: 'monospace')),
            ]),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: InteractiveExecutionTerminal(
              key: _runKey,
              code: widget.code,
              language: widget.language,
            ),
          ),
        ],
      ),
    );
  }
}
