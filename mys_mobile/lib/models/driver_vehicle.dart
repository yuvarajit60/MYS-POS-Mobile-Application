class DriverVehicle {
  final int? vehicleId;
  final String? vehicleName;

  DriverVehicle({this.vehicleId, this.vehicleName});

  factory DriverVehicle.fromJson(Map<String, dynamic> json) => DriverVehicle(
        vehicleId: json['vehicleId'] as int?,
        vehicleName: json['vehicleName'] as String?,
      );
}
