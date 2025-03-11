// lib/widgets/voice_record_button.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_note_recorder.dart';
import '../utils/constants.dart';

class VoiceRecordButton extends StatefulWidget {
  final Function(String audioPath) onRecordComplete;
  final double size;

  const VoiceRecordButton({
    Key? key,
    required this.onRecordComplete,
    this.size = 48.0,
  }) : super(key: key);

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton>
    with SingleTickerProviderStateMixin {
  final VoiceNoteRecorder _recorder = VoiceNoteRecorder();
  bool _isRecording = false;
  double _currentAmplitude = 0.0;
  StreamSubscription<double>? _amplitudeSubscription;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _startRecording() async {
    final started = await _recorder.startRecording();

    if (started) {
      setState(() {
        _isRecording = true;
      });

      // Слушаем изменения амплитуды
      _amplitudeSubscription = _recorder.amplitudeStream?.listen((amplitude) {
        setState(() {
          _currentAmplitude = amplitude;
        });
      });

      // Показываем индикатор записи
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Запись голосового сообщения..."),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;

    final audioPath = await _recorder.stopRecording();
    _amplitudeSubscription?.cancel();

    setState(() {
      _isRecording = false;
    });

    if (audioPath != null) {
      widget.onRecordComplete(audioPath);
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Голосовое сообщение записано"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _cancelRecording() {
    if (!_isRecording) return;

    _recorder.cancelRecording();
    _amplitudeSubscription?.cancel();

    setState(() {
      _isRecording = false;
    });

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _startRecording,
      onLongPressEnd: (_) => _stopRecording(),
      onLongPressCancel: _cancelRecording,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final scale = _isRecording
              ? 1.0 + (_currentAmplitude * 0.3)
              : 1.0 + (_pulseController.value * 0.1);

          return Transform.scale(
            scale: scale,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording ? Colors.red : AppColors.accentPrimary,
                boxShadow: _isRecording
                    ? [
                        BoxShadow(
                          color: Colors.red.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: Icon(
                _isRecording ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: widget.size * 0.5,
              ),
            ),
          );
        },
      ),
    );
  }
}
