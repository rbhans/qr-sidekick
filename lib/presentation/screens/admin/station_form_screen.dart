import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/station.dart';
import '../../../data/services/niagara_client.dart';
import '../../providers/equipment_config_provider.dart';
import '../../providers/station_provider.dart';
import '../../providers/niagara_provider.dart';

/// Add/Edit station screen
class StationFormScreen extends ConsumerStatefulWidget {
  final String? stationId;

  const StationFormScreen({super.key, this.stationId});

  bool get isEditing => stationId != null;

  @override
  ConsumerState<StationFormScreen> createState() => _StationFormScreenState();
}

class _StationFormScreenState extends ConsumerState<StationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostController = TextEditingController();
  final _portController = TextEditingController(text: '443');
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  StationProtocol _protocol = StationProtocol.https;
  bool _isLoading = false;
  bool _isInitialized = false;
  bool _isTesting = false;
  bool _hasLocalCredentials = false;
  NiagaraConnectionResult? _testResult;

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initializeFromStation(Station station) async {
    if (_isInitialized) return;
    _nameController.text = station.name;
    _hostController.text = station.host;
    _portController.text = station.port.toString();
    _protocol = station.protocol;
    _isInitialized = true;

    // Check credential status
    final client = ref.read(niagaraClientProvider);
    final hasLocal = await client.hasCredentials(station.id);

    if (mounted) {
      setState(() {
        _hasLocalCredentials = hasLocal;
      });
    }
  }

  Future<void> _testConnection() async {
    // Validate host and port first
    if (_hostController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a host address'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter credentials to test connection'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final client = ref.read(niagaraClientProvider);

    // Create a temporary station object for testing
    final testStation = Station(
      id: widget.stationId ?? 'temp',
      organizationId: null,
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 443,
      protocol: _protocol,
      createdBy: 'temp',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final result = await client.testConnection(
      station: testStation,
      username: _usernameController.text,
      password: _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isTesting = false;
        _testResult = result;
      });

      if (result.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection successful!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(stationNotifierProvider.notifier);
      final client = ref.read(niagaraClientProvider);
      String stationId;

      if (widget.isEditing) {
        await notifier.updateStation(
          id: widget.stationId!,
          name: _nameController.text.trim(),
          host: _hostController.text.trim(),
          port: int.parse(_portController.text.trim()),
          protocol: _protocol,
        );
        stationId = widget.stationId!;
      } else {
        final station = await notifier.createStation(
          name: _nameController.text.trim(),
          host: _hostController.text.trim(),
          port: int.parse(_portController.text.trim()),
          protocol: _protocol,
        );
        stationId = station.id;
      }

      // Handle credentials if provided
      if (_usernameController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty) {
        await client.storeCredentials(
          stationId: stationId,
          username: _usernameController.text,
          password: _passwordController.text,
        );

        // Invalidate cached credential providers so they re-read from storage
        ref.invalidate(stationCredentialStatusProvider(stationId));
        ref.invalidate(stationCredentialsProvider(stationId));
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? 'Station updated' : 'Station created'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Load existing station data if editing
    if (widget.isEditing) {
      final stationAsync = ref.watch(stationProvider(widget.stationId!));
      stationAsync.whenData((station) {
        if (station != null) {
          _initializeFromStation(station);
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          widget.isEditing ? '[ EDIT STATION ]' : '[ ADD STATION ]',
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 18,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Name field
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Station Name',
                  hintText: 'e.g., Building 1 JACE',
                  prefixIcon: Icon(Icons.label_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a station name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Host field
              TextFormField(
                controller: _hostController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Host',
                  hintText: 'e.g., 192.168.1.100 or station.example.com',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a host address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Port field
              TextFormField(
                controller: _portController,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port',
                  hintText: '443',
                  prefixIcon: Icon(Icons.numbers),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a port';
                  }
                  final port = int.tryParse(value.trim());
                  if (port == null || port < 1 || port > 65535) {
                    return 'Please enter a valid port (1-65535)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Protocol selection
              const Text(
                '[ PROTOCOL ]',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _ProtocolButton(
                      label: 'HTTPS',
                      isSelected: _protocol == StationProtocol.https,
                      onTap: () => setState(() => _protocol = StationProtocol.https),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ProtocolButton(
                      label: 'HTTP',
                      isSelected: _protocol == StationProtocol.http,
                      onTap: () => setState(() => _protocol = StationProtocol.http),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Credentials section
              Row(
                children: [
                  const Text(
                    '[ CREDENTIALS ]',
                    style: TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      letterSpacing: 1,
                    ),
                  ),
                  if (_hasLocalCredentials) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        border: Border.all(color: AppColors.success),
                      ),
                      child: const Text(
                        'SAVED',
                        style: TextStyle(
                          fontFamily: 'JetBrains Mono',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _hasLocalCredentials
                    ? 'Enter new credentials to update.'
                    : 'Credentials are stored securely on device.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Niagara username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  hintText: 'Niagara password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 24),

              // Test connection button
              OutlinedButton.icon(
                onPressed: _isTesting ? null : _testConnection,
                icon: _isTesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi_tethering),
                label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
              ),

              // Test result
              if (_testResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_testResult!.isSuccess
                            ? AppColors.success
                            : AppColors.error)
                        .withValues(alpha: 0.1),
                    border: Border.all(
                      color: _testResult!.isSuccess
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _testResult!.isSuccess
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: _testResult!.isSuccess
                            ? AppColors.success
                            : AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testResult!.isSuccess
                              ? 'Connection successful'
                              : _testResult!.errorMessage ?? 'Connection failed',
                          style: TextStyle(
                            fontSize: 13,
                            color: _testResult!.isSuccess
                                ? AppColors.success
                                : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // Submit button
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(widget.isEditing ? 'Update Station' : 'Add Station'),
              ),

              if (widget.isEditing) ...[
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _isLoading ? null : () => _showDeleteDialog(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Delete Station'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Station?'),
        content: const Text(
          'This will also delete all equipment configs associated with this station. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                // Delete stored credentials
                final client = ref.read(niagaraClientProvider);
                await client.deleteCredentials(widget.stationId!);

                // Delete station (cascade deletes equipment configs)
                await ref
                    .read(stationNotifierProvider.notifier)
                    .deleteStation(widget.stationId!);
                // Refresh equipment configs since cascade delete removed them
                ref.invalidate(equipmentConfigNotifierProvider);
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Station deleted'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _ProtocolButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ProtocolButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrains Mono',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppColors.background : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
