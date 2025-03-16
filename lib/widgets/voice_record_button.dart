// lib/widgets/voice_record_button.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/voice_note_recorder.dart';
import '../utils/constants.dart';
import 'package:permission_handler/permission_handler.dart';

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
  bool _isInitialized = false;
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

    // Проверка разрешений при инициализации
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final initialized = await _recorder.initialize();
    setState(() {
      _isInitialized = initialized;
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _startRecording() async {
    // Если инициализация не выполнена или в процессе записи, выходим
    if (!_isInitialized || _isRecording) return;

    // Проверяем разрешения ещё раз
    final status = await Permission.microphone.status;
    if (!status.isGranted) {
      if (mounted) {
        // Показываем диалог с объяснением, почему нам нужен доступ к микрофону
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Для записи голосовых заметок необходим доступ к микрофону'),
            action: SnackBarAction(
              label: 'Настройки',
              onPressed: () {
                openAppSettings();
              },
            ),
          ),
        );
      }
      return;
    }

    final started = await _recorder.startRecording();

    if (started && mounted) {
      setState(() {
        _isRecording = true;
      });

      // Слушаем изменения амплитуды
      _amplitudeSubscription = _recorder.amplitudeStream?.listen((amplitude) {
        if (mounted) {
          setState(() {
            _currentAmplitude = amplitude;
          });
        }
      });

      // Показываем индикатор записи
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Идет запись голосового сообщения..."),
          backgroundColor: Colors.deepPurple,
          duration: Duration(seconds: 60), // Длительный срок
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Не удалось начать запись"),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _stopRecording() async {
    if (!_isRecording) return;

    final audioPath = await _recorder.stopRecording();
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    if (mounted) {
      setState(() {
        _isRecording = false;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (audioPath != null) {
        widget.onRecordComplete(audioPath);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Голосовое сообщение записано"),
            duration: Duration(seconds: 1),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Ошибка при записи голосового сообщения"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _cancelRecording() async {
    if (!_isRecording) return;

    await _recorder.cancelRecording();
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    if (mounted) {
      setState(() {
        _isRecording = false;
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Запись отменена"),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: _isInitialized ? _startRecording : _checkPermission,
      onLongPressEnd: (_) => _stopRecording(),
      onLongPressCancel: _cancelRecording,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, _) {
          final scale = _isRecording
              ? 1.0 + (_currentAmplitude * 0.3)
              : 1.0 + (_pulseController.value * 0.1);

          return Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  _isRecording ? Colors.deepPurple : AppColors.accentSecondary,
              boxShadow: [
                BoxShadow(
                  color: _isRecording
                      ? Colors.deepPurple.withOpacity(0.4)
                      : AppColors.accentSecondary.withOpacity(0.3),
                  blurRadius: _isRecording ? 12 : 8,
                  spreadRadius: _isRecording ? 2 : 0,
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Transform.scale(
              scale: scale,
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
