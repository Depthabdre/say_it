import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

// The entry point for the overlay window.
// This is essential for flutter_overlay_window to work.
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text(
            "TapReply",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables securely
  await dotenv.load(fileName: ".env").catchError((_) {
    // Ignore if not found during dev, but good to log in prod
  });

  runApp(const SayItApp());
}

class SayItApp extends StatelessWidget {
  const SayItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapReply',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // A modern Indigo primary color
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const MainConfigurationScreen(),
    );
  }
}

class MainConfigurationScreen extends StatefulWidget {
  const MainConfigurationScreen({super.key});

  @override
  State<MainConfigurationScreen> createState() => _MainConfigurationScreenState();
}

class _MainConfigurationScreenState extends State<MainConfigurationScreen> {
  bool _hasOverlayPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasPermission = await FlutterOverlayWindow.isPermissionGranted();
    setState(() {
      _hasOverlayPermission = hasPermission;
    });
  }

  Future<void> _requestOverlayPermission() async {
    final granted = await FlutterOverlayWindow.requestPermission();
    setState(() {
      _hasOverlayPermission = granted ?? false;
    });
  }

  Future<void> _showOverlay() async {
    if (await FlutterOverlayWindow.isActive()) {
      return;
    }
    await FlutterOverlayWindow.showOverlay(
      enableDrag: true,
      overlayTitle: "TapReply Bubble",
      overlayContent: "TapReply is active",
      flag: OverlayFlag.defaultFlag,
      visibility: NotificationVisibility.visibilityPublic,
      positionGravity: PositionGravity.auto,
      height: 200,
      width: WindowSize.matchParent,
    );
  }
  
  Future<void> _closeOverlay() async {
    await FlutterOverlayWindow.closeOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("TapReply Configuration"),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _hasOverlayPermission ? Icons.check_circle : Icons.warning_amber_rounded,
                color: _hasOverlayPermission ? Colors.green : Colors.orange,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _hasOverlayPermission 
                  ? "Overlay Permission Granted" 
                  : "Overlay Permission Required",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                "TapReply needs to draw a bubble over other apps so you can access it anywhere.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              if (!_hasOverlayPermission)
                ElevatedButton.icon(
                  onPressed: _requestOverlayPermission,
                  icon: const Icon(Icons.settings),
                  label: const Text("Grant Permission"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                )
              else ...[
                ElevatedButton.icon(
                  onPressed: _showOverlay,
                  icon: const Icon(Icons.bubble_chart),
                  label: const Text("Show Bubble"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _closeOverlay,
                  icon: const Icon(Icons.close),
                  label: const Text("Close Bubble"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
