/// Question types supported by the scanning system
enum QuestionType {
  mcq,
  short,
  long,
  fill,
  trueFalse,
  match,
  essay,
  unknown
}

/// Difficulty levels for questions
enum Difficulty {
  easy,
  medium,
  hard,
  unknown
}

/// Sub-question for questions with parts
class SubQuestion {
  String part;
  String text;
  int marks;
  
  SubQuestion({
    required this.part,
    required this.text,
    required this.marks,
  });

  factory SubQuestion.fromJson(Map<String, dynamic> json) {
    return SubQuestion(
      part: json['part']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      marks: json['marks']?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'part': part,
      'text': text,
      'marks': marks,
    };
  }
}

/// Main question model
class ScannedQuestion {
  String id;
  int questionNumber;
  QuestionType type;
  String questionText;
  List<String> options; // For MCQ questions
  int marks;
  Difficulty difficulty;
  String topic;
  List<SubQuestion> subQuestions;
  bool isSelected;
  String? imageData; // Base64 encoded image of this specific question
  
  ScannedQuestion({
    required this.id,
    required this.questionNumber,
    required this.type,
    required this.questionText,
    this.options = const [],
    required this.marks,
    required this.difficulty,
    required this.topic,
    this.subQuestions = const [],
    this.isSelected = false,
    this.imageData,
  });

  factory ScannedQuestion.fromJson(Map<String, dynamic> json) {
    // Parse question type
    QuestionType type = QuestionType.unknown;
    String? typeStr = json['type']?.toString()?.toLowerCase();
    switch (typeStr) {
      case 'mcq':
        type = QuestionType.mcq;
        break;
      case 'short':
        type = QuestionType.short;
        break;
      case 'long':
        type = QuestionType.long;
        break;
      case 'fill':
        type = QuestionType.fill;
        break;
      case 'truefalse':
      case 'true_false':
        type = QuestionType.trueFalse;
        break;
      case 'match':
        type = QuestionType.match;
        break;
      case 'essay':
        type = QuestionType.essay;
        break;
    }

    // Parse difficulty
    Difficulty difficulty = Difficulty.unknown;
    String? difficultyStr = json['difficulty']?.toString()?.toLowerCase();
    switch (difficultyStr) {
      case 'easy':
        difficulty = Difficulty.easy;
        break;
      case 'medium':
        difficulty = Difficulty.medium;
        break;
      case 'hard':
        difficulty = Difficulty.hard;
        break;
    }

    // Parse sub-questions
    List<SubQuestion> subQuestions = [];
    if (json['subQuestions'] != null) {
      subQuestions = (json['subQuestions'] as List)
          .map((sq) => SubQuestion.fromJson(sq))
          .toList();
    }

    // Parse options
    List<String> options = [];
    if (json['options'] != null) {
      options = (json['options'] as List)
          .map((opt) => opt.toString())
          .toList();
    }

    return ScannedQuestion(
      id: json['id']?.toString() ?? '',
      questionNumber: json['questionNumber']?.toInt() ?? 0,
      type: type,
      questionText: json['questionText']?.toString() ?? '',
      options: options,
      marks: json['marks']?.toInt() ?? 0,
      difficulty: difficulty,
      topic: json['topic']?.toString() ?? '',
      subQuestions: subQuestions,
      isSelected: json['isSelected']?.toBool() ?? false,
      imageData: json['imageData'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'questionNumber': questionNumber,
      'type': type.name,
      'questionText': questionText,
      'options': options,
      'marks': marks,
      'difficulty': difficulty.name,
      'topic': topic,
      'subQuestions': subQuestions.map((sq) => sq.toJson()).toList(),
      'isSelected': isSelected,
      'imageData': imageData,
    };
  }

  /// Get total marks including sub-questions
  int get totalMarks {
    if (subQuestions.isNotEmpty) {
      return subQuestions.fold(0, (sum, sq) => sum + sq.marks);
    }
    return marks;
  }

  /// Get display text for question type
  String get typeDisplay {
    switch (type) {
      case QuestionType.mcq:
        return 'Multiple Choice';
      case QuestionType.short:
        return 'Short Answer';
      case QuestionType.long:
        return 'Long Answer';
      case QuestionType.fill:
        return 'Fill in the Blanks';
      case QuestionType.trueFalse:
        return 'True/False';
      case QuestionType.match:
        return 'Match the Following';
      case QuestionType.essay:
        return 'Essay';
      case QuestionType.unknown:
        return 'Unknown';
    }
  }

  /// Get display text for difficulty
  String get difficultyDisplay {
    switch (difficulty) {
      case Difficulty.easy:
        return 'Easy';
      case Difficulty.medium:
        return 'Medium';
      case Difficulty.hard:
        return 'Hard';
      case Difficulty.unknown:
        return 'Unknown';
    }
  }

  /// Create a copy with updated selection status
  ScannedQuestion copyWithSelection(bool selected) {
    return ScannedQuestion(
      id: id,
      questionNumber: questionNumber,
      type: type,
      questionText: questionText,
      options: options,
      marks: marks,
      difficulty: difficulty,
      topic: topic,
      subQuestions: subQuestions,
      isSelected: selected,
      imageData: imageData,
    );
  }
}

/// Paper information model
class PaperInfo {
  String title;
  int totalQuestions;
  int maxMarks;
  String duration;
  String instructions;
  String subject;
  String grade;
  
  PaperInfo({
    this.title = '',
    this.totalQuestions = 0,
    this.maxMarks = 0,
    this.duration = '',
    this.instructions = '',
    this.subject = '',
    this.grade = '',
  });

  factory PaperInfo.fromJson(Map<String, dynamic> json) {
    return PaperInfo(
      title: json['title']?.toString() ?? '',
      totalQuestions: json['totalQuestions']?.toInt() ?? 0,
      maxMarks: json['maxMarks']?.toInt() ?? 0,
      duration: json['duration']?.toString() ?? '',
      instructions: json['instructions']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      grade: json['grade']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'totalQuestions': totalQuestions,
      'maxMarks': maxMarks,
      'duration': duration,
      'instructions': instructions,
      'subject': subject,
      'grade': grade,
    };
  }

  /// Create a copy with updated fields
  PaperInfo copyWith({
    String? title,
    int? totalQuestions,
    int? maxMarks,
    String? duration,
    String? instructions,
    String? subject,
    String? grade,
  }) {
    return PaperInfo(
      title: title ?? this.title,
      totalQuestions: totalQuestions ?? this.totalQuestions,
      maxMarks: maxMarks ?? this.maxMarks,
      duration: duration ?? this.duration,
      instructions: instructions ?? this.instructions,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
    );
  }
}

/// Complete scanned paper model
class ScannedPaper {
  String id;
  PaperInfo paperInfo;
  List<ScannedQuestion> questions;
  DateTime scannedAt;
  String? originalImagePath;
  String? base64Image;
  
  ScannedPaper({
    required this.id,
    required this.paperInfo,
    required this.questions,
    required this.scannedAt,
    this.originalImagePath,
    this.base64Image,
  });

  factory ScannedPaper.fromJson(Map<String, dynamic> json) {
    return ScannedPaper(
      id: json['id']?.toString() ?? '',
      paperInfo: PaperInfo.fromJson(json['paperInfo'] ?? {}),
      questions: (json['questions'] as List?)
          ?.map((q) => ScannedQuestion.fromJson(q))
          .toList() ?? [],
      scannedAt: DateTime.parse(json['scannedAt']?.toString() ?? DateTime.now().toIso8601String()),
      originalImagePath: json['originalImagePath'],
      base64Image: json['base64Image'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'paperInfo': paperInfo.toJson(),
      'questions': questions.map((q) => q.toJson()).toList(),
      'scannedAt': scannedAt.toIso8601String(),
      'originalImagePath': originalImagePath,
      'base64Image': base64Image,
    };
  }

  /// Get only selected questions
  List<ScannedQuestion> get selectedQuestions {
    return questions.where((q) => q.isSelected).toList();
  }

  /// Get total marks of selected questions
  int get selectedTotalMarks {
    return selectedQuestions.fold(0, (sum, q) => sum + q.totalMarks);
  }

  /// Get count of selected questions
  int get selectedCount {
    return selectedQuestions.length;
  }

  /// Create a copy with updated questions
  ScannedPaper copyWithUpdatedQuestions(List<ScannedQuestion> updatedQuestions) {
    return ScannedPaper(
      id: id,
      paperInfo: paperInfo,
      questions: updatedQuestions,
      scannedAt: scannedAt,
      originalImagePath: originalImagePath,
      base64Image: base64Image,
    );
  }
}
