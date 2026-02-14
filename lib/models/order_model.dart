import '../helpers/image_helper.dart';

enum OrderStatus {
  pending,
  inProgress,
  completed,
  cancelled,
}

class ProductAttribute {
  final String name;
  final String value;

  const ProductAttribute({
    required this.name,
    required this.value,
  });

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      name: json['name']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
    };
  }

  @override
  String toString() => '$name: $value';
}

class OrderItem {
  final String id; // task item id from API
  final String taskId;
  final String orderItemId;
  final String productId;
  final String erpId;
  final String productName;
  final String barcode;
  final List<String> barcodes;
  final String sku;
  final List<String> locations;
  final int requiredQuantity;
  final String? imageUrl;
  final String? unitName;
  final int unitValue;
  final String? zone;
  final String status;
  final double unitPrice;
  final DateTime? pickedAt;
  final String? pickedBy;
  final String notes;
  final Map<String, dynamic>? substitution;
  final Map<String, dynamic>? exception;
  final List<ProductAttribute> attributes;
  int pickedQuantity;
  bool isPicked;

  OrderItem({
    this.id = '',
    this.taskId = '',
    this.orderItemId = '',
    required this.productId,
    this.erpId = '',
    required this.productName,
    required this.barcode,
    this.barcodes = const [],
    this.sku = '',
    required this.locations,
    required this.requiredQuantity,
    this.imageUrl,
    this.unitName,
    this.unitValue = 1,
    this.zone,
    this.status = '',
    this.unitPrice = 0.0,
    this.pickedAt,
    this.pickedBy,
    this.notes = '',
    this.substitution,
    this.exception,
    this.attributes = const [],
    this.pickedQuantity = 0,
    this.isPicked = false,
  });

  /// الموقع الأساسي (الأول)
  String get primaryLocation => locations.isNotEmpty ? locations.first : '';

  /// للتوافق مع الكود القديم
  String get location => primaryLocation;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'orderItemId': orderItemId,
      'productId': productId,
      'erpId': erpId,
      'productName': productName,
      'barcode': barcode,
      'barcodes': barcodes,
      'sku': sku,
      'locations': locations,
      'requiredQuantity': requiredQuantity,
      'pickedQuantity': pickedQuantity,
      'isPicked': isPicked,
      'imageUrl': imageUrl,
      'unitName': unitName,
      'unitValue': unitValue,
      'zone': zone,
      'status': status,
      'unitPrice': unitPrice,
      'pickedAt': pickedAt?.toIso8601String(),
      'pickedBy': pickedBy,
      'notes': notes,
      'substitution': substitution,
      'exception': exception,
      'attributes': attributes.map((a) => a.toJson()).toList(),
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
      id: json['id']?.toString() ?? '',
      taskId: json['taskId']?.toString() ?? '',
      orderItemId: json['orderItemId']?.toString() ?? '',
      productId: json['productId'],
      erpId: json['erpId']?.toString() ?? '',
      productName: json['productName'],
      barcode: json['barcode'],
      barcodes: json['barcodes'] != null ? List<String>.from(json['barcodes']) : [],
      sku: json['sku']?.toString() ?? '',
      locations: locs,
      requiredQuantity: json['requiredQuantity'],
      pickedQuantity: json['pickedQuantity'] ?? 0,
      isPicked: json['isPicked'] ?? false,
      imageUrl: json['imageUrl'] != null
          ? ImageHelper.buildImageUrl(json['imageUrl'].toString(), height: 600, quality: 90)
          : null,
      unitName: json['unitName'],
      unitValue: json['unitValue'] ?? 1,
      zone: json['zone'],
      status: json['status']?.toString() ?? '',
      unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
      pickedAt: json['pickedAt'] != null ? DateTime.tryParse(json['pickedAt']) : null,
      pickedBy: json['pickedBy'],
      notes: json['notes']?.toString() ?? '',
      substitution: json['substitution'] as Map<String, dynamic>?,
      exception: json['exception'] as Map<String, dynamic>?,
      attributes: json['attributes'] != null
          ? (json['attributes'] as List).map((a) => ProductAttribute.fromJson(a)).toList()
          : [],
    );
  }

  static String _buildProductName(String name, List<ProductAttribute> attributes) {
    if (attributes.isNotEmpty) {
      final attr = attributes.first;
      return '$name ${attr.value} ${attr.name}';
    }
    return name;
  }

  /// تحويل من بيانات الـ API (task item)
  factory OrderItem.fromTaskJson(Map<String, dynamic> json) {
    final barcodes = json['barcodes'] as List<dynamic>? ?? [];
    final barcode = barcodes.isNotEmpty ? barcodes.first.toString() : '';

    final locationsData = json['locations'] as List<dynamic>? ?? [];
    final locations = locationsData.map((loc) {
      if (loc is Map<String, dynamic>) {
        return loc['full_code']?.toString() ?? '';
      }
      return loc.toString();
    }).where((loc) => loc.isNotEmpty).toList();

    final requiredQty = json['ordered_quantity'] ?? 0;
    final pickedQty = json['picked_quantity'] ?? 0;
    final status = json['status']?.toString() ?? '';
    final isPicked = status == 'ITEM_PICKED' || status == 'ITEM_OUT_OF_STOCK' || (pickedQty >= requiredQty && requiredQty > 0);

    final attributesData = json['attributes'] as List<dynamic>? ?? [];
    final attributes = attributesData
        .whereType<Map<String, dynamic>>()
        .map((a) => ProductAttribute.fromJson(a))
        .toList();

    return OrderItem(
      id: json['id']?.toString() ?? '',
      taskId: json['task_id']?.toString() ?? '',
      orderItemId: json['order_item_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      erpId: json['erp_id']?.toString() ?? '',
      productName: _buildProductName(json['product_name']?.toString() ?? '', attributes),
      barcode: barcode,
      barcodes: barcodes.map((b) => b.toString()).toList(),
      sku: json['sku']?.toString() ?? '',
      locations: locations.isNotEmpty ? locations : [''],
      requiredQuantity: requiredQty,
      pickedQuantity: pickedQty,
      isPicked: isPicked,
      imageUrl: json['product_image'] != null
          ? ImageHelper.buildImageUrl(json['product_image'].toString(), height: 600, quality: 90)
          : null,
      unitName: json['unit_name']?.toString(),
      unitValue: json['unit_value'] ?? 1,
      zone: json['zone']?.toString(),
      status: status,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      pickedAt: json['picked_at'] != null ? DateTime.tryParse(json['picked_at'].toString()) : null,
      pickedBy: json['picked_by']?.toString(),
      notes: json['notes']?.toString() ?? '',
      substitution: json['substitution'] as Map<String, dynamic>?,
      exception: json['exception'] as Map<String, dynamic>?,
      attributes: attributes,
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
  final String? zone;
  final int totalZone; // إجمالي عدد الزونات (1-12)
  final String? position;
  final String? neighborhood; // الحي
  final String? slotTime; // مثال: "10-12 pm"
  final String? slotDate; // مثال: "05/12/2026"

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.items,
    this.status = OrderStatus.pending,
    this.assignedTo,
    DateTime? createdAt,
    this.completedAt,
    this.bagsCount = 0,
    this.zone,
    this.totalZone = 12,
    this.position,
    this.neighborhood,
    this.slotTime,
    this.slotDate,
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
    String? zone,
    int? totalZone,
    String? position,
    String? neighborhood,
    String? slotTime,
    String? slotDate,
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
      zone: zone ?? this.zone,
      totalZone: totalZone ?? this.totalZone,
      position: position ?? this.position,
      neighborhood: neighborhood ?? this.neighborhood,
      slotTime: slotTime ?? this.slotTime,
      slotDate: slotDate ?? this.slotDate,
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
      'zone': zone,
      'totalZone': totalZone,
      'position': position,
      'neighborhood': neighborhood,
      'slotTime': slotTime,
      'slotDate': slotDate,
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
      zone: json['zone'],
      totalZone: json['totalZone'] ?? 12,
      position: json['position'],
      neighborhood: json['neighborhood'],
      slotTime: json['slotTime'],
      slotDate: json['slotDate'],
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
