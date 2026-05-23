import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  final ScrollController _repliesScrollController = ScrollController();
  late final AudioRecorder _audioRecorder;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    );
    _animationController.forward();

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
    _audioRecorder.dispose();
    _repliesScrollController.dispose();
    _animationController.dispose();
    _instructionController.dispose();
    super.dispose();
  }

  /// Programmatically animates the scroll position of the replies list
  void _scrollReplies(double offset) {
    if (_repliesScrollController.hasClients) {
      final double targetPosition = _repliesScrollController.offset + offset;
      _repliesScrollController.animateTo(
        targetPosition.clamp(0.0, _repliesScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _handleMicAction() async {
    final bloc = context.read<BubbleOverlayBloc>();
    final state = bloc.state;

    if (!state.isListening) {
      try {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_input_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        bloc.add(const ListeningStatusChangedEvent(true));
        _instructionController.text = "[Recording audio in ${state.isAmharic ? 'Amharic' : 'English'}...]";

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc), 
          path: path,
        );
      } catch (e) {
        bloc.add(const ListeningStatusChangedEvent(false));
        _instructionController.clear();
        bloc.add(ErrorReceivedEvent(
          "Could not start voice recording. Please verify that Microphone permission is enabled in your device settings."
        ));
      }
    } else {
      try {
        final path = await _audioRecorder.stop();
        bloc.add(const ListeningStatusChangedEvent(false));
        
        if (path != null && path.isNotEmpty) {
          bloc.add(VoiceAudioRecordedEvent(path));
          _instructionController.text = "[Voice input captured — ${state.isAmharic ? 'Amharic' : 'English'}]";
        } else {
          _instructionController.clear();
          bloc.add(const VoiceAudioRecordedEvent(null));
        }
      } catch (e) {
        bloc.add(const ListeningStatusChangedEvent(false));
        _instructionController.clear();
        bloc.add(ErrorReceivedEvent("Error saving voice recording: $e"));
      }
    }
  }

  void _handleGenerate() {
    final bloc = context.read<BubbleOverlayBloc>();

    if (bloc.state.isListening) {
      _handleMicAction(); 
    }

    final isVoiceInput = bloc.state.recordedAudioPath != null;
    final textToSend = isVoiceInput ? "" : _instructionController.text.trim();

    bloc.add(
      GenerateRepliesEvent(customText: textToSend),
    );
  }

  void _handleInsert(String text) async {
    final bloc = context.read<BubbleOverlayBloc>();
    if (bloc.state.isExpanded) {
      bloc.add(ToggleExpandEvent());
    }

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
        child: SizedBox(
          width: 80, 
          height: 80,
          child: Image.asset(
            'assets/TapReplyOverLayF2.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.auto_awesome, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedDashboard(BubbleOverlayState state) {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth > 350 ? screenWidth * 0.95 : 350.0;
    final bool hasAudioFile = state.recordedAudioPath != null;

    // Define a strictly constrained, predictable height to fit inside standard overlay limits
    final double overlayHeight = state.generatedReplies.isNotEmpty ? 520 : 380;

    return OverflowBox(
      maxHeight: double.infinity,
      maxWidth: double.infinity,
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        key: const ValueKey('expanded'),
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: containerWidth,
            height: overlayHeight,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xF613141F), // Rich dark slate
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0x1AFFFFFF)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. PINNED HEADER ROW
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
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
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
                            size: 24,
                          ),
                          onPressed: () async {
                            if (state.isListening) {
                              await _audioRecorder.stop();
                              context.read<BubbleOverlayBloc>().add(
                                const ListeningStatusChangedEvent(false),
                              );
                            }
                            context.read<BubbleOverlayBloc>().add(
                              ToggleExpandEvent(),
                            );
                          },
                          tooltip: "Minimize",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.redAccent,
                            size: 20,
                          ),
                          onPressed: () async {
                            if (state.isListening) {
                              await _audioRecorder.stop();
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
                          tooltip: "Close",
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. PINNED CONTROLS: INPUT FIELD
                TextField(
                  controller: _instructionController,
                  maxLines: 2,
                  minLines: 1,
                  keyboardType: TextInputType.multiline,
                  readOnly: state.isListening || hasAudioFile,
                  style: TextStyle(
                    color: hasAudioFile ? Colors.amberAccent : Colors.white,
                    fontSize: 13,
                    fontStyle: (state.isListening || hasAudioFile) ? FontStyle.italic : FontStyle.normal,
                  ),
                  decoration: InputDecoration(
                    hintText: "Tell them... (or record audio voice)",
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0x33000000),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    prefixIcon: hasAudioFile
                        ? IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                            onPressed: () {
                              _instructionController.clear();
                              context.read<BubbleOverlayBloc>().add(
                                const VoiceAudioRecordedEvent(null),
                              );
                            },
                            tooltip: "Delete clip",
                          )
                        : null,
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () {
                            context.read<BubbleOverlayBloc>().add(
                              ToggleLanguageEvent(),
                            );
                            if (state.isListening) {
                              _handleMicAction().then((_) => _handleMicAction());
                            } else if (hasAudioFile) {
                              _instructionController.clear();
                              context.read<BubbleOverlayBloc>().add(
                                const VoiceAudioRecordedEvent(null),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: state.isAmharic
                                  ? Colors.amber.withAlpha(51)
                                  : Colors.blueAccent.withAlpha(51),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              state.isAmharic ? 'AM' : 'EN',
                              style: TextStyle(
                                color: state.isAmharic
                                    ? Colors.amber
                                    : Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            state.isListening ? Icons.stop_circle : Icons.mic_none,
                            size: 20,
                            color: state.isListening
                                ? Colors.redAccent
                                : (hasAudioFile ? Colors.amberAccent : Colors.white54),
                          ),
                          onPressed: _handleMicAction,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 3. PINNED CONTROLS: TONE SELECTORS
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: ReplyTone.values.map((tone) {
                      final isSelected = state.selectedTone == tone;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: ChoiceChip(
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
                            horizontal: 10,
                            vertical: 6,
                          ),
                          selectedColor: const Color(0xFF6366F1),
                          backgroundColor: const Color(0xFF161722),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            fontSize: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              width: 1,
                              color: isSelected
                                  ? const Color(0xFF818CF8)
                                  : const Color(0xFF2D3139),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 10),

                // 4. ERROR DISPLAY SECTION
                if (state.errorMessage?.isNotEmpty ?? false)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0x1AF44336),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0x4DF44336)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            state.errorMessage ?? "",
                            style: const TextStyle(color: Colors.redAccent, fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 5. THE DYNAMIC REMAINING AREA (SHOWN ONLY ON GENERATION COMPLETE OR LOADING)
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: state.isGenerating
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF6366F1),
                            ),
                          )
                        : state.generatedReplies.isNotEmpty
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Replies Scrollable Area
                                  Expanded(
                                    child: ListView.builder(
                                      controller: _repliesScrollController,
                                      // Disable active dragging to eliminate conflicts with Android overlay dragging.
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: state.generatedReplies.length,
                                      itemBuilder: (context, index) {
                                        final reply = state.generatedReplies[index];
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 6),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0x0AFFFFFF),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0x1AFFFFFF)),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  reply,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12.5,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.send,
                                                  color: Color(0xFF6366F1),
                                                  size: 20,
                                                ),
                                                onPressed: () => _handleInsert(reply),
                                                tooltip: "Magic Send",
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Clean Programmatic Scroll Control Dock
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
                                        onPressed: () => _scrollReplies(-80), // Scrolls up smoothly
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0x13FFFFFF),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      IconButton(
                                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                                        onPressed: () => _scrollReplies(80), // Scrolls down smoothly
                                        style: IconButton.styleFrom(
                                          backgroundColor: const Color(0x13FFFFFF),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            : Align(
                                alignment: Alignment.bottomCenter,
                                child: SizedBox(
                                  width: double.infinity,
                                  height: 48,
                                  child: ElevatedButton(
                                    onPressed: _handleGenerate,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF6366F1),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text(
                                      "Generate Magic Replies",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                  ),
                ),
                
                // 6. BOTTOM ACTION BAR (SHOWS CANCEL ACTION ON GENERATED REPLIES)
                if (state.generatedReplies.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 38,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _instructionController.clear();
                        context.read<BubbleOverlayBloc>().add(
                              ClearCurrentStateEvent(),
                            );
                      },
                      icon: const Icon(Icons.close, color: Colors.white70, size: 14),
                      label: const Text(
                        "Cancel Choices",
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0x22FFFFFF)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}