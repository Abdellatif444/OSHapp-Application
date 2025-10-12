import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ActivityListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final DateTime date;

  const ActivityListItem({
    super.key,
    required this.icon,
    required this.title,
    required this.date,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(icon, size: 20),
      ),
      title: Text(title),
      subtitle: Text(DateFormat('dd MMM yyyy, HH:mm').format(date)),
      dense: true,
    );
  }
}
