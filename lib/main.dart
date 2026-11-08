import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/upload_monitor_screen.dart';
import 'services/queue_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await QueueService.instance.init();
  runApp(const TitoStreamMobileApp());
}

class TitoStreamMobileApp extends StatelessWidget {
  const TitoStreamMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: QueueService.instance),
      ],
      child: MaterialApp(
        title: 'TitoStream Multiuploader Mobile',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const MainShellScreen(),
      ),
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  void _onTabChange(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final queue = context.watch<QueueService>();
    final isWorking = queue.isWorking;

    final screens = [
      HomeScreen(onTabChange: _onTabChange),
      const UploadMonitorScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabChange,
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppTheme.bgCard,
          selectedItemColor: AppTheme.primaryOrange,
          unselectedItemColor: AppTheme.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.cloud_upload_outlined),
              activeIcon: Icon(Icons.cloud_upload),
              label: 'Inicio',
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: isWorking,
                backgroundColor: AppTheme.primaryOrange,
                smallSize: 8,
                child: const Icon(Icons.monitor_heart_outlined),
              ),
              activeIcon: Badge(
                isLabelVisible: isWorking,
                backgroundColor: AppTheme.primaryOrange,
                smallSize: 8,
                child: const Icon(Icons.monitor_heart),
              ),
              label: 'Monitor',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              activeIcon: Icon(Icons.history_toggle_off_rounded),
              label: 'Historial',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Ajustes',
            ),
          ],
        ),
      ),
    );
  }
}
