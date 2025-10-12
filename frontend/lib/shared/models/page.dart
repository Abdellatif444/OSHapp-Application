
class Page<T> {
  final List<T> content;
  final int totalPages;
  final int totalElements;
  final int number; // Current page number
  final int size; // Page size

  Page({
    required this.content,
    required this.totalPages,
    required this.totalElements,
    required this.number,
    required this.size,
  });

  factory Page.fromJson(Map<String, dynamic> json, T Function(dynamic) fromJsonT) {
    return Page<T>(
      content: (json['content'] as List).map((item) => fromJsonT(item)).toList(),
      totalPages: json['totalPages'] as int,
      totalElements: json['totalElements'] as int,
      number: json['number'] as int,
      size: json['size'] as int,
    );
  }
}
