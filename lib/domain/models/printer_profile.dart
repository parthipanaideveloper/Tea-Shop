import 'dart:convert';

class PrinterProfile {
  final String id;
  final String name;
  final String type; // 'Bluetooth', 'Network', 'USB'
  final String identifier; // MAC or IP address
  final List<String> categories; // Categories assigned to this printer
  final bool is80mmPaper; // 80mm or 58mm paper
  final bool isActive; // Whether to print to this printer

  PrinterProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.identifier,
    this.categories = const [],
    this.is80mmPaper = false,
    this.isActive = true,
  });

  PrinterProfile copyWith({
    String? id,
    String? name,
    String? type,
    String? identifier,
    List<String>? categories,
    bool? is80mmPaper,
    bool? isActive,
  }) {
    return PrinterProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      identifier: identifier ?? this.identifier,
      categories: categories ?? this.categories,
      is80mmPaper: is80mmPaper ?? this.is80mmPaper,
      isActive: isActive ?? this.isActive);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'identifier': identifier,
      'categories': categories,
      'is80mmPaper': is80mmPaper,
      'isActive': isActive,
    };
  }

  factory PrinterProfile.fromMap(Map<String, dynamic> map) {
    return PrinterProfile(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'Bluetooth',
      identifier: map['identifier'] ?? '',
      categories: List<String>.from(map['categories'] ?? []),
      is80mmPaper: map['is80mmPaper'] ?? false,
      isActive: map['isActive'] ?? true);
  }

  String toJson() => json.encode(toMap());

  factory PrinterProfile.fromJson(String source) =>
      PrinterProfile.fromMap(json.decode(source));
}
