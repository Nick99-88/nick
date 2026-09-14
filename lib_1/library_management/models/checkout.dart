class Checkout {
  final String id;
  final String bookId;
  String bookTitle;
  String bookAuthor;
  String clientName;
  String? clientPhone;
  DateTime checkoutDate;
  DateTime? returnDate;
  String? notes;
  Map<String, dynamic> extraFields;

  Checkout({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    this.bookAuthor = '',
    required this.clientName,
    this.clientPhone,
    DateTime? checkoutDate,
    this.returnDate,
    this.notes,
    this.extraFields = const {},
  }) : checkoutDate = checkoutDate ?? DateTime.now();

  bool get isReturned => returnDate != null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'book_id': bookId,
        'book_title': bookTitle,
        'book_author': bookAuthor,
        'client_name': clientName,
        'client_phone': clientPhone,
        'checkout_date': checkoutDate.toIso8601String(),
        'return_date': returnDate?.toIso8601String(),
        'notes': notes,
        'extra_fields': extraFields,
      };

  factory Checkout.fromJson(Map<String, dynamic> json) => Checkout(
        id: json['id'] as String,
        bookId: json['book_id'] as String,
        bookTitle: json['book_title'] as String? ?? '',
        bookAuthor: json['book_author'] as String? ?? '',
        clientName: json['client_name'] as String,
        clientPhone: json['client_phone'] as String?,
        checkoutDate: json['checkout_date'] != null
            ? DateTime.parse(json['checkout_date'] as String)
            : DateTime.now(),
        returnDate: json['return_date'] != null
            ? DateTime.parse(json['return_date'] as String)
            : null,
        notes: json['notes'] as String?,
        extraFields: json['extra_fields'] is Map
            ? Map<String, dynamic>.from(json['extra_fields'] as Map)
            : {},
      );
}
