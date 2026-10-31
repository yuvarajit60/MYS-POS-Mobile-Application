class Head {
  final int headId;
  final String headName;
  final String incomeOrExpenses;

  Head({required this.headId, required this.headName, required this.incomeOrExpenses});

  factory Head.fromJson(Map<String, dynamic> json) => Head(
        headId: json['headId'] as int,
        headName: json['headName'] as String,
        incomeOrExpenses: json['incomeOrExpenses'] as String,
      );
}
