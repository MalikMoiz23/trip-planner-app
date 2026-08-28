import 'package:flutter/material.dart';

class ItineraryItem {
  const ItineraryItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hours,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final double hours;
}

class ItineraryDay {
  const ItineraryDay({
    required this.dayNumber,
    required this.date,
    required this.title,
    required this.items,
  });

  final int dayNumber;
  final DateTime date;
  final String title;
  final List<ItineraryItem> items;

  double get totalHours => items.fold(0.0, (sum, i) => sum + i.hours);
}
