import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../store/app_store.dart';
import '../theme/app_theme.dart';
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
  late final TextEditingController _markupController;
  String? _markupError;
  bool _savingMarkup = false;
  bool _syncing = false;
  bool _backfillingPhotos = false;

  @override
  void initState() {
    super.initState();
    _markupController = TextEditingController(
      text: _formatPercent(widget.store.markupPercent),
    );
  }

  @override
  void dispose() {
    _markupController.dispose();
    super.dispose();
  }

  String _formatPercent(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);

  double get _previewMarkup =>
      double.tryParse(_markupController.text) ?? widget.store.markupPercent;

  Future<void> _saveMarkup() async {
    final value = double.tryParse(_markupController.text);
    if (value == null || value < 0) {
      setState(() => _markupError = 'Enter 0 or more.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _savingMarkup = true;
      _markupError = null;
    });
    final error = await widget.store.updateMarkupPercent(value);
    if (!mounted) return;
    setState(() => _savingMarkup = false);
    if (error != null) {
      setState(() => _markupError = error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Default markup updated.')),
    );
  }

  Future<void> _changeName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => ChangeNameDialog(
        initialName: widget.store.registeredOwnerName ?? '',
      ),
    );
    if (!mounted || newName == null) return;
    final error = await widget.store.renameOwner(newName);
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store name updated.')),
    );
  }

  // -----------------------------------------------------------------
  // Photo sync (ImgBB)
  // -----------------------------------------------------------------

  /// Uploads any product photo that predates image sync being set up, so
  /// existing products (not just newly-added ones) start following their
  /// photos to other phones too.
  Future<void> _backfillPhotos() async {
    setState(() => _backfillingPhotos = true);
    final count = await widget.store.backfillProductImages();
    if (!mounted) return;
    setState(() => _backfillingPhotos = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          count == 0
              ? 'All photos are already synced.'
              : '$count photo(s) uploaded — they will now sync to other phones.',
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
        child: Padding(
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
                  title: const Text('Create a new sync code'),
                  subtitle: const Text(
                    "Start cloud sync using this phone's current data",
                  ),
                  onTap: () => Navigator.pop(context, _SyncAction.create),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.link_rounded),
                  title: const Text('Join with a code'),
                  subtitle: const Text(
                    'Use a code from another phone for this store',
                  ),
                  onTap: () => Navigator.pop(context, _SyncAction.join),
                ),
              ] else ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_upload_outlined),
                  title: const Text('Upload my changes'),
                  subtitle: const Text(
                    "Replace the cloud copy with what's on this phone",
                  ),
                  onTap: () => Navigator.pop(context, _SyncAction.push),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Download latest'),
                  subtitle: const Text(
                    "Replace this phone's data with the cloud copy",
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
                    'Stop syncing without deleting cloud data',
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
              'This uploads everything currently on this phone to a new '
              'cloud store. Enter the resulting code on your other phones '
              'to join it.',
          confirmLabel: 'Create',
          successMessage: 'Sync code created — share it with your other phones.',
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
              "This replaces the cloud copy with what's on this phone. "
              'Other phones will get these changes next time they sync.',
          confirmLabel: 'Upload',
          successMessage: 'Uploaded to cloud.',
          run: () => widget.store.pushToCloud(),
        );
        break;
      case _SyncAction.pull:
        await _confirmAndRun(
          title: 'Download from cloud?',
          message:
              'This replaces everything on this phone with the cloud copy. '
              "Anything changed here since the last sync will be lost.",
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
              ? successMessage
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
          'Joining will replace everything currently on this phone with '
          'the cloud copy for that code. Make sure that\'s what you want.',
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
        const SnackBar(content: Text('Joined and downloaded cloud data.')),
      );
      return;
    }

    // A wrong or unknown code is common enough (typos, expired codes) that
    // it gets a clear dialog with an explicit OK, rather than a snackbar
    // that can be missed.
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync code not found'),
        content: Text(
          result.error ??
              'No store was found for that sync code. Double-check the '
                  'code and try again.',
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
          'This phone will stop syncing with the cloud store. Your other '
          'phones using the same code are not affected, and the cloud '
          'data is not deleted.',
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
    if (confirmed != true) return;
    await widget.store.leaveCloudSync();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('This phone is no longer linked to cloud sync.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const SectionHeading(
              'Pricing',
              subtitle: 'Controls the suggested selling price',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'When you enter a cost price on Add New Product, '
                      'SariScan suggests a selling price automatically '
                      'using this markup. You can still type in your own '
                      'selling price for any product.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.muted,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _markupController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Default markup',
                        suffixText: '%',
                        prefixIcon: const Icon(Icons.percent_rounded),
                        errorText: _markupError,
                      ),
                      onChanged: (_) {
                        setState(() {
                          if (_markupError != null) _markupError = null;
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Example: ${money(100)} cost → suggested selling '
                      'price ${money(100 * (1 + _previewMarkup / 100))}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppTheme.muted,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _savingMarkup ? null : _saveMarkup,
                      icon: _savingMarkup
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_savingMarkup ? 'Saving...' : 'Save markup'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeading(
              'Cloud sync',
              subtitle: 'Keep multiple phones for this store in sync',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.store.isCloudSyncAvailable)
                      const Text(
                        'Cloud sync is not set up for this build yet.',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.muted),
                      )
                    else ...[
                      Text(
                        widget.store.syncCode == null
                            ? 'This phone is not linked to a cloud sync yet. '
                                  'Create a sync code here, then enter that '
                                  'same code on your other phones to keep '
                                  'them all up to date. Product photos stay '
                                  'on the phone that added them — only text '
                                  'data syncs.'
                            : 'This phone is linked with the sync code '
                                  'below. Share it with your other phones '
                                  'for this store.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.muted,
                          height: 1.5,
                        ),
                      ),
                      if (widget.store.syncCode != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.canvas,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  widget.store.syncCode!,
                                  style: const TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Copy sync code',
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: widget.store.syncCode!),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Sync code copied.'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy_rounded, size: 20),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.store.lastSyncedAt == null
                              ? 'Not synced yet.'
                              : 'Last synced '
                                    '${shortDateTime(widget.store.lastSyncedAt!)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.muted,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _syncing ? null : _openSyncSheet,
                        icon: _syncing
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.sync_rounded),
                        label: Text(_syncing ? 'Syncing...' : 'Sync'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (widget.store.isImageSyncAvailable) ...[
              const SizedBox(height: 24),
              const SectionHeading(
                'Photo sync',
                subtitle: 'Upload photos added before photo sync was set up',
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'New product photos upload automatically when you '
                        'save them. If a product still has a photo from '
                        "before photo sync was set up, use this to upload "
                        "it now so it starts following that product to "
                        'other phones too.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.muted,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _backfillingPhotos ? null : _backfillPhotos,
                        icon: _backfillingPhotos
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined),
                        label: Text(
                          _backfillingPhotos
                              ? 'Uploading...'
                              : 'Upload existing photos now',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SectionHeading(
              'Store account',
              subtitle: 'Your registered store details',
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.storefront_outlined),
                    ),
                    title: Text(widget.store.currentUserName ?? 'Store Owner'),
                    subtitle: const Text('Protected by phone security'),
                    trailing: TextButton(
                      onPressed: _changeName,
                      child: const Text('Change'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(
                      widget.store.storageError == null
                          ? Icons.phone_android_rounded
                          : Icons.error_outline_rounded,
                      color: widget.store.storageError == null
                          ? AppTheme.emerald
                          : Theme.of(context).colorScheme.error,
                    ),
                    title: Text(
                      widget.store.storageError == null
                          ? 'Saved on this phone'
                          : 'Phone storage needs attention',
                    ),
                    subtitle: Text(
                      widget.store.storageError ??
                          'Products, customers, sales, and utang work '
                              'offline.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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