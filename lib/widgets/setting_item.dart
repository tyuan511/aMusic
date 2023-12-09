import 'package:flutter/material.dart';

class SettingItem extends StatelessWidget {
  final String label;
  final Widget value;

  const SettingItem({Key? key, required this.label, required this.value}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const Spacer(),
          value
        ],
      ),
    );
  }
}
