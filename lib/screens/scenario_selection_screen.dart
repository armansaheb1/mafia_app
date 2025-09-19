import 'package:flutter/material.dart';
import '../models/scenario.dart';
import '../services/scenario_service.dart';
import '../services/role_ability_service.dart';
import 'create_room_screen.dart';
import 'scenario_detail_screen.dart';

class ScenarioSelectionScreen extends StatefulWidget {
  final String? currentFilter;
  
  const ScenarioSelectionScreen({super.key, this.currentFilter});

  @override
  State<ScenarioSelectionScreen> createState() => _ScenarioSelectionScreenState();
}

class _ScenarioSelectionScreenState extends State<ScenarioSelectionScreen> {
  List<Scenario> scenarios = [];
  Scenario? selectedScenario;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadScenarios();
  }

  Future<void> _loadScenarios() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final loadedScenarios = await ScenarioService.getScenarios();
      setState(() {
        scenarios = loadedScenarios;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('انتخاب سناریو'),
        centerTitle: true,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorWidget()
              : _buildScenarioList(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'خطا در بارگذاری سناریوها',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            error!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _loadScenarios,
            icon: const Icon(Icons.refresh),
            label: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioList() {
    if (scenarios.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.games_outlined,
              size: 64,
              color: Colors.grey,
            ),
            SizedBox(height: 16),
            Text(
              'هیچ سناریویی یافت نشد',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scenarios.length,
            itemBuilder: (context, index) {
              final scenario = scenarios[index];
              final isSelected = selectedScenario?.id == scenario.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: isSelected ? 8 : 2,
                color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
                child: InkWell(
                  onTap: () {
                    setState(() {
                      selectedScenario = scenario;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                scenario.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isSelected ? Theme.of(context).primaryColor : null,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ScenarioDetailScreen(scenario: scenario),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.info_outline),
                              tooltip: 'جزئیات سناریو',
                            ),
                            if (isSelected)
                              Icon(
                                Icons.check_circle,
                                color: Theme.of(context).primaryColor,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          scenario.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildInfoChip(
                              Icons.people,
                              '${scenario.minPlayers}-${scenario.maxPlayers} بازیکن',
                              Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            _buildInfoChip(
                              Icons.category,
                              '${scenario.scenarioRoles.length} نقش',
                              Colors.green,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildRolesPreview(scenario),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (selectedScenario != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CreateRoomScreen(
                          selectedScenario: selectedScenario!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('ایجاد اتاق با این سناریو'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context, selectedScenario);
                  },
                  icon: const Icon(Icons.filter_list),
                  label: const Text('فیلتر کردن اتاق‌ها'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      selectedScenario = null;
                    });
                  },
                  icon: const Icon(Icons.clear),
                  label: const Text('لغو انتخاب'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRolesPreview(Scenario scenario) {
    final townRoles = ScenarioService.getTownRoles(scenario);
    final mafiaRoles = ScenarioService.getMafiaRoles(scenario);
    final neutralRoles = ScenarioService.getNeutralRoles(scenario);
    final specialRoles = ScenarioService.getSpecialRoles(scenario);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            if (townRoles.isNotEmpty)
              _buildRoleChip('شهر', townRoles.length, Colors.blue),
            if (mafiaRoles.isNotEmpty)
              _buildRoleChip('مافیا', mafiaRoles.length, Colors.red),
            if (neutralRoles.isNotEmpty)
              _buildRoleChip('خنثی', neutralRoles.length, Colors.orange),
            if (specialRoles.isNotEmpty)
              _buildRoleChip('ویژه', specialRoles.length, Colors.purple),
          ],
        ),
        const SizedBox(height: 8),
        _buildDetailedRolesList(scenario),
      ],
    );
  }

  Widget _buildDetailedRolesList(Scenario scenario) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نقش‌های این سناریو:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: scenario.scenarioRoles.map((scenarioRole) {
              final role = scenarioRole.role;
              final color = _getRoleColor(role.roleType);
              return _buildRoleDetailChip(
                role.displayName,
                scenarioRole.count,
                color,
                RoleAbilityService.getRoleIcon(role),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String roleType) {
    switch (roleType) {
      case 'town':
        return Colors.blue;
      case 'mafia':
        return Colors.red;
      case 'neutral':
        return Colors.orange;
      case 'special':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRoleDetailChip(String roleName, int count, Color color, String icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 2),
          Text(
            '$roleName ($count)',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String type, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$type ($count)',
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
