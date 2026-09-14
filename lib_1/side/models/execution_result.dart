enum ExecutionStatus {
  success,
  error,
  running,
  pending,
  timeout,
}

class ExecutionResult {
  final String output;
  final String? error;
  final ExecutionStatus status;
  final Duration executionTime;
  final DateTime executedAt;

  ExecutionResult({
    required this.output,
    this.error,
    required this.status,
    required this.executionTime,
    required this.executedAt,
  });

  factory ExecutionResult.success({
    required String output,
    required Duration executionTime,
  }) {
    return ExecutionResult(
      output: output,
      status: ExecutionStatus.success,
      executionTime: executionTime,
      executedAt: DateTime.now(),
    );
  }

  factory ExecutionResult.error({
    required String error,
    required Duration executionTime,
  }) {
    return ExecutionResult(
      output: '',
      error: error,
      status: ExecutionStatus.error,
      executionTime: executionTime,
      executedAt: DateTime.now(),
    );
  }

  factory ExecutionResult.timeout() {
    return ExecutionResult(
      output: '',
      error: 'Execution timed out (30s limit)',
      status: ExecutionStatus.timeout,
      executionTime: const Duration(seconds: 30),
      executedAt: DateTime.now(),
    );
  }

  bool get isSuccess => status == ExecutionStatus.success;
  bool get hasError => status == ExecutionStatus.error || status == ExecutionStatus.timeout;

  String get formattedTime {
    if (executionTime.inMilliseconds < 1000) {
      return '${executionTime.inMilliseconds}ms';
    }
    return '${(executionTime.inMilliseconds / 1000).toStringAsFixed(2)}s';
  }

  Map<String, dynamic> toJson() => {
        'output': output,
        'error': error,
        'status': status.name,
        'executionTimeMs': executionTime.inMilliseconds,
        'executedAt': executedAt.toIso8601String(),
      };

  factory ExecutionResult.fromJson(Map<String, dynamic> json) {
    return ExecutionResult(
      output: json['output'] ?? '',
      error: json['error'],
      status: ExecutionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ExecutionStatus.error,
      ),
      executionTime: Duration(milliseconds: json['executionTimeMs'] ?? 0),
      executedAt: DateTime.tryParse(json['executedAt'] ?? '') ?? DateTime.now(),
    );
  }
}

class CodingChallenge {
  final String id;
  final String title;
  final String description;
  final String difficulty;
  final String language;
  final List<String> testCases;
  final List<String> expectedOutputs;
  final String hint;
  final String starterCode;
  final String challengeType;
  final String createdBy;
  final DateTime createdAt;
  final bool isSaved;

  CodingChallenge({
    required this.id,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.language,
    required this.testCases,
    required this.expectedOutputs,
    this.hint = '',
    this.starterCode = '',
    this.challengeType = 'open',
    this.createdBy = '',
    DateTime? createdAt,
    this.isSaved = false,
  }) : createdAt = createdAt ?? DateTime.now();

  factory CodingChallenge.fromJson(Map<String, dynamic> json) {
    return CodingChallenge(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      difficulty: json['difficulty'] ?? 'Easy',
      language: json['language'] ?? 'python',
      testCases: List<String>.from(json['testCases'] ?? []),
      expectedOutputs: List<String>.from(json['expectedOutputs'] ?? []),
      hint: json['hint'] ?? '',
      starterCode: json['starterCode'] ?? '',
      challengeType: json['challengeType'] ?? 'open',
      createdBy: json['createdBy'] ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
      isSaved: json['isSaved'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'difficulty': difficulty,
        'language': language,
        'testCases': testCases,
        'expectedOutputs': expectedOutputs,
        'hint': hint,
        'starterCode': starterCode,
        'challengeType': challengeType,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'isSaved': isSaved,
      };
}

class ChallengeReply {
  final String id;
  final String challengeId;
  final String userId;
  final String username;
  final String code;
  final String language;
  final String? output;
  final String? error;
  final String status;
  final int executionTimeMs;
  final DateTime createdAt;

  ChallengeReply({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.username,
    required this.code,
    required this.language,
    this.output,
    this.error,
    this.status = 'pending',
    this.executionTimeMs = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ChallengeReply.fromJson(Map<String, dynamic> json) {
    return ChallengeReply(
      id: json['id'] ?? '',
      challengeId: json['challengeId'] ?? '',
      userId: json['userId'] ?? '',
      username: json['username'] ?? '',
      code: json['code'] ?? '',
      language: json['language'] ?? 'python',
      output: json['output'],
      error: json['error'],
      status: json['status'] ?? 'pending',
      executionTimeMs: json['executionTimeMs'] ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'challengeId': challengeId,
        'userId': userId,
        'username': username,
        'code': code,
        'language': language,
        'output': output,
        'error': error,
        'status': status,
        'executionTimeMs': executionTimeMs,
        'createdAt': createdAt.toIso8601String(),
      };
}
