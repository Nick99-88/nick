import 'package:flutter/material.dart';

const String codingIdeFeatureKey = 'coding_ide';
const IconData codingIdeFeatureIcon = Icons.code;
const String codingIdeFeatureTitle = 'Coding IDE';
const String codingIdeFeatureSubtitle = 'Write, run, and test code right in your browser with powerful tools.';

List<Map<String, dynamic>> get codingIdeIntroSteps => [
  {
    'icon': Icons.code_rounded,
    'title': 'Write Code',
    'description': 'Type code in a clean editor with syntax highlighting and auto-suggestions for multiple languages.',
    'color': const Color(0xFF1A237E),
  },
  {
    'icon': Icons.play_arrow_rounded,
    'title': 'Run & Test',
    'description': 'Execute your code instantly and see the output in real time without leaving the app.',
    'color': const Color(0xFF283593),
  },
  {
    'icon': Icons.bug_report_rounded,
    'title': 'Debug & Learn',
    'description': 'Find and fix errors easily with built-in debugging tools and clear error messages.',
    'color': const Color(0xFF3F51B5),
  },
  {
    'icon': Icons.terminal_rounded,
    'title': 'Full Terminal',
    'description': 'Access a full terminal with command-line tools for advanced development workflows.',
    'color': const Color(0xFF5C6BC0),
  },
];