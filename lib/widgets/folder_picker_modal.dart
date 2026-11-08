import 'package:flutter/material.dart';
import '../services/folder_service.dart';
import '../theme/app_theme.dart';

class FolderPickerModal extends StatefulWidget {
  final String initialFolder;
  final Function(String selectedFolder) onFolderSelected;

  const FolderPickerModal({
    super.key,
    required this.initialFolder,
    required this.onFolderSelected,
  });

  static Future<void> show(
    BuildContext context, {
    required String initialFolder,
    required Function(String selectedFolder) onFolderSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => FolderPickerModal(
        initialFolder: initialFolder,
        onFolderSelected: onFolderSelected,
      ),
    );
  }

  @override
  State<FolderPickerModal> createState() => _FolderPickerModalState();
}

class _FolderPickerModalState extends State<FolderPickerModal> {
  final _searchController = TextEditingController();
  RemoteFolderCatalog? _catalog;
  bool _isLoading = true;
  String _filter = '';
  String _activeTab = 'all'; // 'all', 'in_all', 'doodstream', 'streamtape', 'savefiles', 'earnvids'

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialFolder;
    _filter = widget.initialFolder;
    if (FolderService.cachedCatalog != null) {
      _catalog = FolderService.cachedCatalog;
      _isLoading = false;
    }
    _loadCatalog(false);
  }

  Future<void> _loadCatalog(bool force) async {
    if (_catalog == null || force) {
      setState(() => _isLoading = true);
    }
    final cat = await FolderService.getCatalog(forceRefresh: force);
    if (mounted) {
      setState(() {
        _catalog = cat;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getPlatformColor(String prov) {
    switch (prov) {
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

  String _getPlatformLabel(String prov) {
    switch (prov) {
      case 'doodstream':
        return 'DoodStream';
      case 'streamtape':
        return 'Streamtape';
      case 'savefiles':
        return 'SaveFiles';
      case 'earnvids':
        return 'EarnVids';
      default:
        return prov;
    }
  }

  @override
  Widget build(BuildContext context) {
    final allFolders = _catalog?.folders ?? [];

    // Conteo por pestaña
    final countAll = allFolders.length;
    final countInAll = allFolders.where((f) => f.inAll).length;
    final countDood = allFolders.where((f) => f.platforms.contains('doodstream')).length;
    final countTape = allFolders.where((f) => f.platforms.contains('streamtape')).length;
    final countSave = allFolders.where((f) => f.platforms.contains('savefiles')).length;
    final countEarn = allFolders.where((f) => f.platforms.contains('earnvids')).length;

    // Filtrar por pestaña y texto
    final q = _filter.trim().toLowerCase();
    final filtered = allFolders.where((f) {
      if (_activeTab == 'in_all' && !f.inAll) return false;
      if (['doodstream', 'streamtape', 'savefiles', 'earnvids'].contains(_activeTab)) {
        if (!f.platforms.contains(_activeTab)) return false;
      }
      if (q.isEmpty) return true;
      final matchName = f.name.toLowerCase().contains(q);
      final matchVariants = f.variants.any((v) => v.toLowerCase().contains(q));
      return matchName || matchVariants;
    }).toList();

    final isExactMatch = allFolders.any(
      (f) => f.name.toLowerCase() == q || f.variants.any((v) => v.toLowerCase() == q),
    );
    final hasNewQuery = q.isNotEmpty && !isExactMatch;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderMedium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header responsive
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_special_rounded, color: AppTheme.primaryOrange, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Elegir Carpeta Remota',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'EarnVids • SaveFiles • Streamtape • DoodStream',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _loadCatalog(true),
                  icon: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 19),
                  tooltip: 'Actualizar servidores',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Buscador
            TextField(
              controller: _searchController,
              autofocus: false,
              style: const TextStyle(fontSize: 13, color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar carpeta o escribir nueva...',
                prefixIcon: const Icon(Icons.search, size: 17, color: AppTheme.textMuted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                suffixIcon: _filter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 15, color: AppTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _filter = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),

            // Pestañas de clasificación horizontal
            SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildTabChip('all', 'Todas ($countAll)', AppTheme.primaryOrange),
                  const SizedBox(width: 6),
                  _buildTabChip('in_all', '✨ En las 4 ($countInAll)', AppTheme.colorSavefiles),
                  const SizedBox(width: 6),
                  _buildTabChip('doodstream', 'DoodStream ($countDood)', AppTheme.colorDood),
                  const SizedBox(width: 6),
                  _buildTabChip('streamtape', 'Streamtape ($countTape)', AppTheme.colorTape),
                  const SizedBox(width: 6),
                  _buildTabChip('savefiles', 'SaveFiles ($countSave)', AppTheme.colorSavefiles),
                  const SizedBox(width: 6),
                  _buildTabChip('earnvids', 'EarnVids ($countEarn)', AppTheme.colorEarnvids),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Opción Crear Nueva Carpeta
            if (hasNewQuery) ...[
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  widget.onFolderSelected(_filter.trim());
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.primaryOrange.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.create_new_folder_rounded, color: AppTheme.primaryOrange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Crear y usar: "${_filter.trim()}" en las 4 plataformas',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primaryOrange,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.primaryOrange, size: 12),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Lista de carpetas clasificadas
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryOrange))
                  : filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.cloud_off_rounded, size: 36, color: AppTheme.textMuted),
                                const SizedBox(height: 8),
                                Text(
                                  _filter.trim().isEmpty
                                      ? 'No hay carpetas en este filtro.'
                                      : 'No se encontró "$_filter".',
                                  style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                                  textAlign: TextAlign.center,
                                ),
                                if (hasNewQuery) ...[
                                  const SizedBox(height: 10),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      widget.onFolderSelected(_filter.trim());
                                      Navigator.pop(context);
                                    },
                                    icon: const Icon(Icons.add, size: 16),
                                    label: Text('Usar "${_filter.trim()}"'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primaryOrange,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final folder = filtered[index];
                            final isSelected = folder.name.toLowerCase() == widget.initialFolder.toLowerCase().trim();

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.primaryOrange.withValues(alpha: 0.14)
                                    : AppTheme.bgCardLighter,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryOrange
                                      : (folder.inAll
                                          ? AppTheme.colorSavefiles.withValues(alpha: 0.3)
                                          : AppTheme.borderSubtle),
                                  width: isSelected ? 1.5 : 1.0,
                                ),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  widget.onFolderSelected(folder.name);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Fila superior: Nombre + Badge En las 4 o Contador
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.folder_rounded,
                                            color: isSelected ? AppTheme.primaryOrange : AppTheme.primaryOrange.withValues(alpha: 0.8),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              folder.name,
                                              style: TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w700,
                                                color: isSelected ? AppTheme.primaryOrange : Colors.white,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          if (folder.inAll)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppTheme.colorSavefiles.withValues(alpha: 0.18),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: AppTheme.colorSavefiles.withValues(alpha: 0.4)),
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.check_circle, size: 10, color: AppTheme.colorSavefiles),
                                                  SizedBox(width: 3),
                                                  Text(
                                                    'En las 4',
                                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.colorSavefiles),
                                                  ),
                                                ],
                                              ),
                                            )
                                          else
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.06),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${folder.platformCount}/4 serv.',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                                              ),
                                            ),
                                        ],
                                      ),

                                      // Fila central: Badges de plataformas presentes
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 4,
                                        runSpacing: 4,
                                        children: ['doodstream', 'streamtape', 'savefiles', 'earnvids'].map((prov) {
                                          final hasProv = folder.platforms.contains(prov);
                                          final col = _getPlatformColor(prov);
                                          final label = _getPlatformLabel(prov);

                                          return Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: hasProv ? col.withValues(alpha: 0.16) : Colors.white.withValues(alpha: 0.03),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: hasProv ? col.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.06),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: hasProv ? col : Colors.white24,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  label,
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: hasProv ? col : Colors.white30,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),

                                      // Fila inferior: Variaciones unificadas (si las hay)
                                      if (folder.variants.isNotEmpty) ...[
                                        const SizedBox(height: 5),
                                        Text(
                                          'Unifica: ${folder.variants.map((v) => '"$v"').join(', ')}',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppTheme.textMuted,
                                            fontStyle: FontStyle.italic,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String id, String label, Color activeColor) {
    final isTabActive = _activeTab == id;

    return InkWell(
      onTap: () => setState(() => _activeTab = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isTabActive ? activeColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isTabActive ? activeColor : AppTheme.borderSubtle,
            width: isTabActive ? 1.2 : 1.0,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isTabActive ? FontWeight.w800 : FontWeight.w500,
            color: isTabActive ? activeColor : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}
