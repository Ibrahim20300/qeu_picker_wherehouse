import '../l10n/app_localizations.dart';

class PickerModel {
  final String id;
  final String name;
  final String phone;
  final String employeeId;
  final String warehouseId;
  final String warehouseName;
  final String status;
  final bool isOnDuty;
  final int tasksCompletedToday;
  final int itemsPickedToday;
  final String role;
  final String? zoneId;
  final String? zoneName;
  final String? stationId;
  final String? stationName;
  final DateTime createdAt;
  final DateTime updatedAt;

  PickerModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.employeeId,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.isOnDuty,
    required this.tasksCompletedToday,
    required this.itemsPickedToday,
    required this.role,
    this.zoneId,
    this.zoneName,
    this.stationId,
    this.stationName,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isActive => status == 'active';

  String get roleDisplayName {
    final roleStr = role.toLowerCase();
    if (roleStr.contains('supervisor') || roleStr.contains('super')) {
      return S.roleSupervisor;
    } else if (roleStr.contains('qc') || roleStr.contains('quality')) {
      return S.roleQC;
    } else {
      return S.rolePicker;
    }
  }

  String get statusDisplayName {
    switch (status) {
      case 'active':
        return S.statusActive;
      case 'inactive':
        return S.statusInactive;
      case 'busy':
        return S.statusBusy;
      default:
        return status;
    }
  }

  factory PickerModel.fromJson(Map<String, dynamic> json) {
    return PickerModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      employeeId: json['employee_id'] ?? '',
      warehouseId: json['warehouse_id'] ?? '',
      warehouseName: json['warehouse_name'] ?? '',
      status: json['status'] ?? 'active',
      isOnDuty: json['is_on_duty'] ?? false,
      tasksCompletedToday: json['tasks_completed_today'] ?? 0,
      itemsPickedToday: json['items_picked_today'] ?? 0,
      role: json['role'] ?? 'ROLE_PICKER',
      zoneId: json['zone_id'],
      zoneName: json['zone_name'],
      stationId: json['station_id'],
      stationName: json['station_name'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'employee_id': employeeId,
      'warehouse_id': warehouseId,
      'warehouse_name': warehouseName,
      'status': status,
      'is_on_duty': isOnDuty,
      'tasks_completed_today': tasksCompletedToday,
      'items_picked_today': itemsPickedToday,
      'role': role,
      'zone_id': zoneId,
      'zone_name': zoneName,
      'station_id': stationId,
      'station_name': stationName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
