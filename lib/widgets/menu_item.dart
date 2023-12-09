import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MenuItem extends StatelessWidget {
  const MenuItem({Key? key, required this.path, required this.title, required this.icon, this.isActive = false})
      : super(key: key);

  final String path;
  final String title;
  final IconData icon;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary.withOpacity(0.7);

    return InkWell(
      onTap: () {
        context.go(path);
      },
      customBorder: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(
              icon,
              size: 28,
              color: color,
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium!.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
