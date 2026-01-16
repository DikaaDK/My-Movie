import 'package:flutter/material.dart';

import 'package:mymovie/pages/cuplikan_page.dart';
import 'package:mymovie/pages/explore_page.dart';
import 'package:mymovie/pages/home_page.dart';
import 'package:mymovie/pages/profile_page.dart';

class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  late final List<Widget> _pages;
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pages = [
      const HomePage(),
      const ExplorePage(),
      CuplikanPage(currentIndexListenable: _currentIndexNotifier),
      const ProfilePage(),
    ];
    _currentIndex = _normalizeIndex(widget.initialIndex);
    _currentIndexNotifier.value = _currentIndex;
  }

  @override
  void didUpdateWidget(covariant MainTabScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialIndex != widget.initialIndex) {
      setState(() {
        _currentIndex = _normalizeIndex(widget.initialIndex);
      });
    }
  }

  @override
  void dispose() {
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: MainBottomNav(
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
    );
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _currentIndex = index;
      _currentIndexNotifier.value = index;
    });
  }

  int _normalizeIndex(int index) {
    if (index < 0) {
      return 0;
    }
    if (index >= _pages.length) {
      return _pages.length - 1;
    }
    return index;
  }
}

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key, this.currentIndex = 0, this.onTap});

  final int currentIndex;
  final ValueChanged<int>? onTap;

  static const _labels = ['Beranda', 'Eksplor', 'Cuplikan', 'Profil'];
  static const _icons = [
    Icons.home_filled,
    Icons.grid_view_rounded,
    Icons.slideshow_rounded,
    Icons.person_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF081225).withValues(alpha: 0.94),
          border: const Border(
            top: BorderSide(color: Color(0xFF102140), width: 0.8),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: List.generate(_labels.length, (index) {
            final isActive = index == currentIndex;
            final color = isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.55);

            return Expanded(
              child: GestureDetector(
                onTap: onTap == null ? null : () => onTap!(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(_icons[index], color: color),
                    const SizedBox(height: 6),
                    Text(
                      _labels[index],
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: color,
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
