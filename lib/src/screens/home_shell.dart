import '../l10n/app_localizations.dart';
import 'package:flutter/material.dart';

import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import 'pos_screen.dart';
import 'products_screen.dart';
import 'reports_screen.dart';
import 'settings_screen.dart';
import '../widgets/guided_tutorial.dart';
import 'utang_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final AppStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final Set<int> _visitedTabs = {0};

  final _posTarget = GlobalKey();
  final _productsTarget = GlobalKey();
  final _addTarget = GlobalKey();
  final _scanTarget = GlobalKey();
  final _utangTarget = GlobalKey();
  final _reportsTarget = GlobalKey();
  final _accountTarget = GlobalKey();
  bool _tourOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.store.needsFirstUseTutorial) _openTutorial();
    });
  }

  Future<void> _openTutorial() async {
    if (_tourOpen) return;
    _tourOpen = true;
    final previousTab = _index;
    void showStep(int step) {
      final tab = step <= 1
          ? 1
          : step <= 4
          ? 0
          : step == 5
          ? 2
          : step == 6
          ? 3
          : 0;
      setState(() {
        _index = tab;
        _visitedTabs.add(tab);
      });
    }

    showStep(0);
    await showGeneralDialog<void>(
      context: context,
      barrierLabel: context.tr("App tutorial"),
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => GuidedTutorial(
        targets: [
          _productsTarget,
          _addTarget,
          _posTarget,
          _scanTarget,
          _posTarget,
          _utangTarget,
          _reportsTarget,
          _accountTarget,
        ],
        onStepChanged: showStep,
      ),
      transitionBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    );
    if (!mounted) return;
    setState(() {
      _tourOpen = false;
      _index = previousTab;
    });
    await widget.store.dismissTutorial();
  }

  void _openMore() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr("Store account"),
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  child: Icon(Icons.person_outline_rounded),
                ),
                title: Text(
                  widget.store.currentUserName ?? context.tr("Store Owner"),
                ),
                subtitle: Text(context.tr("Protected by phone security")),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  widget.store.storageError == null
                      ? Icons.phone_android_rounded
                      : Icons.error_outline_rounded,
                  color: widget.store.storageError == null
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  widget.store.storageError == null
                      ? context.tr("Saved on this phone")
                      : context.tr("Phone storage needs attention"),
                ),
                subtitle: Text(
                  widget.store.storageError ??
                      context.tr(
                        "Products, customers, sales, and utang work offline.",
                      ),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.settings_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: Text(context.tr("Settings")),
                subtitle: Text(
                  context.tr("Pricing markup, store name, and more"),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SettingsScreen(
                        store: widget.store,
                        onStartTutorial: () {
                          Navigator.pop(this.context);
                          _openTutorial();
                        },
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined),
                title: Text(context.tr("App tutorial")),
                subtitle: Text(
                  context.tr("Learn products, sales, utang, and more"),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(context);
                  _openTutorial();
                },
              ),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.store.logout();
                },
                icon: const Icon(Icons.logout_rounded),
                label: Text(context.tr("Log out")),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      PosScreen(store: widget.store, scanTutorialKey: _scanTarget),
      ProductsScreen(store: widget.store, addTutorialKey: _addTarget),
      UtangScreen(store: widget.store),
      ReportsScreen(store: widget.store),
    ];

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 66,
        leading: const Padding(
          padding: EdgeInsets.fromLTRB(16, 13, 8, 13),
          child: BrandMark(),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                'Tindahan POS',
                context.tr("Inventory"),
                context.tr("Utang Book"),
                context.tr("Sales & Analytics"),
              ][_index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              _index == 0
                  ? context.tr(
                      "{0}’s store",
                      args: [widget.store.currentUserName ?? 'Your'],
                    )
                  : [
                      context.tr("Your store, at a glance"),
                      context.tr("Products & stock"),
                      context.tr("Customer balances"),
                      context.tr("Your business in numbers"),
                    ][_index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.of(context).muted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.tr("App tutorial"),
            onPressed: _openTutorial,
            icon: const Icon(Icons.help_outline_rounded),
          ),
          IconButton(
            key: _accountTarget,
            tooltip: context.tr("Store account"),
            onPressed: _openMore,
            icon: const Icon(Icons.account_circle_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: IndexedStack(
            index: _index,
            children: [
              for (var index = 0; index < screens.length; index++)
                if (_visitedTabs.contains(index))
                  TickerMode(enabled: index == _index, child: screens[index])
                else
                  const SizedBox.shrink(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: AppTheme.of(context).base,
          boxShadow: [
            BoxShadow(
              color: AppTheme.of(context).baseDark.withValues(alpha: .7),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) {
            if (value == 4) {
              _openMore();
            } else {
              setState(() {
                _index = value;
                _visitedTabs.add(value);
              });
            }
          },
          destinations: [
            NavigationDestination(
              key: _posTarget,
              icon: const Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale),
              label: 'POS',
            ),
            NavigationDestination(
              key: _productsTarget,
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: context.tr("Products"),
            ),
            NavigationDestination(
              key: _utangTarget,
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book),
              label: 'Utang',
            ),
            NavigationDestination(
              key: _reportsTarget,
              icon: const Icon(Icons.bar_chart_outlined),
              selectedIcon: Icon(Icons.bar_chart),
              label: context.tr("Reports"),
            ),
            NavigationDestination(
              icon: Icon(Icons.more_horiz_rounded),
              selectedIcon: Icon(Icons.more_horiz_rounded),
              label: context.tr("More"),
            ),
          ],
        ),
      ),
    );
  }
}
