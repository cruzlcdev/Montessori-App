import 'package:flutter/material.dart';
import 'package:prototipo_2/screens/grades/group_report_cards_screen.dart';

class PrimaryGradesScreen extends StatelessWidget {
  const PrimaryGradesScreen({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  final String groupId;
  final String groupName;

  @override
  Widget build(BuildContext context) {
    return GroupReportCardsScreen(groupId: groupId, groupName: groupName);
  }
}
