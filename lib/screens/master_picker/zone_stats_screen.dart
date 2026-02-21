import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_endpoints.dart';
import '../../services/api_service.dart';

class ZoneStatsScreen extends StatefulWidget {
  const ZoneStatsScreen({super.key});

  @override
  State<ZoneStatsScreen> createState() => _ZoneStatsScreenState();
}

class _ZoneStatsScreenState extends State<ZoneStatsScreen> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _zones = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchStats());
  }

  Future<void> _fetchStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiService = context.read<AuthProvider>().apiService;
      final response = await apiService.get(ApiEndpoints.pickerZoneStats);
      final body = apiService.handleResponse(response);

      final List<dynamic> raw;
      if (body['zones'] is List) {
        raw = body['zones'] as List<dynamic>;
      } else if (body['data'] is List) {
        raw = body['data'] as List<dynamic>;
      } else {
        // Single zone object
        raw = [body];
      }

      setState(() {
        _zones = raw.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.zoneStats),
        centerTitle: true,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchStats,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchStats,
              icon: const Icon(Icons.refresh),
              label: Text(S.retry),
            ),
          ],
        ),
      );
    }

    if (_zones.isEmpty) {
      return const Center(child: Text('No zone stats available', style: TextStyle(fontSize: 16, color: Colors.grey)));
    }

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _zones.length,
        itemBuilder: (context, index) => _buildZoneCard(_zones[index]),
      ),
    );
  }

  /// Fair ranking score based on:
  /// - Tasks completed (40%)
  /// - Items picked (25%)
  /// - Speed: lower avg time = higher score (20%)
  /// - Quality: fewer exceptions = higher score (15%)
  double _pickerScore(Map<String, dynamic> picker) {
    final last12h = picker['last_12h'] as Map<String, dynamic>? ?? {};
    final tasks = (last12h['tasks_completed'] as num?)?.toDouble() ?? 0;
    final items = (last12h['items_picked'] as num?)?.toDouble() ?? 0;
    final exceptions = (last12h['exceptions'] as num?)?.toDouble() ?? 0;
    final avgTime = (last12h['avg_completion_time_minutes'] as num?)?.toDouble() ?? 0;

    if (tasks == 0) return -1; // no work = bottom

    // Speed score: faster = better (cap at 20 min, invert so lower time = higher score)
    final speedScore = avgTime > 0 ? (20.0 - avgTime).clamp(0, 20) : 0.0;

    // Exception rate: fewer per task = better
    final exceptionRate = tasks > 0 ? (exceptions / tasks) : 0.0;
    final qualityScore = (1.0 - exceptionRate).clamp(0, 1) * 100;

    return (tasks * 0.40) + (items * 0.25) + (speedScore * 0.20) + (qualityScore * 0.15);
  }

  Widget _buildZoneCard(Map<String, dynamic> zone) {
    final zoneName = zone['zone_name']?.toString() ?? '';
    final totalPickers = zone['total_pickers'] ?? 0;
    final onlineCount = zone['online_count'] ?? 0;
    final pickers = (zone['pickers'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    // Sort: online first, then by score descending
    pickers.sort((a, b) {
      final aOnline = a['is_online'] == true ? 0 : 1;
      final bOnline = b['is_online'] == true ? 0 : 1;
      if (aOnline != bOnline) return aOnline.compareTo(bOnline);
      return _pickerScore(b).compareTo(_pickerScore(a));
    });

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        leading: const Icon(Icons.grid_view, color: AppColors.primary),
        title: Text(zoneName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Icon(Icons.people, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text('$totalPickers', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            const SizedBox(width: 12),
            Icon(Icons.circle, size: 10, color: onlineCount > 0 ? Colors.green : Colors.grey),
            const SizedBox(width: 4),
            Text('$onlineCount ${S.active}', style: TextStyle(fontSize: 13, color: onlineCount > 0 ? Colors.green[700] : Colors.grey)),
          ],
        ),
        initiallyExpanded: false,
        children: [
          const Divider(height: 1),
          ...pickers.asMap().entries.map((e) => _buildPickerTile(e.value, zoneName, rank: e.key)),
        ],
      ),
    );
  }

  Widget _buildPickerTile(Map<String, dynamic> picker, String zoneName, {int rank = 0}) {
    final name = picker['picker_name']?.toString() ?? '';
    final employeeId = picker['employee_id']?.toString() ?? '';
    final isOnline = picker['is_online'] == true;
    final isOnDuty = picker['is_on_duty'] == true;
    final activity = picker['current_activity']?.toString() ?? '';
    final role = picker['role']?.toString() ?? '';
    final last12h = picker['last_12h'] as Map<String, dynamic>? ?? {};

    final tasksCompleted = last12h['tasks_completed'] ?? 0;
    final itemsPicked = last12h['items_picked'] ?? 0;
    final exceptions = last12h['exceptions'] ?? 0;
    final avgTime = (last12h['avg_completion_time_minutes'] as num?)?.toDouble() ?? 0.0;

    final score = _pickerScore(picker);
    final isTop = rank == 0 && (tasksCompleted as num) > 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: isTop
          ? BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Online indicator + rank icon
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: isTop
                ? const Icon(Icons.emoji_events, size: 20, color: Colors.amber)
                : Icon(Icons.circle, size: 10, color: isOnline ? Colors.green : Colors.grey[400]),
          ),
          const SizedBox(width: 10),
          // Picker info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name ($zoneName)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isTop ? Colors.amber[900] : null,
                        ),
                      ),
                    ),
                    if (score > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isTop ? Colors.amber.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          score.toStringAsFixed(1),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isTop ? Colors.amber[800] : Colors.grey[600]),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _buildRoleBadge(role),
                    const SizedBox(width: 6),
                    if (!isOnDuty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(S.offDuty, style: const TextStyle(fontSize: 10, color: Colors.red)),
                      ),
                    if (isOnDuty && activity == 'PICKING')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(S.statusInProgress, style: const TextStyle(fontSize: 10, color: Colors.blue)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                // Last 12h stats
                Row(
                  children: [
                    _buildMiniStat(Icons.check_circle_outline, '$tasksCompleted', Colors.green),
                    const SizedBox(width: 12),
                    _buildMiniStat(Icons.inventory_2_outlined, '$itemsPicked', Colors.blue),
                    const SizedBox(width: 12),
                    if (exceptions > 0) ...[
                      _buildMiniStat(Icons.warning_amber, '$exceptions', Colors.orange),
                      const SizedBox(width: 12),
                    ],
                    _buildMiniStat(Icons.timer_outlined, '${avgTime.toStringAsFixed(1)}m', Colors.purple),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    String label;
    Color color;
    switch (role) {
      case 'ROLE_MASTER_PICKER':
        label = 'Master';
        color = Colors.deepPurple;
        break;
      case 'ROLE_QC_EMPLOYEE':
        label = 'QC';
        color = Colors.teal;
        break;
      default:
        label = S.picker;
        color = AppColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(value, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
