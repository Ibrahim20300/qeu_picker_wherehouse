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
  final String location;
  final int requiredQuantity;
  int pickedQuantity;
  bool isPicked;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.location,
    required this.requiredQuantity,
    this.pickedQuantity = 0,
    this.isPicked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'productName': productName,
      'barcode': barcode,
      'location': location,
      'requiredQuantity': requiredQuantity,
      'pickedQuantity': pickedQuantity,
      'isPicked': isPicked,
    };
  }

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['productId'],
      productName: json['productName'],
      barcode: json['barcode'],
      location: json['location'],
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

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.items,
    this.status = OrderStatus.pending,
    this.assignedTo,
    DateTime? createdAt,
    this.completedAt,
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
  }) {
    return OrderModel(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      items: items ?? this.items,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
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
