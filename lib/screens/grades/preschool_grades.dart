import 'package:flutter/material.dart';
import 'package:prototipo_2/screens/grades/group_report_cards_screen.dart';

class PreschoolGradesScreen extends StatelessWidget {
  const PreschoolGradesScreen({super.key, required this.gradeType});

  final String gradeType;

  @override
  Widget build(BuildContext context) {
    final groupId = _groupIdFromGradeType(gradeType);

    return GroupReportCardsScreen(groupId: groupId, groupName: gradeType);
  }

  String _groupIdFromGradeType(String gradeType) {
    switch (gradeType.toLowerCase()) {
      case 'preescolar':
      case 'casa de ninos':
      case 'casa de niños':
        return 'casa_ninos';
      case 'maternal':
      case 'comunidad infantil':
        return 'comunidad_infantil';
      default:
        return gradeType.toLowerCase().replaceAll(' ', '_');
    }
  }
}
