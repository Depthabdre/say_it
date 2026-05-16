import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/features/ai_engine/application/gemini_service.dart';
import 'package:say_it/core/native_bridge/accessibility_service.dart';

class BubbleOverlay extends StatefulWidget {
  const BubbleOverlay({super.key});

  @override
  State<BubbleOverlay> createState() => _BubbleOverlayState();
}

class _BubbleOverlayState extends State<BubbleOverlay>
    with SingleTickerProviderStateMixin {
  bool isExpanded = false;
  bool isGenerating = false;
  String? errorMessage;
  List<String> generatedReplies = [];

  ReplyTone selectedTone = ReplyTone.normal;
  final TextEditingController _instructionController = TextEditingController();

  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _isAmharic = true; // Tracks the selected language

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();

    // Listen to messages from the Main App (AI replies, errors)
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (!mounted) return;
      if (event is Map) {
        if (event['action'] == 'REPLIES_READY') {
          setState(() {
            isGenerating = false;
            errorMessage = null;
            generatedReplies = List<String>.from(event['replies']);
          });
          // Resize larger to fit cards
          if (isExpanded) {
            FlutterOverlayWindow.resizeOverlay(
              WindowSize.matchParent,
              600,
              true,
            );
          }
        } else if (event['error'] != null) {
          setState(() {
            isGenerating = false;
            errorMessage = event['error'];
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  void _toggleExpand() async {
    setState(() {
      isExpanded = !isExpanded;
      if (!isExpanded) {
        // Reset state when closing
        generatedReplies.clear();
        errorMessage = null;
        isGenerating = false;
        
        if (_isListening) {
          _speech.stop();
          _isListening = false;
        }
      }
    });

    if (isExpanded) {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
      await FlutterOverlayWindow.resizeOverlay(
        WindowSize.matchParent,
        450,
        true,
      );
    } else {
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
      await FlutterOverlayWindow.resizeOverlay(150, 150, true);
    }
  }

  void _listen() async {
    if (!_isListening) {
      bool available = await _speech.initialize(
        onStatus: (val) {
          debugPrint('onStatus: $val');
          if (val == 'done' || val == 'notListening') {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          debugPrint('onError: $val');
          setState(() => _isListening = false);
        },
      );
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          localeId: _isAmharic ? 'am-ET' : 'en-US', // Dynamic language selection
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          onResult: (val) {
            setState(() {
              if (val.recognizedWords.isNotEmpty) {
                _instructionController.text = val.recognizedWords;
                // Move cursor to the end to ensure UI updates properly
                _instructionController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _instructionController.text.length),
                );
              }
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  void _handleGenerate() async {
    setState(() {
      isGenerating = true;
      errorMessage = null;
      generatedReplies.clear();
    });

    try {
      String screenText = "";
      final customText = _instructionController.text.trim();

      // Only check screen text if the user didn't explicitly type a custom prompt
      if (customText.isEmpty) {
        // 1. Get Screen Text Locally via Bridge!
        final extractedText =
            await AccessibilityServiceBridge.extractScreenText();
        if (extractedText == null ||
            extractedText.trim().isEmpty ||
            extractedText == "NO_ROOT_NODE") {
          setState(() {
            errorMessage =
                "Could not read screen. Please open a chat app first or provide text manually.";
            isGenerating = false;
          });
          return;
        }
        screenText = extractedText;
        debugPrint('Captured Screen Context: \\n"""\\n$screenText\\n"""');
      } else {
        screenText = "User provided contextual input: $customText";
      }

      // 2. Call Gemini
      final geminiService = GeminiService();
      final request = GenerationRequest(
        screenContextText: screenText,
        tone: selectedTone,
        customInstructions: customText.isEmpty ? null : customText,
      );

      final replies = await geminiService.generateReplies(request);

      if (mounted) {
        setState(() {
          generatedReplies = replies;
          isGenerating = false;
        });
        if (isExpanded) {
          FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 600, true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isGenerating = false;
        });
      }
    }
  }

  void _handleInsert(String text) async {
    // 1. Close bubble to drop focusPointer flag
    _toggleExpand();

    // 2. Wait a moment for Android to refocus the underlying app
    await Future.delayed(const Duration(milliseconds: 300));

    // 3. Inject text into the newly active window
    await AccessibilityServiceBridge.injectText(text);
  }

  @override
  Widget build(BuildContext context) {
    // The overlay itself takes the full width when expanded, but just 150x150 when collapsed.
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: Align(
        alignment: isExpanded ? Alignment.bottomCenter : Alignment.center,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return ScaleTransition(scale: animation, child: child);
          },
          child: isExpanded
              ? _buildExpandedDashboard()
              : _buildCollapsedBubble(),
        ),
      ),
    );
  }

  Widget _buildCollapsedBubble() {
    return GestureDetector(
      key: const ValueKey('collapsed'),
      onTap: _toggleExpand,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0x666366F1), // 0.4 opacity
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/IconTap.png',
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDashboard() {
    return ClipRRect(
      key: const ValueKey('expanded'),
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xD91E1E2E), // 0.85 opacity
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x1AFFFFFF)), // 0.1 opacity
            boxShadow: [
              BoxShadow(
                color: const Color(0x4D000000), // 0.3 opacity
                blurRadius: 20,
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Color(0xFFA855F7),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "TapReply",
                          style: TextStyle(
                            color: Colors.white.withAlpha(230),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white54,
                            size: 28,
                          ),
                          onPressed: _toggleExpand,
                          tooltip: "Minimize to bubble",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                            size: 24,
                          ),
                          onPressed: () async {
                            // Reset state BEFORE closing so next launch is clean!
                            // Because the flutter engine is cached by the plugin,
                            // state persists on reopen.
                            setState(() {
                              isExpanded = false;
                              isGenerating = false;
                              errorMessage = null;
                              generatedReplies.clear();
                              _instructionController.clear();
                            });
                            await FlutterOverlayWindow.updateFlag(
                              OverlayFlag.defaultFlag,
                            );
                            await FlutterOverlayWindow.closeOverlay();
                          },
                          tooltip: "Close TapReply",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Input Field
                TextField(
                  controller: _instructionController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Optional: Tell them I'm running late...",
                    hintStyle: TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0x4D000000), // 0.3 opacity
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            // If user switches language mid-speech, let them
                            setState(() {
                              _isAmharic = !_isAmharic;
                            });
                            if (_isListening) {
                              _speech.stop();
                              _listen(); // restart in new language
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isAmharic ? Colors.amber.withValues(alpha: 0.2) : Colors.blueAccent.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _isAmharic ? 'AM' : 'EN',
                              style: TextStyle(
                                color: _isAmharic ? Colors.amber : Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? Colors.redAccent : Colors.white54,
                          ),
                          onPressed: _listen,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tone Selectors
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ReplyTone.values.map((tone) {
                      final isSelected = selectedTone == tone;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tone.displayName),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => selectedTone = tone);
                          },
                          selectedColor: const Color(0x336366F1), // 0.2 opacity
                          backgroundColor: Colors.transparent,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF818CF8)
                                : Colors.white60,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : const Color(0x3DFFFFFF), // 0.24 opacity
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 24),

                // Generate Button or Results
                if (isGenerating)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  )
                else if (errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF44336), // red 0.1
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x4DF44336),
                      ), // red 0.3
                    ),
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (generatedReplies.isNotEmpty)
                  Column(
                    children: generatedReplies.map((reply) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x0DFFFFFF), // white 0.05
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0x1AFFFFFF),
                          ), // white 0.1
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                reply,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.send,
                                color: Color(0xFF6366F1),
                              ),
                              onPressed: () => _handleInsert(reply),
                              tooltip: "Magic Send",
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  )
                else
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _handleGenerate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        "Generate Magic Replies",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
