import 'package:flutter/material.dart';
import '../providers_api/doodstream_provider.dart';
import '../providers_api/earnvids_provider.dart';
import '../providers_api/savefiles_provider.dart';
import '../providers_api/streamtape_provider.dart';
import '../services/secure_storage_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _doodController = TextEditingController();
  final _tapeUserController = TextEditingController();
  final _tapeKeyController = TextEditingController();
  final _savefilesController = TextEditingController();
  final _earnvidsController = TextEditingController();
  final _titoUrlController = TextEditingController();
  final _titoTokenController = TextEditingController();

  int _concurrency = 4;
  String _defaultMode = 'auto';
  bool _isLoading = true;
  final Map<String, String?> _testResults = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final creds = await SecureStorageService.instance.getAllCredentials();
    final concurrency = await SecureStorageService.instance.getUploadConcurrency();

    if (mounted) {
      setState(() {
        _doodController.text = creds['doodstream_api_key'] ?? '';
        _tapeUserController.text = creds['streamtape_user'] ?? '';
        _tapeKeyController.text = creds['streamtape_api_key'] ?? '';
        _savefilesController.text = creds['savefiles_api_key'] ?? '';
        _earnvidsController.text = creds['earnvids_api_key'] ?? '';
        _titoUrlController.text = creds['titostream_api_url'] ?? SecureStorageService.defaultTitoApiUrl;
        _titoTokenController.text = creds['titostream_admin_token'] ?? '';
        _concurrency = concurrency;
        _defaultMode = creds['default_processing_mode'] ?? 'auto';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _doodController.dispose();
    _tapeUserController.dispose();
    _tapeKeyController.dispose();
    _savefilesController.dispose();
    _earnvidsController.dispose();
    _titoUrlController.dispose();
    _titoTokenController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    await SecureStorageService.instance.saveCredentials(
      doodstreamKey: _doodController.text.trim(),
      streamtapeUser: _tapeUserController.text.trim(),
      streamtapeKey: _tapeKeyController.text.trim(),
      savefilesKey: _savefilesController.text.trim(),
      earnvidsKey: _earnvidsController.text.trim(),
      titoUrl: _titoUrlController.text.trim(),
      titoToken: _titoTokenController.text.trim(),
      concurrency: _concurrency.toString(),
      defaultMode: _defaultMode,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada de forma segura'),
          backgroundColor: AppTheme.colorSavefiles,
        ),
      );
    }
  }

  Future<void> _testProvider(String key) async {
    setState(() => _testResults[key] = 'Probando...');

    final creds = {
      'doodstream_api_key': _doodController.text.trim(),
      'streamtape_user': _tapeUserController.text.trim(),
      'streamtape_api_key': _tapeKeyController.text.trim(),
      'savefiles_api_key': _savefilesController.text.trim(),
      'earnvids_api_key': _earnvidsController.text.trim(),
    };

    bool ok = false;
    try {
      if (key == 'doodstream') {
        ok = await DoodStreamProvider().testConnection(creds);
      } else if (key == 'streamtape') {
        ok = await StreamtapeProvider().testConnection(creds);
      } else if (key == 'savefiles') {
        ok = await SaveFilesProvider().testConnection(creds);
      } else if (key == 'earnvids') {
        ok = await EarnVidsProvider().testConnection(creds);
      } else if (key == 'titostream') {
        final list = await SyncService.fetchSeries(
          apiUrl: _titoUrlController.text.trim(),
          adminToken: _titoTokenController.text.trim(),
        );
        ok = list.isNotEmpty;
      }
    } catch (_) {
      ok = false;
    }

    if (mounted) {
      setState(() {
        _testResults[key] = ok ? 'Conexión exitosa' : 'Fallo de autenticación';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.bgDark,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange)),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Configuración y Claves API'),
        backgroundColor: AppTheme.bgDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Concurrencia de subidas simultáneas
              _buildSectionTitle('Rendimiento y Red', Icons.speed_rounded),
              const SizedBox(height: 8),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Subidas simultáneas (Concurrencia):',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$_concurrency servidores a la vez',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryOrange),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Slider(
                      value: _concurrency.toDouble(),
                      min: 1,
                      max: 4,
                      divisions: 3,
                      activeColor: AppTheme.primaryOrange,
                      inactiveColor: AppTheme.bgCardLighter,
                      onChanged: (val) {
                        setState(() => _concurrency = val.round());
                      },
                    ),
                    const Text(
                      'Recomendado 4 para WiFi de alta velocidad. Usa 2 si tu conexión móvil es inestable.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Claves de Streaming
              _buildSectionTitle('Claves de Streaming', Icons.key_rounded),
              const SizedBox(height: 8),
              GlassCard(
                child: Column(
                  children: [
                    _buildKeyField(
                      label: 'DoodStream API Key',
                      controller: _doodController,
                      providerKey: 'doodstream',
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 20),
                    _buildKeyField(
                      label: 'Streamtape Login / User',
                      controller: _tapeUserController,
                    ),
                    const SizedBox(height: 8),
                    _buildKeyField(
                      label: 'Streamtape API Key',
                      controller: _tapeKeyController,
                      providerKey: 'streamtape',
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 20),
                    _buildKeyField(
                      label: 'SaveFiles API Key',
                      controller: _savefilesController,
                      providerKey: 'savefiles',
                    ),
                    const Divider(color: AppTheme.borderSubtle, height: 20),
                    _buildKeyField(
                      label: 'EarnVids API Key',
                      controller: _earnvidsController,
                      providerKey: 'earnvids',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Integración TitoStream
              _buildSectionTitle('Backend TitoStream', Icons.dns_rounded),
              const SizedBox(height: 8),
              GlassCard(
                child: Column(
                  children: [
                    _buildKeyField(
                      label: 'URL de TitoTech API',
                      controller: _titoUrlController,
                      hint: 'https://titotech-tutoriales-back.vercel.app',
                    ),
                    const SizedBox(height: 8),
                    _buildKeyField(
                      label: 'Admin Bearer Token (Opcional)',
                      controller: _titoTokenController,
                      providerKey: 'titostream',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón Guardar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _saveSettings,
                  icon: const Icon(Icons.save_rounded, size: 19),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'GUARDAR CONFIGURACIÓN',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
          ),
        ),
      ],
    );
  }

  Widget _buildKeyField({
    required String label,
    required TextEditingController controller,
    String? hint,
    String? providerKey,
  }) {
    final testResult = providerKey != null ? _testResults[providerKey] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (providerKey != null) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _testProvider(providerKey),
                child: Text(
                  testResult ?? 'Probar conexión',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: testResult == 'Conexión exitosa'
                        ? AppTheme.colorSavefiles
                        : (testResult == 'Fallo de autenticación' ? Colors.redAccent : AppTheme.primaryOrange),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          style: const TextStyle(fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint ?? 'Ingresar clave...',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}
