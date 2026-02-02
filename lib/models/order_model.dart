enum OrderStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

class OrderItem {
  final String productId;
  final String productName;
  final String barcode;
  final List<String> locations;
  final int requiredQuantity;
  int pickedQuantity;
  bool isPicked;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.locations,
    required this.requiredQuantity,
    this.pickedQuantity = 0,
    this.isPicked = false,
  });

  /// الموقع الأساسي (الأول)
  String get primaryLocation => locations.isNotEmpty ? locations.first : '';

  /// للتوافق مع الكود القديم
  String get location => primaryLocation;

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'locations': locations,
      'requiredQuantity': requiredQuantity,
      'pickedQuantity': pickedQuantity,
      'isPicked': isPicked,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    // دعم الصيغة القديمة (location) والجديدة (locations)
    List<String> locs;
    if (json['locations'] != null) {
      locs = List<String>.from(json['locations']);
    } else if (json['location'] != null) {
      locs = [json['location']];
    } else {
      locs = [];
    }

    return OrderItem(
      productId: json['productId'],
      productName: json['productName'],
      barcode: json['barcode'],
      locations: locs,
      requiredQuantity: json['requiredQuantity'],
      pickedQuantity: json['pickedQuantity'] ?? 0,
      isPicked: json['isPicked'] ?? false,
    );
  }
}

class OrderModel {
  final String id;
  final String orderNumber;
  final List<OrderItem> items;
  final OrderStatus status;
  final String? assignedTo;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int bagsCount;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.items,
    this.status = OrderStatus.pending,
    this.assignedTo,
    DateTime? createdAt,
    this.completedAt,
    this.bagsCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  int get totalItems => items.length;
  int get pickedItems => items.where((item) => item.isPicked).length;
  double get progress => totalItems > 0 ? pickedItems / totalItems : 0;

  OrderModel copyWith({
    String? id,
    String? orderNumber,
    List<OrderItem>? items,
    OrderStatus? status,
    String? assignedTo,
    DateTime? createdAt,
    DateTime? completedAt,
    int? bagsCount,
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      items: items ?? this.items,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      bagsCount: bagsCount ?? this.bagsCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'items': items.map((e) => e.toJson()).toList(),
      'status': status.name,
      'assignedTo': assignedTo,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'bagsCount': bagsCount,
    };
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'],
      orderNumber: json['orderNumber'],
      items: (json['items'] as List).map((e) => OrderItem.fromJson(e)).toList(),
      status: OrderStatus.values.firstWhere((e) => e.name == json['status']),
      assignedTo: json['assignedTo'],
      createdAt: DateTime.parse(json['createdAt']),
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'])
          : null,
      bagsCount: json['bagsCount'] ?? 0,
    );
  }

  String get statusDisplayName {
    switch (status) {
      case OrderStatus.pending:
        return 'قيد الانتظار';
      case OrderStatus.inProgress:
        return 'جاري التنفيذ';
      case OrderStatus.completed:
        return 'مكتمل';
      case OrderStatus.cancelled:
        return 'ملغي';
    }
  }
}
