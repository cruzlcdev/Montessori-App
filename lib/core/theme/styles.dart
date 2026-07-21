// styles.dart
import 'package:flutter/material.dart';
import 'colors.dart';

class AppStyles {
  static final roundedBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(15),
    borderSide: const BorderSide(color: Colors.grey),
  );

  static final cardShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(15),
  );

  static const titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primaryBlue,
  );

  static const subtitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryBlue,
  );
}
