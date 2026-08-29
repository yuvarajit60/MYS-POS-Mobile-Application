class Vehicle {
  final int vehicleId;
  final String vehicleName;

  Vehicle({required this.vehicleId, required this.vehicleName});

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        vehicleId: json['vehicleId'] as int,
        vehicleName: json['vehicleName'] as String? ?? '',
      );
}
