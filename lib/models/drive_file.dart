import 'package:flutter/material.dart';

class DriveFile {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String date;
  final bool isStarred;
  final String? previewUrl;

  DriveFile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.date,
    this.isStarred = false,
    this.previewUrl,
  });
}
