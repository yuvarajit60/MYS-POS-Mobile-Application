class Company {
  final String companyName;
  final String address;
  final String gstIn;
  final String phoneNo;
  final String mobileNo;
  final String emailId;

  Company({
    required this.companyName,
    required this.address,
    required this.gstIn,
    required this.phoneNo,
    required this.mobileNo,
    required this.emailId,
  });

  factory Company.fromJson(Map<String, dynamic> json) => Company(
        companyName: json['companyName'] as String,
        address: json['address'] as String? ?? '',
        gstIn: json['gstIn'] as String? ?? '',
        phoneNo: json['phoneNo'] as String? ?? '',
        mobileNo: json['mobileNo'] as String? ?? '',
        emailId: json['emailId'] as String? ?? '',
      );
}
