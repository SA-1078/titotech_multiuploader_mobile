import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/provider_result.dart';
import '../models/upload_job.dart';
import '../services/queue_service.dart';
import '../services/storage_checker.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showJobDetails(BuildContext context, UploadJob job, QueueService queue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.borderMedium,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    job.filename,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${DateFormat('dd/MM/yyyy HH:mm').format(job.createdAt)} • ${StorageCheckResult.formatBytes(job.filesize)}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.borderSubtle, height: 1),
                  const SizedBox(height: 16),

                  // Enlaces de Servidores
                  const Text(
                    'Enlaces y Reproductores Generados',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(height: 10),

                  ...job.providers.entries.map((entry) {
                    final prov = entry.key;
                    final res = entry.value;
                    final link = res.embedUrl ?? res.fileCode ?? '';
                    final isSuccess = res.status == ProviderStatus.completed && link.isNotEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCardLighter,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderSubtle),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSuccess ? Icons.link_rounded : Icons.link_off_rounded,
                            size: 18,
                            color: isSuccess ? AppTheme.primaryOrange : AppTheme.textMuted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prov.toUpperCase(),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isSuccess ? link : (res.errorMessage ?? 'No disponible'),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSuccess ? AppTheme.textSecondary : Colors.redAccent,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isSuccess) ...[
                            IconButton(
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: link));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Enlace de ${prov.toUpperCase()} copiado'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: AppTheme.bgCardLighter,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16, color: AppTheme.primaryOrange),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Botón Sincronizar en TitoStream
                  if (job.overallStatus == OverallStatus.completed || job.overallStatus == OverallStatus.uploadsCompleted) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 46,
                      child: ElevatedButton.icon(
                        onPressed: () => _openSyncDialog(context, job, queue),
                        icon: const Icon(Icons.sync_alt_rounded, size: 18),
                        label: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            job.syncState == SyncState.completed ? 'Re-Sincronizar en TitoStream' : 'Publicar en TitoStream',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Botón eliminar del historial
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await queue.deleteJob(job.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Registro eliminado del historial'),
                              backgroundColor: AppTheme.bgCardLighter,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      label: const Text('Eliminar del historial', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openSyncDialog(BuildContext context, UploadJob job, QueueService queue) {
    Navigator.pop(context); // cerrar sheet anterior
    final seasonCtrl = TextEditingController(text: job.season > 0 ? job.season.toString() : '1');
    final episodeCtrl = TextEditingController(text: job.episode > 0 ? job.episode.toString() : '1');
    final titleCtrl = TextEditingController(text: job.title.isNotEmpty ? job.title : job.filename);
    String seriesId = job.seriesId;

    showDialog(
      context: context,
      builder: (dlgCtx) {
        return AlertDialog(
          backgroundColor: AppTheme.bgCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Publicar en TitoStream', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Serie ID', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: TextEditingController(text: seriesId),
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                  onChanged: (v) => seriesId = v.trim(),
                  decoration: const InputDecoration(hintText: 'ID de la Serie'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Temporada', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: seasonCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Capítulo', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 4),
                          TextField(
                            controller: episodeCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Título del capítulo', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(fontSize: 13, color: Colors.white),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: const Text('Cancelar', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (seriesId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ingresa el ID de la serie')),
                  );
                  return;
                }
                Navigator.pop(dlgCtx);
                try {
                  await SyncService.syncJobToTitoStream(
                    job: job,
                    seriesId: seriesId,
                    season: int.tryParse(seasonCtrl.text.trim()) ?? 1,
                    episode: int.tryParse(episodeCtrl.text.trim()) ?? 1,
                    title: titleCtrl.text.trim(),
                  );
                  await queue.refreshHistory();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('¡Capítulo publicado con éxito en TitoStream!')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al sincronizar: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryOrange),
              child: const Text('Publicar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<QueueService>();
    final allJobs = queue.historyJobs;

    final jobs = _filter.isEmpty
        ? allJobs
        : allJobs.where((j) => j.filename.toLowerCase().contains(_filter.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Historial de Subidas'),
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => queue.refreshHistory(),
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre de archivo...',
                  prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                  suffixIcon: _filter.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppTheme.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _filter = '');
                          },
                        )
                      : null,
                ),
                onChanged: (val) => setState(() => _filter = val),
              ),
            ),

            Expanded(
              child: jobs.isEmpty
                  ? Center(
                      child: Text(
                        _filter.isEmpty ? 'No hay trabajos en el historial.' : 'No se encontraron resultados.',
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => queue.refreshHistory(),
                      color: AppTheme.primaryOrange,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          return GlassCard(
                            onTap: () => _showJobDetails(context, job, queue),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                _buildStatusIcon(job.overallStatus),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        job.filename,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Text(
                                            DateFormat('dd/MM/yyyy HH:mm').format(job.createdAt),
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            '•  ${StorageCheckResult.formatBytes(job.filesize)}',
                                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildSyncBadge(job.syncState),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(OverallStatus status) {
    Color color = AppTheme.textMuted;
    IconData icon = Icons.circle_outlined;

    switch (status) {
      case OverallStatus.completed:
        color = AppTheme.colorSavefiles;
        icon = Icons.check_circle_rounded;
        break;
      case OverallStatus.uploadsCompleted:
        color = AppTheme.primaryOrange;
        icon = Icons.cloud_done_rounded;
        break;
      case OverallStatus.failed:
        color = Colors.redAccent;
        icon = Icons.error_outline_rounded;
        break;
      case OverallStatus.cancelled:
        color = Colors.orangeAccent;
        icon = Icons.cancel_outlined;
        break;
      default:
        color = AppTheme.primaryOrange;
        icon = Icons.autorenew_rounded;
    }

    return Icon(icon, color: color, size: 22);
  }

  Widget _buildSyncBadge(SyncState state) {
    if (state == SyncState.completed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.colorSavefiles.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text('SYNC', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.colorSavefiles)),
      );
    }
    return const SizedBox.shrink();
  }
}
