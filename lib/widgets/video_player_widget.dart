import 'package:flutter/material.dart';
import 'dart:io';

class VideoPlayerWidget extends StatelessWidget {
  final String videoPath;
  final VoidCallback? onClose;

  const VideoPlayerWidget({
    Key? key,
    required this.videoPath,
    this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Placeholder for actual video player
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.video_library,
                  size: 50,
                  color: Colors.white,
                ),
                SizedBox(height: 10),
                Text(
                  'Видео: ${videoPath.split('/').last}',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),

          // Close button
          if (onClose != null)
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
            ),
        ],
      ),
    );
  }
}
