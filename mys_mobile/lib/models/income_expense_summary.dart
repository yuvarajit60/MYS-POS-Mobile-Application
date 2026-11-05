class IncomeExpenseSummary {
  final String entryNo;
  final DateTime entryDate;
  final DateTime entryTime;
  final String incomeOrExpenses;
  final String particulars;
  final double amount;
  final double runningBalance;

  IncomeExpenseSummary({
    required this.entryNo,
    required this.entryDate,
    required this.entryTime,
    required this.incomeOrExpenses,
    required this.particulars,
    required this.amount,
    required this.runningBalance,
  });

  factory IncomeExpenseSummary.fromJson(Map<String, dynamic> json) => IncomeExpenseSummary(
        entryNo: json['entryNo'] as String,
        entryDate: DateTime.parse(json['entryDate'] as String),
        entryTime: DateTime.parse(json['entryTime'] as String),
        incomeOrExpenses: json['incomeOrExpenses'] as String,
        particulars: json['particulars'] as String? ?? '',
        amount: (json['amount'] as num).toDouble(),
        runningBalance: (json['runningBalance'] as num).toDouble(),
      );
}
