import 'package:flutter/material.dart';
import 'calendar_design.dart';

class CalendarBackgroundDecor extends StatelessWidget {
  const CalendarBackgroundDecor({super.key});

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: CalendarDesign.background(context));
}
