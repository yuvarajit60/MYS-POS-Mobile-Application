class EmployeeVehicleMapping {
  final int mappingId;
  final int employeeId;
  final String employeeName;
  final int vehicleId;
  final String vehicleName;
  final DateTime validStartDate;
  final DateTime? validEndDate;

  EmployeeVehicleMapping({
    required this.mappingId,
    required this.employeeId,
    required this.employeeName,
    required this.vehicleId,
    required this.vehicleName,
    required this.validStartDate,
    required this.validEndDate,
  });

  factory EmployeeVehicleMapping.fromJson(Map<String, dynamic> json) => EmployeeVehicleMapping(
        mappingId: json['mappingId'] as int,
        employeeId: json['employeeId'] as int,
        employeeName: json['employeeName'] as String? ?? '',
        vehicleId: json['vehicleId'] as int,
        vehicleName: json['vehicleName'] as String? ?? '',
        validStartDate: DateTime.parse(json['validStartDate'] as String),
        validEndDate: json['validEndDate'] == null ? null : DateTime.parse(json['validEndDate'] as String),
      );
}
