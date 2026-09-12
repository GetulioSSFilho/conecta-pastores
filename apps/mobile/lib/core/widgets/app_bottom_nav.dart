import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBottomNavItem {
  const AppBottomNavItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<AppBottomNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Material(
    color: AppColors.surface,
    child: SafeArea(
      top: false,
      child: Container(
        height: 60,
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            for (var index = 0; index < items.length; index++)
              Expanded(
                child: InkWell(
                  onTap: () => onChanged(index),
                  child: _BottomNavDestination(
                    item: items[index],
                    selected: index == selectedIndex,
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _BottomNavDestination extends StatelessWidget {
  const _BottomNavDestination({required this.item, required this.selected});

  final AppBottomNavItem item;
  final bool selected;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        selected ? item.selectedIcon : item.icon,
        size: 20,
        color: selected ? AppColors.primary : AppColors.mutedInk,
      ),
      const SizedBox(height: 2),
      Text(
        item.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: selected ? AppColors.primary : AppColors.mutedInk,
          fontSize: 10,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    ],
  );
}
