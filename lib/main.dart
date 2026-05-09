import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:say_it/core/native_bridge/accessibility_service.dart';
import 'package:say_it/features/overlay_dashboard/presentation/bubble_overlay.dart';
import 'package:say_it/features/ai_engine/application/gemini_service.dart';
import 'package:say_it/features/ai_engine/domain/models.dart';

// The entry point for the overlay window.
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: BubbleOverlay(),
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables securely
  await dotenv.load(fileName: ".env").catchError((_) {});

  // Setup the background listener to act as the Bridge between Overlay UI, AI, and Native Android
  FlutterOverlayWindow.overlayListener.listen((event) async {
    if (event is Map) {
      if (event['action'] == 'GENERATE') {
        try {
          // 1. Read the screen context natively
          final screenText = await AccessibilityServiceBridge.extractScreenText();
          if (screenText == null || screenText.isEmpty) {
            FlutterOverlayWindow.shareData({'error': 'Could not read screen content. Is Accessibility enabled?'});
            return;
          }

          // 2. Map the requested tone
          final toneName = event['tone'] as String;
          final tone = ReplyTone.values.firstWhere((e) => e.name == toneName, orElse: () => ReplyTone.normal);

          // 3. Call Gemini
          final geminiService = GeminiService();
          final request = GenerationRequest(
            screenContextText: screenText,
            tone: tone,
            customInstructions: event['instructions'],
          );

          final replies = await geminiService.generateReplies(request);

          // 4. Send replies back to Overlay
          FlutterOverlayWindow.shareData({'action': 'REPLIES_READY', 'replies': replies});
        } catch (e) {
          FlutterOverlayWindow.shareData({'error': e.toString()});
        }
      } else if (event['action'] == 'INSERT_TEXT') {
        // 5. Inject chosen reply into active field
        final textToInject = event['text'] as String;
        await AccessibilityServiceBridge.injectText(textToInject);
        // Automatically close bubble after magic send
        await FlutterOverlayWindow.closeOverlay();
      }
    }
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
  bool _hasAccessibilityPermission = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final hasOverlay = await FlutterOverlayWindow.isPermissionGranted();
    final hasAccessibility = await AccessibilityServiceBridge.isAccessibilityEnabled();
    setState(() {
      _hasOverlayPermission = hasOverlay;
      _hasAccessibilityPermission = hasAccessibility;
    });
  }

  Future<void> _requestOverlayPermission() async {
    final granted = await FlutterOverlayWindow.requestPermission();
    setState(() {
      _hasOverlayPermission = granted ?? false;
    });
  }
  
  Future<void> _requestAccessibilityPermission() async {
    await AccessibilityServiceBridge.openAccessibilitySettings();
    // User has to manually navigate back, so we re-check when app resumes.
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkPermissions,
            tooltip: "Refresh Permissions",
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Overlay Status
              ListTile(
                leading: Icon(
                  _hasOverlayPermission ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: _hasOverlayPermission ? Colors.green : Colors.orange,
                  size: 32,
                ),
                title: Text("Overlay Permission"),
                subtitle: Text("Allows the bubble to float."),
                trailing: !_hasOverlayPermission 
                  ? TextButton(onPressed: _requestOverlayPermission, child: Text("GRANT"))
                  : null,
              ),
              const Divider(),
              // Accessibility Status
              ListTile(
                leading: Icon(
                  _hasAccessibilityPermission ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: _hasAccessibilityPermission ? Colors.green : Colors.orange,
                  size: 32,
                ),
                title: Text("Accessibility Service"),
                subtitle: Text("Allows reading screen & injecting replies."),
                trailing: !_hasAccessibilityPermission 
                  ? TextButton(onPressed: _requestAccessibilityPermission, child: Text("GRANT"))
                  : null,
              ),
              
              const SizedBox(height: 32),
              
              if (_hasOverlayPermission && _hasAccessibilityPermission) ...[
                ElevatedButton.icon(
                  onPressed: _showOverlay,
                  icon: const Icon(Icons.bubble_chart),
                  label: const Text("Launch TapReply Bubble"),
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
              ] else ...[
                 Text(
                  "Please grant all permissions above to use TapReply.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
