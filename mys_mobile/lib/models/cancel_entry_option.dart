class CancelEntryOption {
  final String entryNo;
  final String description;

  CancelEntryOption({required this.entryNo, required this.description});

  factory CancelEntryOption.fromJson(Map<String, dynamic> json) => CancelEntryOption(
        entryNo: json['entryNo'] as String,
        description: json['description'] as String? ?? '',
      );
}
