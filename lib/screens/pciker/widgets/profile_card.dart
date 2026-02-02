import 'package:flutter/material.dart';
import '../../../models/user_model.dart';

class ProfileCard extends StatelessWidget {
  final UserModel? user;

  const ProfileCard({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAvatar(context),
            const SizedBox(height: 16),
            _buildName(),
            const SizedBox(height: 8),
            _buildRoleBadge(context),
            const SizedBox(height: 12),
            _buildTeamInfo(),
            if (user?.zone != null) ...[
              const SizedBox(height: 8),
              _buildZoneBadge(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return CircleAvatar(
      radius: 45,
      backgroundColor: Theme.of(context).primaryColor,
      child: const Icon(
        Icons.person,
        size: 50,
        color: Colors.white,
      ),
    );
  }

  Widget _buildName() {
    return Text(
      user?.name ?? 'مستخدم',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildRoleBadge(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        user?.roleDisplayName ?? 'بيكر',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildTeamInfo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.groups_outlined, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Text(
          'الفريق: ${user?.teamName ?? '-'}',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildZoneBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.location_on, size: 20, color: Colors.blue),
          const SizedBox(width: 6),
          Text(
            'Zone ${user!.zone}',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
