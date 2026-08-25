class Site {
  final int siteId;
  final String siteName;
  final String areaName;
  final int customerId;
  final String customerName;
  final String mobileNo;

  Site({
    required this.siteId,
    required this.siteName,
    required this.areaName,
    required this.customerId,
    required this.customerName,
    required this.mobileNo,
  });

  factory Site.fromJson(Map<String, dynamic> json) => Site(
        siteId: json['siteId'] as int,
        siteName: json['siteName'] as String? ?? '',
        areaName: json['areaName'] as String? ?? '',
        customerId: json['customerId'] as int,
        customerName: json['customerName'] as String? ?? '',
        mobileNo: json['mobileNo'] as String? ?? '',
      );
}
