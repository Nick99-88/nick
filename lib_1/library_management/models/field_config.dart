import 'package:uuid/uuid.dart';

enum FieldType { text, number, boolean, coordinate, date, dropdown }

class CabinConfig {
  String id;
  String name;

  CabinConfig({String? id, required this.name}) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory CabinConfig.fromJson(Map<String, dynamic> json) => CabinConfig(
        id: json['id'] as String?,
        name: json['name'] as String,
      );
}

class AlmirahConfig {
  String id;
  String name;
  List<CabinConfig> cabins;

  AlmirahConfig({String? id, required this.name, List<CabinConfig>? cabins})
      : id = id ?? const Uuid().v4(),
        cabins = cabins ?? [CabinConfig(name: 'Cabin 1')];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'cabins': cabins.map((c) => c.toJson()).toList(),
      };

  factory AlmirahConfig.fromJson(Map<String, dynamic> json) => AlmirahConfig(
        id: json['id'] as String?,
        name: json['name'] as String,
        cabins: (json['cabins'] as List?)
                ?.map((c) => CabinConfig.fromJson(c as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class FieldConfig {
  final String id;
  String name;
  FieldType type;
  bool required;
  int order;
  List<String>? options;

  FieldConfig({
    required this.id,
    required this.name,
    this.type = FieldType.text,
    this.required = false,
    this.order = 0,
    this.options,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'required': required,
        'order': order,
        'options': options,
      };

  factory FieldConfig.fromJson(Map<String, dynamic> json) => FieldConfig(
        id: json['id'] as String,
        name: json['name'] as String,
        type: FieldType.values.firstWhere((e) => e.name == json['type']),
        required: json['required'] as bool? ?? false,
        order: json['order'] as int? ?? 0,
        options: (json['options'] as List?)?.cast<String>(),
      );
}

class LibraryConfig {
  List<AlmirahConfig> almirahs;
  List<FieldConfig> extraFields;

  LibraryConfig({
    List<AlmirahConfig>? almirahs,
    this.extraFields = const [],
  }) : almirahs = almirahs ?? [AlmirahConfig(name: 'Almirah 1')];

  String get almirahLabel => almirahs.length == 1 ? 'Almirah' : 'Almirahs';

  Map<String, dynamic> toJson() => {
        'almirahs': almirahs.map((a) => a.toJson()).toList(),
        'extra_fields': extraFields.map((f) => f.toJson()).toList(),
      };

  factory LibraryConfig.fromJson(Map<String, dynamic> json) => LibraryConfig(
        almirahs: (json['almirahs'] as List?)
                ?.map((a) => AlmirahConfig.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [AlmirahConfig(name: 'Almirah 1')],
        extraFields: (json['extra_fields'] as List?)
                ?.map((e) => FieldConfig.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}
