// lib/screens/create_room_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/game_provider.dart';
import '../models/scenario.dart';
import '../services/scenario_service.dart';
import 'lobby_screen.dart';
import 'scenario_selection_screen.dart';

class CreateRoomScreen extends StatefulWidget {
  final Scenario? selectedScenario;
  
  const CreateRoomScreen({super.key, this.selectedScenario});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNameController = TextEditingController();
  final _passwordController = TextEditingController();
  int _maxPlayers = 8;
  bool _isPrivate = false;
  Scenario? _defaultScenario;
  bool _isLoadingScenario = true;
  Scenario? _selectedScenario;

  @override
  void initState() {
    super.initState();
    _selectedScenario = widget.selectedScenario;
    _loadDefaultScenario();
  }

  Future<void> _loadDefaultScenario() async {
    try {
      final scenarios = await ScenarioService.getScenarios();
      // پیدا کردن سناریو "کلاسیک ساده"
      final defaultScenario = scenarios.firstWhere(
        (scenario) => scenario.name == 'کلاسیک ساده',
        orElse: () => scenarios.first,
      );
      
      setState(() {
        _defaultScenario = defaultScenario;
        _isLoadingScenario = false;
        // تنظیم _maxPlayers به مقدار معتبر
        _maxPlayers = defaultScenario.minPlayers;
      });
    } catch (e) {
      setState(() {
        _isLoadingScenario = false;
        // در صورت خطا، مقدار پیش‌فرض تنظیم کن
        _maxPlayers = 8;
      });
    }
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // استفاده از سناریو انتخاب شده یا سناریو پیش‌فرض
    final scenario = _selectedScenario ?? _defaultScenario;
    
    if (scenario != null) {
      if (!ScenarioService.isPlayerCountValid(scenario, _maxPlayers)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعداد بازیکنان باید بین ${scenario.minPlayers} تا ${scenario.maxPlayers} باشد',
            ),
          ),
        );
        return;
      }
    }

    try {
      await Provider.of<GameProvider>(context, listen: false).createRoom(
        _roomNameController.text,
        _maxPlayers,
        _isPrivate,
        _passwordController.text,
        scenario?.id,
      );

      // بعد از ساخت اتاق موفق، به لابی برو
      // ignore: use_build_context_synchronously
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => LobbyScreen(),
        ),
      );
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطا در ساخت اتاق: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingScenario) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // اطمینان از معتبر بودن _maxPlayers
    _ensureValidMaxPlayers();

    return Scaffold(
      appBar: AppBar(title: const Text('ساخت اتاق جدید')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                // دکمه انتخاب سناریو
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.games,
                              color: Theme.of(context).primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'انتخاب سناریو',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_selectedScenario != null) ...[
                          // نمایش سناریو انتخاب شده
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedScenario!.name,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedScenario!.description,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildInfoChip(
                                      Icons.people,
                                      '${_selectedScenario!.minPlayers}-${_selectedScenario!.maxPlayers} بازیکن',
                                      Colors.blue,
                                    ),
                                    const SizedBox(width: 8),
                                    _buildInfoChip(
                                      Icons.category,
                                      '${_selectedScenario!.roles.length} نقش',
                                      Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  final result = await Navigator.push<Scenario>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (ctx) => const ScenarioSelectionScreen(),
                                    ),
                                  );
                                  
                                  if (result != null) {
                                    setState(() {
                                      _selectedScenario = result;
                                      _maxPlayers = result.minPlayers;
                                    });
                                  }
                                },
                                icon: const Icon(Icons.games),
                                label: Text(_selectedScenario != null ? 'تغییر سناریو' : 'انتخاب سناریو'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            if (_selectedScenario != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _selectedScenario = null;
                                    _maxPlayers = _defaultScenario?.minPlayers ?? 8;
                                  });
                                },
                                icon: const Icon(Icons.clear),
                                tooltip: 'حذف سناریو',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // نمایش اطلاعات سناریو پیش‌فرض (اگر سناریو انتخاب نشده)
                if (_selectedScenario == null && _defaultScenario != null) ...[
                  Card(
                    color: Colors.grey[100],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'سناریو پیش‌فرض',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _defaultScenario!.name,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _defaultScenario!.description,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildInfoChip(
                                Icons.people,
                                '${_defaultScenario!.minPlayers}-${_defaultScenario!.maxPlayers} بازیکن',
                                Colors.blue,
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                Icons.category,
                                '${_defaultScenario!.roles.length} نقش',
                                Colors.green,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                TextFormField(
                  controller: _roomNameController,
                  decoration: const InputDecoration(
                    labelText: 'نام اتاق',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'لطفاً نام اتاق را وارد کنید';
                    }
                    if (value.length < 3) {
                      return 'نام اتاق باید حداقل ۳ کاراکتر باشد';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  value: _getPlayerCountOptions().contains(_maxPlayers) ? _maxPlayers : null,
                  decoration: const InputDecoration(
                    labelText: 'تعداد بازیکنان',
                    border: OutlineInputBorder(),
                  ),
                  items: _getPlayerCountOptions()
                      .map((number) => DropdownMenuItem(
                            value: number,
                            child: Text('$number نفر'),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _maxPlayers = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('اتاق خصوصی'),
                  value: _isPrivate,
                  onChanged: (value) {
                    setState(() {
                      _isPrivate = value;
                    });
                  },
                ),
                if (_isPrivate) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'رمز عبور اتاق',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (_isPrivate && (value == null || value.isEmpty)) {
                        return 'برای اتاق خصوصی باید رمز عبور تعیین کنید';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _submitForm,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'ساخت اتاق',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<int> _getPlayerCountOptions() {
    final scenario = _selectedScenario ?? _defaultScenario;
    if (scenario == null) {
      return [4, 5, 6, 7, 8, 9, 10];
    }
    
    final List<int> options = [];
    for (int i = scenario.minPlayers; i <= scenario.maxPlayers; i++) {
      options.add(i);
    }
    
    // اطمینان از وجود حداقل یک گزینه
    if (options.isEmpty) {
      return [4, 5, 6, 7, 8, 9, 10];
    }
    
    return options;
  }

  void _ensureValidMaxPlayers() {
    final options = _getPlayerCountOptions();
    if (!options.contains(_maxPlayers)) {
      _maxPlayers = options.first;
    }
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

  @override
  void dispose() {
    _roomNameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}