import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/upload_job.dart';
import '../services/queue_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/provider_progress_card.dart';

class UploadMonitorScreen extends StatelessWidget {
  const UploadMonitorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<QueueService>();
    final activeJob = queue.activeJob;
    final isWorking = queue.isWorking;
    final progress = queue.overallProgress;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Monitor de Subida'),
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: activeJob == null
            ? _buildEmptyState(context)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estado global y barra de progreso
                    GlassCard(
                      borderColor: isWorking ? AppTheme.primaryOrange.withValues(alpha: 0.5) : AppTheme.borderSubtle,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: (isWorking ? AppTheme.primaryOrange : AppTheme.colorSavefiles)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isWorking ? Icons.autorenew_rounded : Icons.check_circle_rounded,
                                  color: isWorking ? AppTheme.primaryOrange : AppTheme.colorSavefiles,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      activeJob.filename,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      queue.statusMessage.isNotEmpty
                                          ? queue.statusMessage
                                          : (isWorking ? 'Procesando...' : 'Completado'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isWorking ? AppTheme.primaryOrange : AppTheme.colorSavefiles,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${(progress * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Barra de progreso global
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: AppTheme.bgCardLighter,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isWorking ? AppTheme.primaryOrange : AppTheme.colorSavefiles,
                              ),
                              minHeight: 8,
                            ),
                          ),

                          // Telemetría de conversión si está procesando video
                          if (queue.currentFps > 0 || queue.currentSpeed > 0) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppTheme.bgCardLighter,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.speed, size: 14, color: AppTheme.primaryOrange),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${queue.currentFps.toStringAsFixed(0)} FPS',
                                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.flash_on, size: 14, color: AppTheme.primaryOrange),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${queue.currentSpeed.toStringAsFixed(1)}x velocidad',
                                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Servidores en progreso / completados
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Progreso por Servidor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${activeJob.providers.length} servidores configurados',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Lista de servidores
                    ...activeJob.providers.entries.map((entry) {
                      return ProviderProgressCard(
                        providerKey: entry.key,
                        result: entry.value,
                      );
                    }),
                    const SizedBox(height: 14),

                    // Estado de sincronización en TitoStream
                    if (activeJob.seriesId.isNotEmpty || activeJob.syncState != SyncState.pending) ...[
                      GlassCard(
                        child: Row(
                          children: [
                            Icon(
                              activeJob.syncState == SyncState.completed
                                  ? Icons.cloud_done_rounded
                                  : (activeJob.syncState == SyncState.syncing ? Icons.sync : Icons.cloud_off_rounded),
                              color: activeJob.syncState == SyncState.completed
                                  ? AppTheme.colorSavefiles
                                  : AppTheme.primaryOrange,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Sincronización con TitoStream',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                                  ),
                                  Text(
                                    activeJob.syncState == SyncState.completed
                                        ? 'Capítulo publicado correctamente.'
                                        : (activeJob.syncState == SyncState.syncing
                                            ? 'Registrando en backend...'
                                            : 'Pendiente de sincronizar'),
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Botón de cancelación
                    if (isWorking) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: () => queue.cancelCurrentJob(),
                          icon: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent, size: 20),
                          label: const Text('CANCELAR SUBIDA ACTUAL', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.bgCardLighter,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.cloud_queue_rounded, size: 48, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay subidas activas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Selecciona un video en la pestaña Inicio para comenzar.',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}
