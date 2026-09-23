import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store/app_store.dart';
import '../theme/app_theme.dart';
import '../theme/theme_choice.dart';
import '../utils/formatters.dart';
import '../widgets/design_system.dart';
import 'login_screen.dart';

enum _SyncAction { create, join, push, pull, leave }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final AppStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _savingTheme = false;
  bool _savingName = false;
  bool _syncing = false;
  bool _backfillingPhotos = false;

  bool get _busy =>
      _syncing || _backfillingPhotos || _savingName || _savingTheme;

  String _formatPercent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  void _feedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _chooseTheme() async {
    final choice = await showModalBottomSheet<ThemeChoice>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .8,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Choose a theme',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                const Text(
                  'Applies across SariScan and stays saved on this phone.',
                ),
                const SizedBox(height: 16),
                for (final choice in ThemeChoice.values)
                  ListTile(
                    key: ValueKey('theme-${choice.name}'),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    selected: widget.store.themeChoice == choice,
                    selectedColor: AppTheme.of(context).emeraldDeep,
                    selectedTileColor: AppTheme.of(context).mint,
                    leading: CircleAvatar(
                      backgroundColor: AppPalette.forChoice(choice).base,
                      child: Icon(
                        choice == ThemeChoice.dark
                            ? Icons.dark_mode_outlined
                            : Icons.palette_outlined,
                        color: AppPalette.forChoice(choice).emeraldDeep,
                      ),
                    ),
                    title: Text(choice.label),
                    subtitle: choice == ThemeChoice.defaultTheme
                        ? const Text('Original SariScan green')
                        : null,
                    trailing: Icon(
                      widget.store.themeChoice == choice
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: widget.store.themeChoice == choice
                          ? AppTheme.of(context).emeraldDeep
                          : AppTheme.of(context).muted,
                    ),
                    onTap: () => Navigator.pop(context, choice),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    setState(() => _savingTheme = true);
    final error = await widget.store.updateTheme(choice);
    if (!mounted) return;
    setState(() => _savingTheme = false);
    _feedback(error ?? '${choice.label} theme saved.');
  }

  Future<void> _editMarkup() async {
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MarkupDialog(store: widget.store),
    );
    if (saved == true) _feedback('Default markup updated.');
  }

  Future<void> _showInfo(String title, List<Widget> content) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: content,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of SariScan?'),
        content: const Text(
          'Your saved store data will stay on this phone. '
          'Your current cart will be cleared. Use phone security to sign in again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await widget.store.logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _changeName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) =>
          ChangeNameDialog(initialName: widget.store.registeredOwnerName ?? ''),
    );
    if (!mounted || newName == null) return;
    setState(() => _savingName = true);
    final error = await widget.store.renameOwner(newName);
    if (!mounted) return;
    setState(() => _savingName = false);
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Store name updated.')));
  }

  // -----------------------------------------------------------------
  // Photo sync (Supabase Storage)
  // -----------------------------------------------------------------

  /// Uploads any product photo that predates image sync being set up, so
  /// existing products (not just newly-added ones) start following their
  /// photos to other phones too.
  Future<void> _backfillPhotos() async {
    if (widget.store.syncCode == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Set up cloud sync first.')));
      return;
    }
    setState(() => _backfillingPhotos = true);
    final count = await widget.store.backfillProductImages();
    if (!mounted) return;
    setState(() => _backfillingPhotos = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.store.photoSyncWarning ??
              '$count photo(s) uploaded. Next, tap Sync store > Upload changes '
                  'to share photo links, then Download latest on the other phone.',
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Cloud sync
  // -----------------------------------------------------------------

  Future<void> _openSyncSheet() async {
    final linked = widget.store.syncCode != null;
    final action = await showModalBottomSheet<_SyncAction>(
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
                'Sync this store',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (!linked) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Create sync code'),
                  subtitle: const Text(
                    "Upload this phone's data to a new cloud store",
                  ),
                  onTap: () => Navigator.pop(context, _SyncAction.create),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('Join with a code'),
                  subtitle: const Text(
                    'Connect using another phone’s sync code',
                  ),
                  onTap: () => Navigator.pop(context, _SyncAction.join),
                ),
              ] else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Upload changes'),
                  subtitle: const Text(
                    "Replace cloud data with this phone's data",
                  ),
                  onTap: () => Navigator.pop(context, _SyncAction.push),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Download latest'),
                  subtitle: const Text(
                    "Replace this phone's data with cloud data",
                  ),
                  onTap: () => Navigator.pop(context, _SyncAction.pull),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.link_off_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  title: const Text('Unlink this phone'),
                  subtitle: const Text(
                    'Clear this phone; keep the store in the cloud',
                  ),
                  onTap: () => Navigator.pop(context, _SyncAction.leave),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (action == null || !mounted) return;

    // The bottom sheet's closing animation is still finishing when this
    // Future completes; opening another dialog immediately can collide
    // with that transition and trip a framework assertion. A short delay
    // lets the sheet fully close first.
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    switch (action) {
      case _SyncAction.create:
        await _confirmAndRun(
          title: 'Create sync code?',
          message:
              "Upload this phone's data. Use the code to link other phones.",
          confirmLabel: 'Create',
          successMessage: 'Sync code created.',
          run: () => widget.store.startCloudSync(),
        );
        break;
      case _SyncAction.join:
        await _promptJoinCode();
        break;
      case _SyncAction.push:
        await _confirmAndRun(
          title: 'Upload to cloud?',
          message:
              "Replace cloud data with this phone's data. "
              'Other phones receive changes on their next download.',
          confirmLabel: 'Upload',
          successMessage: 'Uploaded to cloud.',
          run: () => widget.store.pushToCloud(),
        );
        break;
      case _SyncAction.pull:
        await _confirmAndRun(
          title: 'Download from cloud?',
          message:
              "Replace this phone's data with cloud data. "
              'Unsynced changes will be lost.',
          confirmLabel: 'Download',
          isDestructive: true,
          successMessage: 'Downloaded from cloud.',
          run: () => widget.store.pullFromCloud(),
        );
        break;
      case _SyncAction.leave:
        await _confirmLeave();
        break;
    }
  }

  Future<void> _confirmAndRun({
    required String title,
    required String message,
    required String confirmLabel,
    required String successMessage,
    required Future<CloudSyncResult> Function() run,
    bool isDestructive = false,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _syncing = true);
    final result = await run();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? '$successMessage${result.warning == null ? '' : ' ${result.warning}'}'
              : (result.error ?? 'Something went wrong.'),
        ),
      ),
    );
  }

  Future<void> _promptJoinCode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (context) => const _JoinSyncCodeDialog(),
    );
    if (code == null || code.trim().isEmpty || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Replace this phone's data?"),
        content: const Text(
          "Replace this phone's data with the linked store's cloud data. "
          'Unsynced changes will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Join & replace'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _syncing = true);
    final result = await widget.store.joinCloudSync(code);
    if (!mounted) return;
    setState(() => _syncing = false);

    if (result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Joined and downloaded cloud data.'
            '${result.warning == null ? '' : ' ${result.warning}'}',
          ),
        ),
      );
      return;
    }

    // A wrong or unknown code is common enough (typos, expired codes) that
    // it gets a clear dialog with an explicit OK, rather than a snackbar
    // that can be missed.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Could not join store'),
        content: Text(
          result.error ?? 'Store not found. Check the sync code and try again.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLeave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unlink this phone?'),
        content: const Text(
          'Remove all store records and cached product photos from this phone. '
          'Changes you have not uploaded will be lost. Cloud data stays saved. '
          'Keep your sync code to download the store again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlink'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _syncing = true);
    final error = await widget.store.leaveCloudSync();
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              'Phone cleared and unlinked. Your cloud store is still saved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final palette = AppTheme.of(context);
        final linked = widget.store.syncCode != null;
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    // A store identity header, distinct from the preference groups.
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 8, 4, 24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BrandMark(size: 52),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'YOUR STORE',
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(
                                        color: palette.muted,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.store.registeredOwnerName ??
                                      'Store Owner',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Make SariScan work for your store.',
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 13,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _SettingsGroup(
                      title: 'Store account',
                      children: [
                        _SettingsRow(
                          icon: Icons.storefront_outlined,
                          title: 'Store name',
                          description:
                              widget.store.registeredOwnerName ??
                              'No store registered',
                          busy: _savingName,
                          onTap: _busy || !widget.store.hasLocalAccount
                              ? null
                              : _changeName,
                        ),
                        _SettingsRow(
                          icon: Icons.lock_outline_rounded,
                          title: 'Phone security',
                          description: 'Protected by your device lock',
                          onTap: () => _showInfo('Phone security', const [
                            Text(
                              'SariScan uses your phone\'s fingerprint, face unlock, PIN, '
                              'pattern, or password when you sign in.',
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Manage these methods in your phone settings. '
                              'There is no separate SariScan password.',
                            ),
                          ]),
                        ),
                      ],
                    ),
                    _SettingsGroup(
                      title: 'Preferences',
                      children: [
                        _SettingsRow(
                          icon: Icons.palette_outlined,
                          title: 'Appearance',
                          description:
                              '${widget.store.themeChoice.label} theme',
                          busy: _savingTheme,
                          onTap: _busy ? null : _chooseTheme,
                        ),
                        _SettingsRow(
                          icon: Icons.percent_rounded,
                          title: 'Default markup',
                          description:
                              '${_formatPercent(widget.store.markupPercent)}% added to cost for suggested prices',
                          onTap: _busy ? null : _editMarkup,
                        ),
                      ],
                    ),
                    const SectionHeading('Data & sync'),
                    const SizedBox(height: 12),
                    Card(
                      elevation: 1,
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SettingsRow(
                            icon: widget.store.storageError == null
                                ? Icons.offline_pin_outlined
                                : Icons.error_outline_rounded,
                            title: widget.store.storageError == null
                                ? 'Available offline'
                                : 'Storage needs attention',
                            description:
                                widget.store.storageError ??
                                'Products, sales, and customer balances stay on this phone.',
                            onTap: () => _showInfo('Your store data', [
                              const Text(
                                'Your store records are saved on this phone so you can keep selling offline.',
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Cloud sync is manual. Upload your changes before downloading on another phone. '
                                'A download replaces the receiving phone\'s records.',
                              ),
                              if (widget.store.storageError != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  widget.store.storageError!,
                                  style: TextStyle(color: palette.danger),
                                ),
                              ],
                            ]),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.cloud_sync_outlined,
                                      color: palette.emeraldDeep,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Cloud sync',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  !widget.store.isCloudSyncAvailable
                                      ? 'Unavailable right now. You can continue using your store offline.'
                                      : linked
                                      ? 'Linked to your cloud store. Sync when you are ready.'
                                      : 'Link your phones with a sync code to share store records.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: palette.muted,
                                  ),
                                ),
                                if (linked) ...[
                                  const SizedBox(height: 14),
                                  Container(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      8,
                                      4,
                                      8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: palette.baseSunken,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'SYNC CODE',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: palette.muted,
                                                      letterSpacing: 1,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              SelectableText(
                                                widget.store.syncCode!,
                                                style: const TextStyle(
                                                  fontFamily: 'SpaceGrotesk',
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 18,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'Copy sync code',
                                          onPressed: () async {
                                            try {
                                              await Clipboard.setData(
                                                ClipboardData(
                                                  text: widget.store.syncCode!,
                                                ),
                                              );
                                              _feedback('Sync code copied.');
                                            } catch (_) {
                                              _feedback(
                                                'Could not copy the code. Try again.',
                                              );
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.copy_rounded,
                                            size: 20,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    widget.store.lastSyncedAt == null
                                        ? 'No sync recorded yet'
                                        : 'Last synced ${shortDateTime(widget.store.lastSyncedAt!)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: palette.muted,
                                    ),
                                  ),
                                ],
                                if (widget.store.isCloudSyncAvailable) ...[
                                  const SizedBox(height: 16),
                                  FilledButton.icon(
                                    onPressed: _busy ? null : _openSyncSheet,
                                    icon: _syncing
                                        ? const _SettingsProgress()
                                        : const Icon(Icons.sync_rounded),
                                    label: Text(
                                      _syncing
                                          ? 'Syncing store...'
                                          : linked
                                          ? 'Sync store'
                                          : 'Set up cloud sync',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (widget.store.isImageSyncAvailable) ...[
                            const Divider(height: 1, indent: 64, endIndent: 16),
                            _SettingsRow(
                              icon: Icons.add_photo_alternate_outlined,
                              title: 'Upload product photos',
                              description: !linked
                                  ? 'Set up cloud sync to share photos'
                                  : _backfillingPhotos
                                  ? 'Uploading photos...'
                                  : 'Retry photos, then sync to share their links',
                              busy: _backfillingPhotos,
                              onTap: _busy || !linked ? null : _backfillPhotos,
                            ),
                            if (widget.store.photoSyncWarning != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  16,
                                ),
                                child: Text(
                                  widget.store.photoSyncWarning!,
                                  style: TextStyle(
                                    color: palette.danger,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _SettingsGroup(
                      title: 'Help & information',
                      children: [
                        _SettingsRow(
                          icon: Icons.help_outline_rounded,
                          title: 'Help & FAQ',
                          description: 'Pricing, backups, and switching phones',
                          onTap: () => _showInfo('Help & FAQ', const [
                            _HelpAnswer(
                              'How does markup work?',
                              'A 10% markup on a ₱100 cost suggests a ₱110 selling price. You can still set each product\'s price yourself.',
                            ),
                            _HelpAnswer(
                              'How do I use another phone?',
                              'Create a sync code on the phone with your store data. Join with that code on the other phone. Joining replaces its local records.',
                            ),
                            _HelpAnswer(
                              'When should I sync?',
                              'Upload after making changes, then download on the other phone. Sync is manual; avoid editing both phones before syncing.',
                            ),
                            _HelpAnswer(
                              'Why are photos missing?',
                              'Use Upload product photos, then Sync store > Upload changes. On the other phone, choose Download latest.',
                            ),
                            _HelpAnswer(
                              'What happens when I log out?',
                              'Saved records stay on this phone. The current cart is cleared, and signing in again requires phone security.',
                            ),
                          ]),
                        ),
                        _SettingsRow(
                          icon: Icons.info_outline_rounded,
                          title: 'About SariScan',
                          description: 'Scan. Sell. Track.',
                          onTap: () => showAboutDialog(
                            context: context,
                            applicationName: 'SariScan',
                            applicationIcon: const BrandMark(),
                            children: [
                              const Text(
                                'Your store\'s daily companion for products, sales, stock, '
                                'and customer balances. Built to keep your store moving offline.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SectionHeading('Account actions'),
                    const SizedBox(height: 8),
                    _SettingsRow(
                      icon: Icons.logout_rounded,
                      title: 'Log out',
                      description: 'Keep saved store data on this phone',
                      onTap: _busy ? null : _confirmLogout,
                    ),
                    if (linked)
                      _SettingsRow(
                        icon: Icons.link_off_rounded,
                        title: 'Unlink this phone',
                        description:
                            'Clear local records; keep your cloud store',
                        destructive: true,
                        onTap: _busy ? null : _confirmLeave,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MarkupDialog extends StatefulWidget {
  const _MarkupDialog({required this.store});
  final AppStore store;

  @override
  State<_MarkupDialog> createState() => _MarkupDialogState();
}

class _MarkupDialogState extends State<_MarkupDialog> {
  late final TextEditingController _controller;
  late double _savedValue;
  String? _error;
  bool _saving = false;
  bool _confirmingDiscard = false;
  bool _allowClose = false;

  double? get _value => double.tryParse(_controller.text);
  bool get _dirty => _value != _savedValue || _error != null;

  @override
  void initState() {
    super.initState();
    _savedValue = widget.store.markupPercent;
    _controller = TextEditingController(
      text: _savedValue == _savedValue.roundToDouble()
          ? _savedValue.toStringAsFixed(0)
          : _savedValue.toString(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    if (_saving || _confirmingDiscard) return;
    if (_dirty) {
      _confirmingDiscard = true;
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard markup changes?'),
          content: const Text('Your new markup has not been saved.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Discard'),
            ),
          ],
        ),
      );
      _confirmingDiscard = false;
      if (!mounted || discard != true) return;
    }
    if (!mounted) return;
    setState(() => _allowClose = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context);
    });
  }

  Future<void> _save() async {
    final value = _value;
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        !(100 * (1 + value / 100)).isFinite) {
      setState(() => _error = 'Enter a valid percentage of 0 or more.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.store.updateMarkupPercent(value);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    setState(() {
      _savedValue = value;
      _saving = false;
      _allowClose = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.pop(context, true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _value;
    return PopScope(
      canPop: _allowClose || (!_dirty && !_saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: AlertDialog(
        scrollable: true,
        title: const Text('Default markup'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Add a percentage to cost to suggest selling prices. '
              'Existing product prices stay the same.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _controller,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.done,
              inputFormatters: [
                TextInputFormatter.withFunction(
                  (oldValue, newValue) =>
                      RegExp(r'^\d*\.?\d{0,2}$').hasMatch(newValue.text)
                      ? newValue
                      : oldValue,
                ),
              ],
              decoration: InputDecoration(
                labelText: 'Markup',
                suffixText: '%',
                prefixIcon: const Icon(Icons.percent_rounded),
                errorText: _error,
                errorMaxLines: 5,
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) {
                if (!_saving && _dirty) _save();
              },
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.of(context).baseSunken,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PRICE PREVIEW',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    preview == null ||
                            !preview.isFinite ||
                            !(100 * (1 + preview / 100)).isFinite
                        ? 'Enter a markup to preview a price.'
                        : '${money(100)} cost → ${money(100 * (1 + preview / 100))} selling price',
                    style: const TextStyle(fontSize: 14, height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _saving
                  ? 'Saving markup...'
                  : _dirty
                  ? 'Unsaved changes'
                  : 'Saved on this phone',
              style: TextStyle(fontSize: 12, color: AppTheme.of(context).muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _close,
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving || !_dirty ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save markup'),
          ),
        ],
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title),
        const SizedBox(height: 12),
        Card(
          elevation: 1,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 64, endIndent: 16),
                children[i],
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.busy = false,
    this.destructive = false,
  });
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool busy;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final palette = AppTheme.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 12,
      minLeadingWidth: 32,
      titleAlignment: ListTileTitleAlignment.top,
      leading: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Icon(
          icon,
          color: destructive ? palette.danger : palette.emeraldDeep,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: destructive ? palette.danger : palette.ink,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          description,
          style: TextStyle(fontSize: 13, height: 1.45, color: palette.muted),
        ),
      ),
      trailing: busy
          ? const _SettingsProgress()
          : onTap != null
          ? Icon(Icons.chevron_right_rounded, color: palette.muted, size: 20)
          : null,
      onTap: onTap,
    );
  }
}

class _SettingsProgress extends StatelessWidget {
  const _SettingsProgress();
  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

class _HelpAnswer extends StatelessWidget {
  const _HelpAnswer(this.question, this.answer);
  final String question;
  final String answer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(question, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(answer, style: const TextStyle(height: 1.5)),
      ],
    ),
  );
}

/// A dedicated dialog widget for entering a sync code.
///
/// The TextEditingController belongs to this widget's own State, so it
/// stays alive for the dialog's entire lifetime — including its closing
/// animation — and is disposed only once Flutter actually unmounts this
/// widget. Creating and manually disposing a controller from the caller
/// right after `showDialog` returns is unsafe: the dialog can still be
/// mid-transition at that point, and touching an already-disposed
/// controller from a still-attached TextField is what causes crashes.
class _JoinSyncCodeDialog extends StatefulWidget {
  const _JoinSyncCodeDialog();

  @override
  State<_JoinSyncCodeDialog> createState() => _JoinSyncCodeDialogState();
}

class _JoinSyncCodeDialogState extends State<_JoinSyncCodeDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Join with a code'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(labelText: 'Sync code'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Join')),
      ],
    );
  }
}
