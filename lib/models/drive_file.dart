import 'package:flutter/material.dart';

class DriveFile {
  final int? id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final String date;
  final String? previewUrl;
  final bool isStarred;
  final String? size;
  final String? directoryName;
  final int? directoryId;

  DriveFile({
    this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.date,
    this.previewUrl,
    this.isStarred = false,
    this.size,
    this.directoryName,
    this.directoryId,
  });
}
