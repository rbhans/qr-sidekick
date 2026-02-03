import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/equipment_config.dart';
import '../../../data/models/station.dart';
import '../../../data/datasources/supabase_datasource.dart';
import '../../providers/equipment_config_provider.dart';
import '../../providers/station_provider.dart';
import '../../providers/niagara_provider.dart';
import '../../providers/scan_history_provider.dart';

/// Equipment detail screen - shows live data from scanned QR code
class EquipmentScreen extends ConsumerStatefulWidget {
  final String qrId;

  const EquipmentScreen({super.key, required this.qrId});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  bool _isLoading = true;
  String? _error;
  EquipmentConfig? _config;
  Station? _station;
  List<PointValue> _points = [];
  CredentialSource _credentialSource = CredentialSource.none;
  bool _isConnected = false;
  DateTime? _lastUpdate;
  final _newNoteController = TextEditingController();
  bool _isAddingNote = false;
  bool _isSavingNote = false;
  List<NoteEntry> _notes = [];
  final Set<String> _expandedNotes = {};
  final PageController _notesPageController = PageController();
  int _currentNotesPage = 0;
  static const int _notesPerPage = 2;

  @override
  void initState() {
    super.initState();
    _loadEquipmentData();
  }

  @override
  void dispose() {
    _newNoteController.dispose();
    _notesPageController.dispose();
    super.dispose();
  }

  Future<void> _addNote() async {
    if (_config == null || _newNoteController.text.trim().isEmpty) return;

    setState(() => _isSavingNote = true);

    try {
      final repository = ref.read(equipmentConfigRepositoryProvider);
      final userId = ref.read(supabaseClientProvider).auth.currentUser?.id;

      final note = NoteEntry.create(
        content: _newNoteController.text.trim(),
        createdBy: userId,
      );

      final updatedNotes = await repository.addNote(_config!.qrId, note);

      setState(() {
        _notes = updatedNotes;
        _newNoteController.clear();
        _isAddingNote = false;
        _isSavingNote = false;
        _currentNotesPage = 0;
      });
      // Reset to first page to show new note
      if (_notesPageController.hasClients) {
        _notesPageController.jumpToPage(0);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note added'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      setState(() => _isSavingNote = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add note: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _deleteNote(String noteId) async {
    if (_config == null) return;

    try {
      final repository = ref.read(equipmentConfigRepositoryProvider);
      final updatedNotes = await repository.deleteNote(_config!.qrId, noteId);

      setState(() {
        _notes = updatedNotes;
        _expandedNotes.remove(noteId);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted'), duration: Duration(seconds: 1)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete note: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _loadEquipmentData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch equipment config from Supabase
      final repository = ref.read(equipmentConfigRepositoryProvider);
      final config = await repository.getByQrId(widget.qrId);

      if (config == null) {
        setState(() {
          _isLoading = false;
          _error = 'Equipment not found.\n\nThis QR code is not registered in the system.';
        });
        return;
      }

      // Get station
      final stationRepo = ref.read(stationRepositoryProvider);
      final station = await stationRepo.getStation(config.stationId);

      if (station == null) {
        setState(() {
          _isLoading = false;
          _config = config;
          _error = 'Station not found.\n\nThe station for this equipment has been deleted.';
        });
        return;
      }

      // Check credential source (local first, then shared)
      final credStatus = await ref.read(stationCredentialStatusProvider(station.id).future);

      setState(() {
        _config = config;
        _station = station;
        _credentialSource = credStatus;
        _notes = config.noteEntries ?? [];
      });

      // Save to scan history
      ref.read(scanHistoryNotifierProvider.notifier).addScan(
        qrId: config.qrId,
        equipmentName: config.equipmentName,
      );

      if (credStatus != CredentialSource.none) {
        // Fetch live data
        await _fetchLiveData();
      } else {
        // Show placeholder points
        final placeholderPoints = config.pointPaths.map((path) {
          return PointValue(
            path: path,
            name: path.split('/').last,
            value: '--',
          );
        }).toList();

        setState(() {
          _isLoading = false;
          _points = placeholderPoints;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _fetchLiveData() async {
    if (_config == null || _station == null) return;

    final niagaraClient = ref.read(niagaraClientProvider);

    try {
      // Get credentials (checks local first, then shared)
      final creds = await ref.read(stationCredentialsProvider(_station!.id).future);

      if (creds == null) {
        setState(() {
          _isLoading = false;
          _credentialSource = CredentialSource.none;
        });
        return;
      }

      // Store credentials locally if they came from shared (for faster future access)
      if (_credentialSource == CredentialSource.shared) {
        await niagaraClient.storeCredentials(
          stationId: _station!.id,
          username: creds.username,
          password: creds.password,
        );
      }

      final results = await niagaraClient.readPoints(
        station: _station!,
        pointPaths: _config!.pointPaths,
      );

      final points = <PointValue>[];
      bool anySuccess = false;

      for (int i = 0; i < results.length; i++) {
        final result = results[i];
        if (result.isSuccess && result.point != null) {
          points.add(result.point!);
          anySuccess = true;
        } else {
          // Add error placeholder
          points.add(PointValue(
            path: _config!.pointPaths[i],
            name: _config!.pointPaths[i].split('/').last,
            value: '--',
            status: 'error',
          ));
        }
      }

      setState(() {
        _isLoading = false;
        _points = points;
        _isConnected = anySuccess;
        _lastUpdate = DateTime.now();
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isConnected = false;
        // Keep existing points but mark as potentially stale
      });
    }
  }

  void _showCredentialsDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Station Login'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter credentials for ${_station?.name ?? 'station'}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                enabled: !isLoading,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  errorMessage!,
                  style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (usernameController.text.isEmpty ||
                          passwordController.text.isEmpty) {
                        setDialogState(() {
                          errorMessage = 'Please enter both username and password';
                        });
                        return;
                      }

                      setDialogState(() {
                        isLoading = true;
                        errorMessage = null;
                      });

                      final niagaraClient = ref.read(niagaraClientProvider);
                      final result = await niagaraClient.testConnection(
                        station: _station!,
                        username: usernameController.text,
                        password: passwordController.text,
                      );

                      if (result.isSuccess) {
                        // Store credentials locally
                        await niagaraClient.storeCredentials(
                          stationId: _station!.id,
                          username: usernameController.text,
                          password: passwordController.text,
                        );

                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {
                            _credentialSource = CredentialSource.local;
                            _isLoading = true;
                          });
                          _fetchLiveData();
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = result.errorMessage;
                        });
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Text(
          _config?.equipmentName ?? '[ EQUIPMENT ]',
          style: const TextStyle(
            fontFamily: 'JetBrains Mono',
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _credentialSource != CredentialSource.none
                ? _fetchLiveData
                : _loadEquipmentData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text(
              'Loading equipment data...',
              style: TextStyle(
                fontFamily: 'JetBrains Mono',
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              const Text(
                '[ ERROR ]',
                style: TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadEquipmentData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _credentialSource != CredentialSource.none
          ? _fetchLiveData
          : _loadEquipmentData,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Equipment header card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                        ),
                        child: const Icon(
                          Icons.hvac,
                          color: AppColors.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _config?.equipmentName ?? 'Unknown',
                              style: const TextStyle(
                                fontFamily: 'JetBrains Mono',
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              _station?.name ?? '',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(),
                    ],
                  ),
                  if (_config?.location != null && _config!.location!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 14, color: AppColors.textTertiary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _config!.location!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _config?.equipmentPath ?? '',
                    style: const TextStyle(
                      fontFamily: 'JetBrains Mono',
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '[ NOTES ]',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                if (!_isAddingNote)
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () => setState(() => _isAddingNote = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.primary,
                    tooltip: 'Add note',
                  ),
              ],
            ),
          ),

          // Add note form
          if (_isAddingNote) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _newNoteController,
                      maxLines: 3,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Write a note...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.all(12),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _newNoteController.clear();
                            setState(() => _isAddingNote = false);
                          },
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _isSavingNote ? null : _addNote,
                          child: _isSavingNote
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Add'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Notes list with pagination
          if (_notes.isEmpty && !_isAddingNote)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.note_add, size: 32, color: AppColors.textTertiary),
                      const SizedBox(height: 8),
                      const Text(
                        'No notes yet',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => setState(() => _isAddingNote = true),
                        child: const Text('Add first note'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else ...[
            _buildNotesCarousel(),
          ],

          const SizedBox(height: 16),

          // Connection prompt if no credentials
          if (_credentialSource == CredentialSource.none) ...[
            Card(
              child: InkWell(
                onTap: _showCredentialsDialog,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                        ),
                        child: const Icon(
                          Icons.vpn_key,
                          color: AppColors.warning,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Login Required',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Enter station credentials to view live data',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                const Text(
                  '[ POINTS ]',
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_points.length} configured',
                  style: const TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),

          // Point cards
          if (_points.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No points configured',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
            )
          else
            ..._points.map((point) => _buildPointCard(point)),

          const SizedBox(height: 24),

          // Last update info
          if (_lastUpdate != null)
            Center(
              child: Text(
                'Last updated: ${_formatTime(_lastUpdate!)}',
                style: const TextStyle(
                  fontFamily: 'JetBrains Mono',
                  fontSize: 11,
                  color: AppColors.textTertiary,
                ),
              ),
            ),

          const SizedBox(height: 16),

          // QR ID footer
          Center(
            child: Text(
              'QR: ${widget.qrId}',
              style: const TextStyle(
                fontFamily: 'JetBrains Mono',
                fontSize: 10,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    final Color color;
    final String text;

    if (_credentialSource == CredentialSource.none) {
      color = AppColors.warning;
      text = 'NO LOGIN';
    } else if (_isConnected) {
      color = AppColors.success;
      text = 'ONLINE';
    } else {
      color = AppColors.error;
      text = 'OFFLINE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'JetBrains Mono',
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNotesCarousel() {
    final totalPages = (_notes.length / _notesPerPage).ceil();

    // If only 1-2 notes, just show them directly
    if (_notes.length <= _notesPerPage) {
      return Column(
        children: _notes.map((note) => _buildNoteCard(note)).toList(),
      );
    }

    return Column(
      children: [
        // PageView for notes
        SizedBox(
          height: 195, // Fixed height for carousel
          child: PageView.builder(
            controller: _notesPageController,
            itemCount: totalPages,
            onPageChanged: (page) => setState(() => _currentNotesPage = page),
            itemBuilder: (context, pageIndex) {
              final startIndex = pageIndex * _notesPerPage;
              final endIndex = (startIndex + _notesPerPage).clamp(0, _notes.length);
              final pageNotes = _notes.sublist(startIndex, endIndex);

              return Column(
                children: pageNotes.map((note) => _buildNoteCard(note)).toList(),
              );
            },
          ),
        ),

        // Page indicator dots
        if (totalPages > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Left arrow
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 20),
                onPressed: _currentNotesPage > 0
                    ? () => _notesPageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : null,
                color: _currentNotesPage > 0 ? AppColors.primary : AppColors.textTertiary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              // Dots
              ...List.generate(totalPages, (index) {
                final isActive = index == _currentNotesPage;
                return GestureDetector(
                  onTap: () => _notesPageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  ),
                  child: Container(
                    width: isActive ? 20 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive ? AppColors.primary : AppColors.textTertiary.withValues(alpha: 0.3),
                    ),
                  ),
                );
              }),
              const SizedBox(width: 8),
              // Right arrow
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 20),
                onPressed: _currentNotesPage < totalPages - 1
                    ? () => _notesPageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        )
                    : null,
                color: _currentNotesPage < totalPages - 1 ? AppColors.primary : AppColors.textTertiary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          // Page count text
          Text(
            '${_currentNotesPage + 1} of $totalPages',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNoteCard(NoteEntry note) {
    final isExpanded = _expandedNotes.contains(note.id);
    final dateFormat = DateFormat('MMM d @ h:mm a');
    final firstLine = note.content.split('\n').first;
    final hasMoreContent = note.content.contains('\n') || note.content.length > 60;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: hasMoreContent
            ? () {
                setState(() {
                  if (isExpanded) {
                    _expandedNotes.remove(note.id);
                  } else {
                    _expandedNotes.add(note.id);
                  }
                });
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      dateFormat.format(note.createdAt),
                      style: const TextStyle(
                        fontFamily: 'JetBrains Mono',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (hasMoreContent)
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: AppColors.textTertiary,
                    ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    onPressed: () => _confirmDeleteNote(note),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    color: AppColors.textTertiary,
                    tooltip: 'Delete note',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isExpanded ? note.content : (hasMoreContent ? '$firstLine...' : note.content),
                style: const TextStyle(fontSize: 13),
                maxLines: isExpanded ? null : 1,
                overflow: isExpanded ? null : TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteNote(NoteEntry note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Note?'),
        content: Text(
          'Delete note from ${DateFormat('MMM d, yyyy').format(note.createdAt)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteNote(note.id);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildPointCard(PointValue point) {
    final rawStatus = point.status?.toLowerCase() ?? '';

    // Niagara standard status colors
    const niagaraAlarm = Color(0xFFCF1624);      // #cf1624
    const niagaraDisabled = Color(0xFFD6D6D6);   // #d6d6d6
    const niagaraFault = Color(0xFFFC7734);      // #fc7734
    const niagaraDown = Color(0xFFFAC600);       // #fac600
    const niagaraStale = Color(0xFFD9C09D);      // #d9c09d
    const niagaraOverridden = Color(0xFFBFADDD); // #bfaddd

    // Determine status color
    Color statusColor = AppColors.textPrimary; // default/ok
    if (rawStatus.contains('alarm')) {
      statusColor = niagaraAlarm;
    } else if (rawStatus.contains('fault')) {
      statusColor = niagaraFault;
    } else if (rawStatus.contains('down')) {
      statusColor = niagaraDown;
    } else if (rawStatus.contains('stale')) {
      statusColor = niagaraStale;
    } else if (rawStatus.contains('overridden')) {
      statusColor = niagaraOverridden;
    } else if (rawStatus.contains('disabled')) {
      statusColor = niagaraDisabled;
    }

    // Clean up status text for display (remove braces)
    final statusText = point.status?.replaceAll(RegExp(r'[{}]'), '') ?? '';
    final isOk = rawStatus.contains('ok') || rawStatus.isEmpty;
    final hasStatus = !isOk && statusText.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                point.name,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  point.value,
                  style: TextStyle(
                    fontFamily: 'JetBrains Mono',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: hasStatus ? statusColor : AppColors.textPrimary,
                  ),
                ),
                if (hasStatus) ...[
                  const SizedBox(height: 2),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColor,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inSeconds < 5) {
      return 'just now';
    } else if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
