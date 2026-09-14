import 'package:flutter/material.dart';

class LanguageModel {
  final String id;
  final String name;
  final String extension;
  final IconData icon;
  final Color color;
  final String defaultCode;
  final bool isCompiled;

  const LanguageModel({
    required this.id,
    required this.name,
    required this.extension,
    required this.icon,
    required this.color,
    required this.defaultCode,
    this.isCompiled = false,
  });
}

class SupportedLanguages {
  static const List<LanguageModel> languages = [
    LanguageModel(
      id: 'python',
      name: 'Python',
      extension: '.py',
      icon: Icons.code,
      color: Color(0xFF3776AB),
      defaultCode: '''# Welcome to Starlight IDE
# NumPy & Pandas are ready to use

import numpy as np
import pandas as pd

def hello():
    print("Hello, Starlight!")

if __name__ == "__main__":
    hello()
''',
    ),
    LanguageModel(
      id: 'javascript',
      name: 'JavaScript',
      extension: '.js',
      icon: Icons.javascript,
      color: Color(0xFFF7DF1E),
      defaultCode: '''// Welcome to Starlight IDE
// Start coding in JavaScript

function hello() {
    console.log("Hello, Starlight!");
}

hello();
''',
    ),
    LanguageModel(
      id: 'html',
      name: 'HTML/CSS',
      extension: '.html',
      icon: Icons.web,
      color: Color(0xFFE34F26),
      defaultCode: '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Starlight Web</title>
  <style>
    body { font-family: sans-serif; text-align: center; }
    h1 { color: #1A237E; }
  </style>
</head>
<body>
  <h1>Hello, Starlight!</h1>
</body>
</html>
''',
    ),
    LanguageModel(
      id: 'cpp',
      name: 'C/C++',
      extension: '.c',
      icon: Icons.code,
      color: Color(0xFF00599C),
      defaultCode: '''#include <stdio.h>

int main() {
    printf("Hello, Starlight!\\n");
    return 0;
}
''',
      isCompiled: true,
    ),
    LanguageModel(
      id: 'java',
      name: 'Java',
      extension: '.java',
      icon: Icons.coffee,
      color: Color(0xFFED8B00),
      defaultCode: '''public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, Starlight!");
    }
}
''',
      isCompiled: true,
    ),
  ];

  static LanguageModel? getById(String id) {
    try {
      return languages.firstWhere((lang) => lang.id == id);
    } catch (_) {
      return null;
    }
  }
}
