enum UserRole {
  supervisor,
  picker,
}

class UserModel {
  final String id;
  final String name;
  final String teamName;
  final String password;
  final UserRole role;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.teamName,
    required this.password,
    required this.role,
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  UserModel copyWith({
    String? id,
    String? name,
    String? teamName,
    String? password,
    UserRole? role,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      teamName: teamName ?? this.teamName,
      password: password ?? this.password,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'teamName': teamName,
      'password': password,
      'role': role.name,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      name: json['name'],
      teamName: json['teamName'],
      password: json['password'],
      role: UserRole.values.firstWhere((e) => e.name == json['role']),
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  String get roleDisplayName {
    switch (role) {
      case UserRole.supervisor:
        return 'سوبر فايزر';
      case UserRole.picker:
        return 'بيكر';
    }
  }
}
