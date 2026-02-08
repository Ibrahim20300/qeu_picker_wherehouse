import 'order_model.dart';

enum TaskStatus {
  pending,
  assigned,
  inProgress,
  completed,
  cancelled;

  static TaskStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'TASK_PENDING':
        return TaskStatus.pending;
      case 'TASK_ASSIGNED':
        return TaskStatus.assigned;
      case 'TASK_IN_PROGRESS':
        return TaskStatus.inProgress;
      case 'TASK_COMPLETED':
        return TaskStatus.completed;
      case 'TASK_CANCELLED':
        return TaskStatus.cancelled;
      default:
        return TaskStatus.pending;
    }
  }

  String get apiValue {
    switch (this) {
      case TaskStatus.pending:
        return 'TASK_PENDING';
      case TaskStatus.assigned:
        return 'TASK_ASSIGNED';
      case TaskStatus.inProgress:
        return 'TASK_IN_PROGRESS';
      case TaskStatus.completed:
        return 'TASK_COMPLETED';
      case TaskStatus.cancelled:
        return 'TASK_CANCELLED';
    }
  }

  String get displayName {
    switch (this) {
      case TaskStatus.pending:
        return 'قيد الانتظار';
      case TaskStatus.assigned:
        return 'تم التعيين';
      case TaskStatus.inProgress:
        return 'جاري التحضير';
      case TaskStatus.completed:
        return 'مكتمل';
      case TaskStatus.cancelled:
        return 'ملغي';
    }
  }

  OrderStatus toOrderStatus() {
    switch (this) {
      case TaskStatus.pending:
      case TaskStatus.assigned:
        return OrderStatus.pending;
      case TaskStatus.inProgress:
        return OrderStatus.inProgress;
      case TaskStatus.completed:
        return OrderStatus.completed;
      case TaskStatus.cancelled:
        return OrderStatus.cancelled;
    }
  }
}

class TaskDetailsModel {
  final String id;
  final String orderNumber;
  final TaskStatus status;
  final int totalItems;
  final String customerName;
  final List<OrderItem> items;
  final DateTime createdAt;

  TaskDetailsModel({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalItems,
    required this.customerName,
    required this.items,
    required this.createdAt,
  });

  factory TaskDetailsModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>? ?? [])
        .map((item) => OrderItem.fromTaskJson(item as Map<String, dynamic>))
        .toList();

    return TaskDetailsModel(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number']?.toString().replaceAll('#', '') ?? '',
      status: TaskStatus.fromString(json['status']?.toString() ?? ''),
      totalItems: json['total_items'] ?? 0,
      customerName: json['customer_name']?.toString() ?? '',
      items: itemsList,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'status': status.apiValue,
      'total_items': totalItems,
      'customer_name': customerName,
      'items': items.map((item) => item.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isInProgress => status == TaskStatus.inProgress;
  bool get isCompleted => status == TaskStatus.completed;

  OrderModel toOrderModel() {
    return OrderModel(
      id: id,
      orderNumber: orderNumber,
      status: status.toOrderStatus(),
      items: items,
      createdAt: createdAt,
    );
  }
}
