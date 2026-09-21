class SiteDetail {
  final int siteId;
  final String siteName;
  final String areaName;
  final int areaId;
  final int cityId;
  final String cityName;
  final int customerId;
  final String customerName;

  SiteDetail({
    required this.siteId,
    required this.siteName,
    required this.areaName,
    required this.areaId,
    required this.cityId,
    required this.cityName,
    required this.customerId,
    required this.customerName,
  });

  factory SiteDetail.fromJson(Map<String, dynamic> json) => SiteDetail(
        siteId: json['siteId'] as int,
        siteName: json['siteName'] as String? ?? '',
        areaName: json['areaName'] as String? ?? '',
        areaId: json['areaId'] as int? ?? 0,
        cityId: json['cityId'] as int,
        cityName: json['cityName'] as String? ?? '',
        customerId: json['customerId'] as int,
        customerName: json['customerName'] as String? ?? '',
      );
}
