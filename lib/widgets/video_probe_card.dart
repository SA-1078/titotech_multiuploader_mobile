import 'package:flutter/material.dart';
import '../models/video_metadata.dart';
import '../services/storage_checker.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class VideoProbeCard extends StatelessWidget {
  final VideoMetadata metadata;
  final StorageCheckResult? storageCheck;
  final VoidCallback onClear;

  const VideoProbeCard({
    super.key,
    required this.metadata,
    this.storageCheck,
    required this.onClear,
  });

  String _formatDuration(double seconds) {
    if (seconds <= 0) return '00:00';
    final duration = Duration(seconds: seconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final secs = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final recommendation = metadata.recommendedStrategy;
    Color badgeColor = AppTheme.colorSavefiles;
    IconData badgeIcon = Icons.check_circle_outline;

    if (recommendation == 'remux') {
      badgeColor = const Color(0xFF06B6D4); // Cyan
      badgeIcon = Icons.bolt;
    } else if (recommendation == 'video_copy_audio_aac') {
      badgeColor = const Color(0xFF3B82F6); // Blue
      badgeIcon = Icons.audiotrack;
    } else if (recommendation == 'mediacodec_transcode') {
      badgeColor = AppTheme.primaryOrange;
      badgeIcon = Icons.memory;
    }

    return GlassCard(
      borderColor: AppTheme.borderMedium,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con nombre de archivo y botón descartar
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.movie_outlined, color: AppTheme.primaryOrange, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      metadata.filename,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${StorageCheckResult.formatBytes(metadata.filesize)} • ${_formatDuration(metadata.durationSeconds)}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, color: AppTheme.textMuted, size: 20),
                tooltip: 'Cambiar video',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderSubtle, height: 1),
          const SizedBox(height: 12),

          // Codec and Stream Badges
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _buildPill('Video: ${metadata.videoCodec.toUpperCase()}', Icons.videocam_outlined),
              _buildPill('Audio: ${metadata.audioCodec.toUpperCase()}', Icons.volume_up_outlined),
              _buildPill(
                metadata.width > 0 ? '${metadata.width}x${metadata.height}' : 'Resolución N/D',
                Icons.aspect_ratio,
              ),
              _buildPill(metadata.containerFormat.toUpperCase(), Icons.folder_zip_outlined),
            ],
          ),
          const SizedBox(height: 14),

          // Recomendación inteligente
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(badgeIcon, color: badgeColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    metadata.recommendedStrategyLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: badgeColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Storage check banner
          if (storageCheck != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  storageCheck!.hasEnoughSpace ? Icons.storage_rounded : Icons.warning_amber_rounded,
                  size: 15,
                  color: storageCheck!.hasEnoughSpace ? AppTheme.colorSavefiles : AppTheme.colorDood,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    storageCheck!.message,
                    style: TextStyle(
                      fontSize: 11,
                      color: storageCheck!.hasEnoughSpace ? AppTheme.textSecondary : AppTheme.colorDood,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPill(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgCardLighter,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
