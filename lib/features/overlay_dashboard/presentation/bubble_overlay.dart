import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:say_it/features/ai_engine/domain/models.dart';
import 'package:say_it/core/native_bridge/accessibility_service.dart';
import 'package:say_it/features/overlay_dashboard/presentation/bloc/bubble_overlay_bloc.dart';

class BubbleOverlay extends StatefulWidget {
  const BubbleOverlay({super.key});

  @override
  State<BubbleOverlay> createState() => _BubbleOverlayState();
}

class _BubbleOverlayState extends State<BubbleOverlay>
    with SingleTickerProviderStateMixin {
  final TextEditingController _instructionController = TextEditingController();

  late stt.SpeechToText _speech;

  // --- NEW VARIABLES FOR CONTINUOUS LISTENING ---
  bool _forceStop = false;
  String _previousText = "";
  // ----------------------------------------------

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
          context.read<BubbleOverlayBloc>().add(
            RepliesReceivedEvent(List<String>.from(event['replies'])),
          );
        } else if (event['error'] != null) {
          context.read<BubbleOverlayBloc>().add(
            ErrorReceivedEvent(event['error']),
          );
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

  void _listen() async {
    final bloc = context.read<BubbleOverlayBloc>();
    final state = bloc.state;

    if (!state.isListening) {
      _forceStop = false; // Reset the flag
      _previousText =
          _instructionController.text; // Save what is currently in the box

      bool available = await _speech.initialize(
        onStatus: (val) {
          debugPrint('onStatus: $val');

          // Android timed out or detected silence!
          if (val == 'done' || val == 'notListening') {
            if (!_forceStop) {
              // Save the text and instantly restart the microphone
              _previousText = _instructionController.text;
              _startActiveListening(state.isAmharic);
            } else {
              bloc.add(const ListeningStatusChangedEvent(false));
            }
          }
        },
        onError: (val) {
          debugPrint('onError: $val');
          // Restart on timeout error too, unless user pressed Stop
          if (!_forceStop) {
            _previousText = _instructionController.text;
            _startActiveListening(state.isAmharic);
          } else {
            bloc.add(const ListeningStatusChangedEvent(false));
          }
        },
      );

      if (available) {
        bloc.add(const ListeningStatusChangedEvent(true));
        _startActiveListening(state.isAmharic);
      }
    } else {
      // User manually pressed the Stop (Mic) button
      _forceStop = true;
      bloc.add(const ListeningStatusChangedEvent(false));
      _speech.stop();
    }
  }

  void _startActiveListening(bool isAmharic) {
    _speech.listen(
      localeId: isAmharic ? 'am-ET' : 'en-US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      onResult: (val) {
        if (!mounted) return;
        if (val.recognizedWords.isNotEmpty) {
          _instructionController.text = "$_previousText ${val.recognizedWords}"
              .trim();

          _instructionController.selection = TextSelection.fromPosition(
            TextPosition(offset: _instructionController.text.length),
          );
        }
      },
    );
  }

  void _handleGenerate() {
    final bloc = context.read<BubbleOverlayBloc>();

    if (bloc.state.isListening) {
      _forceStop = true;
      _speech.stop();
      bloc.add(const ListeningStatusChangedEvent(false));
    }

    bloc.add(
      GenerateRepliesEvent(customText: _instructionController.text.trim()),
    );
  }

  void _handleInsert(String text) async {
    final bloc = context.read<BubbleOverlayBloc>();
    if (bloc.state.isExpanded) {
      bloc.add(ToggleExpandEvent());
    }

    // Wait a moment for Android to refocus the underlying app
    await Future.delayed(const Duration(milliseconds: 300));
    await AccessibilityServiceBridge.injectText(text);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BubbleOverlayBloc, BubbleOverlayState>(
      builder: (context, state) {
        return Material(
          color: Colors.transparent,
          elevation: 0,
          child: Align(
            alignment: state.isExpanded
                ? Alignment.bottomCenter
                : Alignment.center,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: state.isExpanded
                  ? _buildExpandedDashboard(state)
                  : _buildCollapsedBubble(state),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedBubble(BubbleOverlayState state) {
    return GestureDetector(
      key: const ValueKey('collapsed'),
      onTap: () {
        context.read<BubbleOverlayBloc>().add(ToggleExpandEvent());
      },
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
            boxShadow: const [
              BoxShadow(
                color: Color(0x666366F1),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Image.asset(
            'assets/IconTap2.png',
            width: 40,
            height: 40,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.auto_awesome, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDashboard(BubbleOverlayState state) {
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
            color: const Color(0xD91E1E2E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0x1AFFFFFF)),
            boxShadow: const [
              BoxShadow(color: Color(0x4D000000), blurRadius: 20),
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
                          onPressed: () {
                            if (state.isListening) {
                              _forceStop = true;
                              _speech.stop();
                            }
                            context.read<BubbleOverlayBloc>().add(
                              ToggleExpandEvent(),
                            );
                          },
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
                            if (state.isListening) {
                              _forceStop = true;
                              _speech.stop();
                            }
                            _instructionController.clear();
                            context.read<BubbleOverlayBloc>().add(
                              ResetBubbleEvent(),
                            );
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
                    hintStyle: const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: const Color(0x4D000000),
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
                            context.read<BubbleOverlayBloc>().add(
                              ToggleLanguageEvent(),
                            );
                            if (state.isListening) {
                              _forceStop = true;
                              _speech.stop();

                              Future.delayed(
                                const Duration(milliseconds: 150),
                                () {
                                  _listen();
                                },
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: state.isAmharic
                                  ? Colors.amber.withAlpha(51)
                                  : Colors.blueAccent.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              state.isAmharic ? 'AM' : 'EN',
                              style: TextStyle(
                                color: state.isAmharic
                                    ? Colors.amber
                                    : Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            state.isListening ? Icons.mic : Icons.mic_none,
                            color: state.isListening
                                ? Colors.redAccent
                                : Colors.white54,
                          ),
                          onPressed: _listen,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Tone Selectors
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: ReplyTone.values.map((tone) {
                    final isSelected = state.selectedTone == tone;
                    return ChoiceChip(
                      label: Text(tone.displayName),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          context.read<BubbleOverlayBloc>().add(
                            ChangeToneEvent(tone),
                          );
                        }
                      },
                      showCheckmark: false,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: const Color(0xFF1E2028),
                      labelStyle: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: BorderSide(
                          width: 1.5,
                          color: isSelected
                              ? const Color(0xFF818CF8)
                              : const Color(0xFF2D3139),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                // Generate Button or Results
                if (state.isGenerating)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  )
                else if ((state.errorMessage?.isNotEmpty ?? false))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF44336),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x4DF44336)),
                    ),
                    child: Text(
                      state.errorMessage ?? "",
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  )
                else if (state.generatedReplies.isNotEmpty)
                  Column(
                    children: state.generatedReplies.map((reply) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0x0DFFFFFF),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x1AFFFFFF)),
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
