import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/provider_result.dart';
import '../theme/app_theme.dart';
import 'glass_card.dart';

class ProviderProgressCard extends StatelessWidget {
  final String providerKey;
  final ProviderResult? result;

  const ProviderProgressCard({
    super.key,
    required this.providerKey,
    this.result,
  });

  Color _getProviderColor(String key) {
    switch (key.toLowerCase()) {
      case 'doodstream':
        return AppTheme.colorDood;
      case 'streamtape':
        return AppTheme.colorTape;
      case 'savefiles':
        return AppTheme.colorSavefiles;
      case 'earnvids':
        return AppTheme.colorEarnvids;
      default:
        return AppTheme.primaryOrange;
    }
  }

  String _getProviderTitle(String key) {
    switch (key.toLowerCase()) {
      case 'doodstream':
        return 'DoodStream';
      case 'streamtape':
        return 'Streamtape';
      case 'savefiles':
        return 'SaveFiles';
      case 'earnvids':
        return 'EarnVids';
      default:
        return key;
    }
  }

  String _formatSpeed(int bps) {
    if (bps <= 0) return '0 KB/s';
    final kb = bps / 1024;
    if (kb >= 1024) {
      return '${(kb / 1024).toStringAsFixed(1)} MB/s';
    }
    return '${kb.toStringAsFixed(0)} KB/s';
  }

  @override
  Widget build(BuildContext context) {
    final color = _getProviderColor(providerKey);
    final title = _getProviderTitle(providerKey);
    final status = result?.status ?? ProviderStatus.idle;
    final progress = (result?.progress ?? 0.0).clamp(0.0, 1.0);
    final speed = result?.speedBps ?? 0;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Nombre del servidor + Status Badge
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              _buildStatusBadge(status),
            ],
          ),
          const SizedBox(height: 10),

          // Barra de progreso interactiva
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: status == ProviderStatus.completed ? 1.0 : (status == ProviderStatus.uploading ? progress : 0.0),
              backgroundColor: AppTheme.bgCardLighter,
              valueColor: AlwaysStoppedAnimation<Color>(
                status == ProviderStatus.failed ? Colors.redAccent : color,
              ),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),

          // Información de velocidad y porcentaje
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                status == ProviderStatus.uploading ? _formatSpeed(speed) : (status == ProviderStatus.completed ? 'Completado' : (status == ProviderStatus.failed ? 'Error' : 'En espera')),
                style: TextStyle(
                  fontSize: 12,
                  color: status == ProviderStatus.failed ? Colors.redAccent : AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          // Enlace o FileCode generado
          if (status == ProviderStatus.completed && (result?.embedUrl != null || result?.fileCode != null)) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.bgCardLighter,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      result?.embedUrl ?? result?.fileCode ?? '',
                      style: const TextStyle(fontSize: 11, color: Colors.white70),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      final text = result?.embedUrl ?? result?.fileCode ?? '';
                      Clipboard.setData(ClipboardData(text: text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Enlace copiado de $title'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: AppTheme.bgCardLighter,
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.copy, size: 14, color: AppTheme.primaryOrange),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error message
          if (status == ProviderStatus.failed && result?.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              result!.errorMessage!,
              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ProviderStatus status) {
    Color bg = AppTheme.bgCardLighter;
    Color text = AppTheme.textMuted;
    String label = 'En espera';

    switch (status) {
      case ProviderStatus.idle:
        label = 'En espera';
        break;
      case ProviderStatus.uploading:
        bg = AppTheme.primaryOrange.withValues(alpha: 0.15);
        text = AppTheme.primaryOrange;
        label = 'Subiendo...';
        break;
      case ProviderStatus.completed:
        bg = AppTheme.colorSavefiles.withValues(alpha: 0.15);
        text = AppTheme.colorSavefiles;
        label = 'Listo';
        break;
      case ProviderStatus.failed:
        bg = Colors.redAccent.withValues(alpha: 0.15);
        text = Colors.redAccent;
        label = 'Fallo';
        break;
      case ProviderStatus.cancelled:
        label = 'Cancelado';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: text),
      ),
    );
  }
}
