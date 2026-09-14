class Book {
  final String id;
  String title;
  String author;
  String? isbn;
  String? description;
  int? totalCopies;
  int? availableCopies;
  String? almirahId;
  String? cabinId;
  DateTime createdAt;
  Map<String, dynamic> fieldValues;

  Book({
    required this.id,
    required this.title,
    this.author = '',
    this.isbn,
    this.description,
    this.totalCopies,
    this.availableCopies,
    this.almirahId,
    this.cabinId,
    DateTime? createdAt,
    Map<String, dynamic>? fieldValues,
  })  : createdAt = createdAt ?? DateTime.now(),
        fieldValues = fieldValues ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'isbn': isbn,
        'description': description,
        'total_copies': totalCopies,
        'available_copies': availableCopies,
        'almirah_id': almirahId,
        'cabin_id': cabinId,
        'created_at': createdAt.toIso8601String(),
        'field_values': fieldValues,
      };

  factory Book.fromJson(Map<String, dynamic> json) => Book(
        id: json['id'] as String,
        title: json['title'] as String,
        author: json['author'] as String? ?? '',
        isbn: json['isbn'] as String?,
        description: json['description'] as String?,
        totalCopies: json['total_copies'] as int?,
        availableCopies: json['available_copies'] as int?,
        almirahId: json['almirah_id'] as String?,
        cabinId: json['cabin_id'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : DateTime.now(),
        fieldValues: (json['field_values'] as Map<String, dynamic>?) ?? {},
      );
}
