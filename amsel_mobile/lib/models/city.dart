class City {
  final int cityId;
  final String cityName;

  City({required this.cityId, required this.cityName});

  factory City.fromJson(Map<String, dynamic> json) => City(
        cityId: json['cityId'] as int,
        cityName: json['cityName'] as String,
      );
}
