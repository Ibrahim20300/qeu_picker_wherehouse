import '../l10n/app_localizations.dart';

class QCZoneTask {
  final String taskId;
  final String zoneName;
  final String zoneCode;
  final String pickerName;
  final int totalItems;
  final int pickedItems;
  final int exceptionItems;
  final int packageCount;
  final DateTime? completedAt;

  QCZoneTask({
    required this.taskId,
    required this.zoneName,
    required this.zoneCode,
    required this.pickerName,
    required this.totalItems,
    required this.pickedItems,
    required this.exceptionItems,
    required this.packageCount,
    this.completedAt,
  });

  factory QCZoneTask.fromJson(Map<String, dynamic> json) {
    return QCZoneTask(
      taskId: json['task_id']?.toString() ?? '',
      zoneName: json['zone_name']?.toString() ?? '',
      zoneCode: json['zone_code']?.toString() ?? '',
      pickerName: json['picker_name']?.toString() ?? '',
      totalItems: json['total_items'] ?? 0,
      pickedItems: json['picked_items'] ?? 0,
      exceptionItems: json['exception_items'] ?? 0,
      packageCount: json['package_count'] ?? 0,
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'zone_name': zoneName,
      'zone_code': zoneCode,
      'picker_name': pickerName,
      'total_items': totalItems,
      'picked_items': pickedItems,
      'exception_items': exceptionItems,
      'package_count': packageCount,
      'completed_at': completedAt?.toIso8601String(),
    };
  }
}

enum QCStatus {
  unspecified,
  pending,
  inProgress,
  passed,
  failed,
  overridden;

  static QCStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'QC_PENDING':
        return QCStatus.pending;
      case 'QC_IN_PROGRESS':
        return QCStatus.inProgress;
      case 'QC_PASSED':
        return QCStatus.passed;
      case 'QC_FAILED':
        return QCStatus.failed;
      case 'QC_OVERRIDDEN':
        return QCStatus.overridden;
      default:
        return QCStatus.unspecified;
    }
  }

  String get apiValue {
    switch (this) {
      case QCStatus.unspecified:
        return 'QC_UNSPECIFIED';
      case QCStatus.pending:
        return 'QC_PENDING';
      case QCStatus.inProgress:
        return 'QC_IN_PROGRESS';
      case QCStatus.passed:
        return 'QC_PASSED';
      case QCStatus.failed:
        return 'QC_FAILED';
      case QCStatus.overridden:
        return 'QC_OVERRIDDEN';
    }
  }

  String get displayName {
    switch (this) {
      case QCStatus.unspecified:
        return S.qcUnspecified;
      case QCStatus.pending:
        return S.qcPending;
      case QCStatus.inProgress:
        return S.qcInProgress;
      case QCStatus.passed:
        return S.qcPassed;
      case QCStatus.failed:
        return S.qcFailed;
      case QCStatus.overridden:
        return S.qcOverridden;
    }
  }
}

class QCCheckModel {
  final String id;
  final String orderId;
  final String warehouseId;
  final QCStatus status;
  final int queuePosition;
  final int expectedPackageCount;
  final int actualPackageCount;
  final String assignedTo;
  final String assignedToName;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String verifiedBy;
  final String verifiedByName;
  final String result;
  final String rejectionReason;
  final String overrideBy;
  final String overrideByName;
  final String overrideReason;
  final DateTime? overrideAt;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<QCZoneTask> zoneTasks;
  final String orderNumber;
  final String customerName;

  QCCheckModel({
    required this.id,
    required this.orderId,
    required this.warehouseId,
    required this.status,
    required this.queuePosition,
    required this.expectedPackageCount,
    required this.actualPackageCount,
    required this.assignedTo,
    required this.assignedToName,
    this.startedAt,
    this.completedAt,
    required this.verifiedBy,
    required this.verifiedByName,
    required this.result,
    required this.rejectionReason,
    required this.overrideBy,
    required this.overrideByName,
    required this.overrideReason,
    this.overrideAt,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.zoneTasks,
    required this.orderNumber,
    required this.customerName,
  });

  factory QCCheckModel.fromJson(Map<String, dynamic> json) {
    final zoneTasksList = (json['zone_tasks'] as List<dynamic>? ?? [])
        .map((t) => QCZoneTask.fromJson(t as Map<String, dynamic>))
        .toList();

    return QCCheckModel(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      warehouseId: json['warehouse_id']?.toString() ?? '',
      status: QCStatus.fromString(json['status']?.toString() ?? ''),
      queuePosition: json['queue_position'] ?? 0,
      expectedPackageCount: json['expected_package_count'] ?? 0,
      actualPackageCount: json['actual_package_count'] ?? 0,
      assignedTo: json['assigned_to']?.toString() ?? '',
      assignedToName: json['assigned_to_name']?.toString() ?? '',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? ''),
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? ''),
      verifiedBy: json['verified_by']?.toString() ?? '',
      verifiedByName: json['verified_by_name']?.toString() ?? '',
      result: json['result']?.toString() ?? '',
      rejectionReason: json['rejection_reason']?.toString() ?? '',
      overrideBy: json['override_by']?.toString() ?? '',
      overrideByName: json['override_by_name']?.toString() ?? '',
      overrideReason: json['override_reason']?.toString() ?? '',
      overrideAt: DateTime.tryParse(json['override_at']?.toString() ?? ''),
      notes: json['notes']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      zoneTasks: zoneTasksList,
      orderNumber: json['order_number']?.toString().replaceAll('#', '') ?? '',
      customerName: json['customer_name']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'warehouse_id': warehouseId,
      'status': status.apiValue,
      'queue_position': queuePosition,
      'expected_package_count': expectedPackageCount,
      'actual_package_count': actualPackageCount,
      'assigned_to': assignedTo,
      'assigned_to_name': assignedToName,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'verified_by': verifiedBy,
      'verified_by_name': verifiedByName,
      'result': result,
      'rejection_reason': rejectionReason,
      'override_by': overrideBy,
      'override_by_name': overrideByName,
      'override_reason': overrideReason,
      'override_at': overrideAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'zone_tasks': zoneTasks.map((t) => t.toJson()).toList(),
      'order_number': orderNumber,
      'customer_name': customerName,
    };
  }

  bool get isPending => status == QCStatus.pending;
  bool get isInProgress => status == QCStatus.inProgress;
  bool get isPassed => status == QCStatus.passed;
  bool get isFailed => status == QCStatus.failed;

  int get totalZoneItems => zoneTasks.fold(0, (sum, t) => sum + t.totalItems);
  int get totalZonePicked => zoneTasks.fold(0, (sum, t) => sum + t.pickedItems);
  int get totalZoneExceptions => zoneTasks.fold(0, (sum, t) => sum + t.exceptionItems);
}
