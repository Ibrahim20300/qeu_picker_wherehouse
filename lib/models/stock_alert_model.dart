enum AlertStatus {
  pending,
  confirmed,
  resolved,
}

class StockAlertModel {
  final String id;
  final String productId;
  final String productName;
  final String barcode;
  final String location;
  final int currentQuantity;
  final int minimumQuantity;
  final AlertStatus status;
  final DateTime createdAt;
  final String? confirmedBy;
  final DateTime? confirmedAt;

  StockAlertModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.location,
    required this.currentQuantity,
    required this.minimumQuantity,
    this.status = AlertStatus.pending,
    DateTime? createdAt,
    this.confirmedBy,
    this.confirmedAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isLowStock => currentQuantity <= minimumQuantity;

  StockAlertModel copyWith({
    String? id,
    String? productId,
    String? productName,
    String? barcode,
    String? location,
    int? currentQuantity,
    int? minimumQuantity,
    AlertStatus? status,
    DateTime? createdAt,
    String? confirmedBy,
    DateTime? confirmedAt,
  }) {
    return StockAlertModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      location: location ?? this.location,
      currentQuantity: currentQuantity ?? this.currentQuantity,
      minimumQuantity: minimumQuantity ?? this.minimumQuantity,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      confirmedBy: confirmedBy ?? this.confirmedBy,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'location': location,
      'currentQuantity': currentQuantity,
      'minimumQuantity': minimumQuantity,
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'confirmedBy': confirmedBy,
      'confirmedAt': confirmedAt?.toIso8601String(),
    };
  }

  factory StockAlertModel.fromJson(Map<String, dynamic> json) {
    return StockAlertModel(
      id: json['id'],
      productId: json['productId'],
      productName: json['productName'],
      barcode: json['barcode'],
      location: json['location'],
      currentQuantity: json['currentQuantity'],
      minimumQuantity: json['minimumQuantity'],
      status: AlertStatus.values.firstWhere((e) => e.name == json['status']),
      createdAt: DateTime.parse(json['createdAt']),
      confirmedBy: json['confirmedBy'],
      confirmedAt: json['confirmedAt'] != null
          ? DateTime.parse(json['confirmedAt'])
          : null,
    );
  }

  String get statusDisplayName {
    switch (status) {
      case AlertStatus.pending:
        return 'قيد الانتظار';
      case AlertStatus.confirmed:
        return 'تم التأكيد';
      case AlertStatus.resolved:
        return 'تم الحل';
    }
  }
}
