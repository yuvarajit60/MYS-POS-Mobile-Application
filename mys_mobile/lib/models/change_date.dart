class ChangeDate {
  final DateTime currentDate;

  ChangeDate({required this.currentDate});

  factory ChangeDate.fromJson(Map<String, dynamic> json) => ChangeDate(
        currentDate: DateTime.parse(json['currentDate'] as String),
      );
}
