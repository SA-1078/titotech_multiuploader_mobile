import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../services/cache_service.dart';
import '../services/folder_service.dart';
import '../services/queue_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/folder_picker_modal.dart';
import '../widgets/glass_card.dart';
import '../widgets/video_probe_card.dart';

class HomeScreen extends StatefulWidget {
  final Function(int) onTabChange;

  const HomeScreen({super.key, required this.onTabChange});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedMode = 'auto'; // 'auto', 'remuxOnly', 'compress'
  bool _syncToTito = true;
  String _defaultServer = 'earnvids';

  final List<String> _selectedProviders = ['doodstream', 'streamtape', 'savefiles', 'earnvids'];

  // Video & TitoStream metadata controllers
  final _titleController = TextEditingController();
  final _folderController = TextEditingController();
  final _seriesController = TextEditingController();
  final _seasonController = TextEditingController(text: '1');
  final _episodeController = TextEditingController(text: '1');

  List<TitoSeriesItem> _seriesList = [];
  String? _selectedSeriesId;
  List<String> _availableFolders = [];
  bool _isLoadingSeries = false;

  @override
  void initState() {
    super.initState();
    _loadSeries();
    _loadAvailableFolders();
  }

  Future<void> _loadSeries() async {
    setState(() => _isLoadingSeries = true);
    try {
      final list = await SyncService.fetchSeries();
      if (mounted) {
        setState(() {
          _seriesList = list;
          _isLoadingSeries = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSeries = false);
    }
  }

  Future<void> _loadAvailableFolders() async {
    final cat = await FolderService.getCatalog();
    if (mounted) {
      setState(() => _availableFolders = cat.flatNames);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _folderController.dispose();
    _seriesController.dispose();
    _seasonController.dispose();
    _episodeController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo(QueueService queue) async {
    final ok = await queue.pickVideo();
    if (ok && queue.stagedMetadata != null) {
      final base = p.basenameWithoutExtension(queue.stagedMetadata!.filename);
      final clean = base.replaceAll('_', ' ').replaceAll('.', ' ').trim();
      setState(() {
        if (_titleController.text.trim().isEmpty) {
          _titleController.text = clean;
        }
      });
    }
  }

  void _onProviderToggle(String providerKey) {
    setState(() {
      if (_selectedProviders.contains(providerKey)) {
        if (_selectedProviders.length > 1) {
          _selectedProviders.remove(providerKey);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debes seleccionar al menos 1 servidor.'),
              backgroundColor: AppTheme.bgCardLighter,
            ),
          );
        }
      } else {
        _selectedProviders.add(providerKey);
      }
    });
  }

  Future<void> _handleStartJob(QueueService queue) async {
    final meta = queue.stagedMetadata;
    if (meta == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un video primero.'),
          backgroundColor: AppTheme.bgCardLighter,
        ),
      );
      return;
    }

    final videoTitle = _titleController.text.trim().isNotEmpty
        ? _titleController.text.trim()
        : p.basenameWithoutExtension(meta.filename);

    final season = int.tryParse(_seasonController.text.trim()) ?? 1;
    final episode = int.tryParse(_episodeController.text.trim()) ?? 1;
    final seriesTitle = _seriesList.firstWhere(
      (s) => s.id == _selectedSeriesId,
      orElse: () => TitoSeriesItem(id: '', titulo: _seriesController.text.trim()),
    ).titulo;

    widget.onTabChange(1); // Cambiar a la pestaña de Monitor

    queue.startJob(
      seriesId: _selectedSeriesId ?? '',
      seriesTitle: seriesTitle,
      season: season,
      episode: episode,
      title: videoTitle,
      folderName: _folderController.text.trim().isNotEmpty ? _folderController.text.trim() : null,
      processingMode: _selectedMode,
      selectedProviders: _selectedProviders,
      syncToTitoStream: _syncToTito,
      defaultServer: _defaultServer,
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<QueueService>();
    final meta = queue.stagedMetadata;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryOrange, Color(0xFFEA580C)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cloud_upload_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TitoStream Multiuploader',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Carga masiva concurrente a 4 servidores',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.6)),
                        ),
                      ],
                    ),
                  ),
                  Tooltip(
                    message: 'Toca para vaciar la caché temporal',
                    child: InkWell(
                      onTap: () async {
                        final freed = await queue.clearCacheNow();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                freed > 0
                                    ? 'Caché liberada: ${CacheService.formatBytes(freed)} eliminados'
                                    : 'Caché completamente limpia (0 B)',
                              ),
                              backgroundColor: AppTheme.primaryOrange,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.bgCardLighter,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cleaning_services_rounded, size: 14, color: AppTheme.primaryOrange),
                            const SizedBox(width: 4),
                            Text(
                              queue.cacheSizeFormatted,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // PASO 1: SELECCIONAR VIDEO
              _buildSectionTitle('1. Archivo de Video', Icons.videocam_rounded),
              const SizedBox(height: 8),

              if (meta == null) ...[
                GlassCard(
                  onTap: () => _pickVideo(queue),
                  borderColor: AppTheme.borderMedium,
                  padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.video_library_rounded,
                            color: AppTheme.primaryOrange,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Seleccionar Video para Subir',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'MP4, MKV, AVI, WebM (se analizará con FFprobe)',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                VideoProbeCard(
                  metadata: meta,
                  storageCheck: queue.storageCheck,
                  onClear: () {
                    queue.clearStagedVideo();
                    setState(() => _titleController.clear());
                  },
                ),
              ],
              const SizedBox(height: 20),

              // PASO 2: NOMBRE / TÍTULO DEL VIDEO (VISIBLE Y EDITABLE)
              _buildSectionTitle('2. Nombre / Título del Video', Icons.drive_file_rename_outline_rounded),
              const SizedBox(height: 8),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Nombre que tendrán los archivos en los servidores y TitoStream:',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ej. La Era de Hielo (2002) 1080p',
                        prefixIcon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryOrange),
                        suffixIcon: _titleController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                                onPressed: () => setState(() => _titleController.clear()),
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // PASO 3: CARPETA EN SERVIDORES (CON SELECTOR REMOTO)
              _buildSectionTitle('3. Carpeta en los Servidores', Icons.folder_special_rounded),
              const SizedBox(height: 8),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Carpeta remota (streaming):',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            FolderPickerModal.show(
                              context,
                              initialFolder: _folderController.text,
                              onFolderSelected: (selected) {
                                setState(() {
                                  _folderController.text = selected;
                                  _folderController.selection = TextSelection.collapsed(offset: selected.length);
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_open_rounded, size: 14, color: AppTheme.primaryOrange),
                                SizedBox(width: 4),
                                Text(
                                  'Elegir Carpeta',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _folderController,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ej. La Era de Hielo, Mushoku Tensei...',
                        prefixIcon: const Icon(Icons.folder_outlined, size: 18, color: AppTheme.primaryOrange),
                        suffixIcon: _folderController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                                onPressed: () {
                                  setState(() => _folderController.clear());
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (_availableFolders.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      SizedBox(
                        height: 26,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _availableFolders.take(8).length,
                          separatorBuilder: (context, index) => const SizedBox(width: 6),
                          itemBuilder: (context, i) {
                            final f = _availableFolders[i];
                            final isSelected = _folderController.text.trim().toLowerCase() == f.toLowerCase();
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _folderController.text = f;
                                  _folderController.selection = TextSelection.collapsed(offset: f.length);
                                });
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.primaryOrange.withValues(alpha: 0.2)
                                      : Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.primaryOrange : AppTheme.borderSubtle,
                                  ),
                                ),
                                child: Text(
                                  f,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? AppTheme.primaryOrange : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // PASO 4: MODO DE OPTIMIZACIÓN
              _buildSectionTitle('4. Estrategia de Formato', Icons.tune_rounded),
              const SizedBox(height: 8),
              GlassCard(
                child: Column(
                  children: [
                    _buildModeOption(
                      id: 'auto',
                      title: 'Automático (Recomendado)',
                      subtitle: 'Evalúa codecs y aplica Remux o MediaCodec según compatibilidad.',
                      icon: Icons.auto_awesome,
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildModeOption(
                      id: 'remuxOnly',
                      title: 'Remux Rápido (-c copy)',
                      subtitle: 'Ultra rápido (1-3 seg). Solo cambia contenedor a MP4 con faststart.',
                      icon: Icons.bolt,
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 16),
                    _buildModeOption(
                      id: 'compress',
                      title: 'Transcodificar por Hardware',
                      subtitle: 'Fuerza H.264 MediaCodec (audio AAC) para compatibilidad total.',
                      icon: Icons.memory,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // PASO 5: SERVIDORES CONCURRENTES
              _buildSectionTitle('5. Servidores de Destino', Icons.cloud_done_rounded),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildProviderChip('doodstream', 'DoodStream', AppTheme.colorDood),
                  const SizedBox(width: 8),
                  _buildProviderChip('streamtape', 'Streamtape', AppTheme.colorTape),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildProviderChip('savefiles', 'SaveFiles', AppTheme.colorSavefiles),
                  const SizedBox(width: 8),
                  _buildProviderChip('earnvids', 'EarnVids', AppTheme.colorEarnvids),
                ],
              ),
              const SizedBox(height: 20),

              // PASO 6: METADATOS TITOSTREAM
              Row(
                children: [
                  Expanded(
                    child: _buildSectionTitle('6. Publicación en TitoStream', Icons.sync_alt_rounded),
                  ),
                  Switch(
                    value: _syncToTito,
                    onChanged: (v) => setState(() => _syncToTito = v),
                    activeThumbColor: AppTheme.primaryOrange,
                    activeTrackColor: AppTheme.primaryOrange.withValues(alpha: 0.3),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (_syncToTito) ...[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selector de Serie
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Serie en TitoStream:',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                          ),
                          if (_isLoadingSeries)
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryOrange),
                            )
                          else
                            InkWell(
                              onTap: _loadSeries,
                              child: const Icon(Icons.refresh, size: 16, color: AppTheme.textMuted),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (_seriesList.isNotEmpty)
                        DropdownButtonFormField<String>(
                          initialValue: _selectedSeriesId,
                          hint: const Text('Seleccionar serie existente...', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
                          dropdownColor: AppTheme.bgCardLighter,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            fillColor: AppTheme.bgCardLighter,
                          ),
                          items: _seriesList.map((s) {
                            return DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(
                                s.titulo,
                                style: const TextStyle(fontSize: 13, color: Colors.white),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedSeriesId = val;
                              if (val != null) {
                                final s = _seriesList.firstWhere(
                                  (item) => item.id == val,
                                  orElse: () => TitoSeriesItem(id: '', titulo: ''),
                                );
                                if (s.titulo.isNotEmpty && _folderController.text.trim().isEmpty) {
                                  _folderController.text = s.titulo;
                                }
                              }
                            });
                          },
                        )
                      else
                        TextField(
                          controller: _seriesController,
                          style: const TextStyle(fontSize: 13, color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: 'ID o Nombre de Serie',
                            prefixIcon: Icon(Icons.tv, size: 18, color: AppTheme.textMuted),
                          ),
                        ),
                      const SizedBox(height: 12),

                      // Temporada y Capítulo
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Temporada', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _seasonController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, color: Colors.white),
                                  decoration: const InputDecoration(hintText: '1'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Capítulo (Orden)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                                const SizedBox(height: 4),
                                TextField(
                                  controller: _episodeController,
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 13, color: Colors.white),
                                  decoration: const InputDecoration(hintText: '1'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Servidor predeterminado
                      const Text('Servidor Predeterminado para Reproducción', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: _defaultServer,
                        dropdownColor: AppTheme.bgCardLighter,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          fillColor: AppTheme.bgCardLighter,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'earnvids', child: Text('EarnVids (Recomendado)', style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: 'savefiles', child: Text('SaveFiles', style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: 'doodstream', child: Text('DoodStream', style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: 'streamtape', child: Text('Streamtape', style: TextStyle(color: Colors.white, fontSize: 13))),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _defaultServer = v);
                        },
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // BOTÓN PRINCIPAL DE INICIO
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: queue.isWorking ? null : () => _handleStartJob(queue),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 4,
                    shadowColor: AppTheme.primaryOrange.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.rocket_launch_rounded, size: 19),
                        const SizedBox(width: 8),
                        Text(
                          queue.isWorking ? 'TRABAJO EN CURSO...' : 'INICIAR SUBIDA CONCURRENTE',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primaryOrange),
        const SizedBox(width: 6),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildModeOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMode == id;

    return InkWell(
      onTap: () => setState(() => _selectedMode = id),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppTheme.primaryOrange : AppTheme.textMuted,
                size: 20,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderChip(String key, String name, Color color) {
    final isSelected = _selectedProviders.contains(key);

    return Expanded(
      child: InkWell(
        onTap: () => _onProviderToggle(key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.15) : AppTheme.bgCardLighter,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : AppTheme.borderSubtle,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
                size: 16,
                color: isSelected ? color : AppTheme.textMuted,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : Colors.white60,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
