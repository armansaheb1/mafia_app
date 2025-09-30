import 'package:flutter/material.dart';
import '../models/scenario.dart';
import '../services/role_ability_service.dart';

class ScenarioDetailScreen extends StatelessWidget {
  final Scenario scenario;

  const ScenarioDetailScreen({
    super.key,
    required this.scenario,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(scenario.name),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // اطلاعات کلی سناریو
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اطلاعات کلی',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      scenario.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
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
                          '${scenario.roles.length} نقش',
                          Colors.green,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // نقش‌های سناریو
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'نقش‌های این سناریو',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._buildRolesByType(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // قوانین بازی
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'قوانین بازی',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildGameRules(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRolesByType() {
    final rolesByType = <String, List<Role>>{};
    
    for (final scenarioRole in scenario.roles) {
      final roleType = scenarioRole.roleType;
      if (!rolesByType.containsKey(roleType)) {
        rolesByType[roleType] = [];
      }
      rolesByType[roleType]!.add(scenarioRole);
    }

    return [
      if (rolesByType.containsKey('town'))
        _buildRoleTypeSection('شهروندان', rolesByType['town']!, Colors.blue),
      if (rolesByType.containsKey('mafia'))
        _buildRoleTypeSection('مافیا', rolesByType['mafia']!, Colors.red),
      if (rolesByType.containsKey('neutral'))
        _buildRoleTypeSection('خنثی', rolesByType['neutral']!, Colors.orange),
      if (rolesByType.containsKey('special'))
        _buildRoleTypeSection('ویژه', rolesByType['special']!, Colors.purple),
    ];
  }

  Widget _buildRoleTypeSection(String title, List<Role> roles, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        ...roles.map((scenarioRole) => _buildRoleCard(scenarioRole, color)),
      ],
    );
  }

  Widget _buildRoleCard(Role scenarioRole, Color color) {
    final role = scenarioRole;
    final icon = RoleAbilityService.getRoleIcon(role);
    final abilities = RoleAbilityService.getAbilityDescription(role);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: color.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${role.displayName} (${1} نفر)',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              role.description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            if (abilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'توانایی‌ها: $abilities',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGameRules() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRuleItem('🌙 شب', 'نقش‌های ویژه اقدامات خود را انجام می‌دهند'),
        _buildRuleItem('☀️ روز', 'همه بازیکنان بحث می‌کنند و رای‌گیری می‌کنند'),
        _buildRuleItem('🏆 برد مافیا', 'وقتی تعداد مافیا برابر یا بیشتر از شهروندان شود'),
        _buildRuleItem('🏆 برد شهروندان', 'وقتی همه مافیا کشته شوند'),
        _buildRuleItem('⚖️ رای‌گیری', 'بازیکن با بیشترین رای اعدام می‌شود'),
        _buildRuleItem('🔄 ادامه بازی', 'بازی تا تعیین برنده ادامه می‌یابد'),
      ],
    );
  }

  Widget _buildRuleItem(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
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
}
