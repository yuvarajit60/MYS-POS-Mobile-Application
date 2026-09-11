class EmployeeDetail {
  final int employeeId;
  final String employeeName;
  final String printName;
  final String employeeCode;
  final String address;
  final int cityId;
  final String cityName;
  final String pinCode;
  final String phoneNo;
  final String mobileNo;
  final String emailId;
  final bool isDriver;

  EmployeeDetail({
    required this.employeeId,
    required this.employeeName,
    required this.printName,
    required this.employeeCode,
    required this.address,
    required this.cityId,
    required this.cityName,
    required this.pinCode,
    required this.phoneNo,
    required this.mobileNo,
    required this.emailId,
    required this.isDriver,
  });

  factory EmployeeDetail.fromJson(Map<String, dynamic> json) => EmployeeDetail(
        employeeId: json['employeeId'] as int,
        employeeName: json['employeeName'] as String,
        printName: json['printName'] as String? ?? '',
        employeeCode: json['employeeCode'] as String? ?? '',
        address: json['address'] as String? ?? '',
        cityId: json['cityId'] as int,
        cityName: json['cityName'] as String? ?? '',
        pinCode: json['pinCode'] as String? ?? '',
        phoneNo: json['phoneNo'] as String? ?? '',
        mobileNo: json['mobileNo'] as String? ?? '',
        emailId: json['emailId'] as String? ?? '',
        isDriver: json['isDriver'] as bool? ?? false,
      );
}
