class Driver {
  final int employeeId;
  final String employeeName;
  final String mobileNo;

  Driver({required this.employeeId, required this.employeeName, required this.mobileNo});

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        employeeId: json['employeeId'] as int,
        employeeName: json['employeeName'] as String,
        mobileNo: json['mobileNo'] as String? ?? '',
      );
}
