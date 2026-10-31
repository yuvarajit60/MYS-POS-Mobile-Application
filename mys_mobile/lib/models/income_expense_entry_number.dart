class IncomeExpenseEntryNumber {
  final int incomeOrExpensesId;
  final String entryNo;

  IncomeExpenseEntryNumber({required this.incomeOrExpensesId, required this.entryNo});

  factory IncomeExpenseEntryNumber.fromJson(Map<String, dynamic> json) => IncomeExpenseEntryNumber(
        incomeOrExpensesId: json['incomeOrExpensesId'] as int,
        entryNo: json['entryNo'] as String,
      );
}
