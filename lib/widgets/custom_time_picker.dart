import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Кастомный виджет для выбора времени
class CustomTimePicker extends StatefulWidget {
  final TimeOfDay initialTime;
  final ValueChanged<TimeOfDay>? onTimeChanged;
  final bool use24HourFormat;

  const CustomTimePicker({
    Key? key,
    required this.initialTime,
    this.onTimeChanged,
    this.use24HourFormat = true,
  }) : super(key: key);

  @override
  State<CustomTimePicker> createState() => _CustomTimePickerState();
}

class _CustomTimePickerState extends State<CustomTimePicker> {
  late TimeOfDay _selectedTime;

  @override
  void initState() {
    super.initState();
    _selectedTime = widget.initialTime;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppDimens.buttonBorderRadius),
        boxShadow: [AppShadows.small],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Выберите время',
              style: AppTextStyles.heading3,
            ),
          ),
          InkWell(
            onTap: () => _selectTime(context),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.access_time,
                    color: AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _formatTime(_selectedTime),
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickTimeButton(const TimeOfDay(hour: 9, minute: 0)),
                _buildQuickTimeButton(const TimeOfDay(hour: 12, minute: 0)),
                _buildQuickTimeButton(const TimeOfDay(hour: 15, minute: 0)),
                _buildQuickTimeButton(const TimeOfDay(hour: 18, minute: 0)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    if (widget.onTimeChanged != null) {
                      widget.onTimeChanged!(_selectedTime);
                    }
                    Navigator.of(context).pop(_selectedTime);
                  },
                  child: Text(
                    'Готово',
                    style: TextStyle(color: AppColors.accentPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Открывает стандартный диалог выбора времени
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.accentPrimary,
              onPrimary: AppColors.textBackground,
              onSurface: AppColors.textOnLight,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      if (widget.onTimeChanged != null) {
        widget.onTimeChanged!(picked);
      }
    }
  }

  /// Создает кнопку быстрого выбора времени
  Widget _buildQuickTimeButton(TimeOfDay time) {
    final bool isSelected =
        _selectedTime.hour == time.hour && _selectedTime.minute == time.minute;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedTime = time;
        });
        if (widget.onTimeChanged != null) {
          widget.onTimeChanged!(time);
        }
      },
      borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentPrimary.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimens.smallBorderRadius),
          border: Border.all(
            color: isSelected ? AppColors.accentPrimary : Colors.transparent,
          ),
        ),
        child: Text(
          _formatTime(time),
          style: AppTextStyles.bodyMedium.copyWith(
            color: isSelected ? AppColors.accentPrimary : AppColors.textOnLight,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// Форматирует время в удобочитаемую строку
  String _formatTime(TimeOfDay time) {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');

    if (widget.use24HourFormat) {
      return '$hour:$minute';
    } else {
      String period = time.hour < 12 ? 'AM' : 'PM';
      int displayHour = time.hour > 12 ? time.hour - 12 : time.hour;
      displayHour = displayHour == 0 ? 12 : displayHour;
      return '$displayHour:$minute $period';
    }
  }
}

/// Статический метод для показа диалога выбора времени
class TimePickerDialog {
  static Future<TimeOfDay?> show({
    required BuildContext context,
    required TimeOfDay initialTime,
    bool use24HourFormat = true,
  }) async {
    return await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.cardBorderRadius),
          ),
          child: CustomTimePicker(
            initialTime: initialTime,
            use24HourFormat: use24HourFormat,
          ),
        );
      },
    );
  }
}
