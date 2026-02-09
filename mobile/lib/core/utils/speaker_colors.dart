import 'package:flutter/material.dart';

/// Returns a color associated with a speaker label.
Color getSpeakerColor(String label) {
  const colors = {
    'A': Colors.blue,
    'B': Colors.green,
    'C': Colors.purple,
    'D': Colors.orange,
    'E': Colors.pink,
    'F': Colors.teal,
  };
  return colors[label] ?? Colors.grey;
}
