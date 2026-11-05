class Head {
  final int headId;
  final String headName;
  final String incomeOrExpenses;
  final String? mappedMaster;

  Head({required this.headId, required this.headName, required this.incomeOrExpenses, this.mappedMaster});

  factory Head.fromJson(Map<String, dynamic> json) => Head(
        headId: json['headId'] as int,
        headName: json['headName'] as String,
        incomeOrExpenses: json['incomeOrExpenses'] as String,
        mappedMaster: json['mappedMaster'] as String?,
      );
}
