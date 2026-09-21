class Area {
  final int areaId;
  final String areaName;
  final int cityId;
  final String cityName;

  Area({required this.areaId, required this.areaName, required this.cityId, required this.cityName});

  factory Area.fromJson(Map<String, dynamic> json) => Area(
        areaId: json['areaId'] as int,
        areaName: json['areaName'] as String? ?? '',
        cityId: json['cityId'] as int,
        cityName: json['cityName'] as String? ?? '',
      );
}
