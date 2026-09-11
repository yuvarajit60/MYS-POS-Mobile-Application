class Employee {
  final int employeeId;
  final String employeeName;
  final String mobileNo;
  final bool isDriver;

  Employee({
    required this.employeeId,
    required this.employeeName,
    required this.mobileNo,
    required this.isDriver,
  });

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        employeeId: json['employeeId'] as int,
        employeeName: json['employeeName'] as String,
        mobileNo: json['mobileNo'] as String? ?? '',
        isDriver: json['isDriver'] as bool? ?? false,
      );
}
