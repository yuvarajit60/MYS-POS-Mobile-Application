class HeadDetail {
  final int headId;
  final String headName;
  final String printName;
  final String incomeOrExpenses;
  final String? mappedMaster;
  final bool status;

  HeadDetail({
    required this.headId,
    required this.headName,
    required this.printName,
    required this.incomeOrExpenses,
    this.mappedMaster,
    required this.status,
  });

  factory HeadDetail.fromJson(Map<String, dynamic> json) => HeadDetail(
        headId: json['headId'] as int,
        headName: json['headName'] as String,
        printName: json['printName'] as String? ?? '',
        incomeOrExpenses: json['incomeOrExpenses'] as String,
        mappedMaster: json['mappedMaster'] as String?,
        status: json['status'] as bool? ?? true,
      );
}
