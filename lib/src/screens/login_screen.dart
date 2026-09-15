import 'package:flutter/material.dart';

import '../services/phone_security_service.dart';
import '../store/app_store.dart';
import '../widgets/design_system.dart';
import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.store,
    required this.phoneSecurity,
  });

  final AppStore store;
  final PhoneSecurityAuthenticator phoneSecurity;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nameError =
        widget.store.validateOwnerName(_nameController.text);

    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _submitting = true;
      _error = null;
    });

    final securityResult =
        await widget.phoneSecurity.authenticate();

    if (!mounted) return;

    if (!securityResult.authenticated) {
      setState(() {
        _submitting = false;
        _error = securityResult.message;
      });
      return;
    }

    final error = await widget.store.openSecureSession(
      _nameController.text,
    );

    if (!mounted) return;

    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  Future<void> _forgotName() async {
    setState(() => _error = null);

    final result =
        await widget.phoneSecurity.authenticate();

    if (!mounted) return;

    if (!result.authenticated) {
      setState(() => _error = result.message);
      return;
    }

    final name =
        widget.store.registeredOwnerName ?? '';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registered Store Name'),
        content: Text(
          name.isEmpty
              ? "Register your Store's name."
              : 'Your store is registered as "$name".',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Got it'),
          ),
        ],
      ),
    );

    if (!mounted || name.isEmpty) return;

    setState(() {
      _nameController.text = name;
    });
  }

  Future<void> _changeName() async {
    setState(() => _error = null);

    final result =
        await widget.phoneSecurity.authenticate();

    if (!mounted) return;

    if (!result.authenticated) {
      setState(() => _error = result.message);
      return;
    }

    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return ChangeNameDialog(
          initialName:
              widget.store.registeredOwnerName ?? '',
        );
      },
    );

    if (!mounted || newName == null) return;

    final error =
        await widget.store.renameOwner(newName);

    if (!mounted) return;

    if (error != null) {
      setState(() => _error = error);
      return;
    }

    setState(() {
      _nameController.text = newName;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Store name updated.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.7),
            radius: 1.2,
            colors: [
              Color.fromARGB(255, 209, 250, 229),
              Color(0xFFF8FAFC),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 32,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 430,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: BrandMark(size: 84),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'SariScan',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Scan. Sell. Track',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Card(
                      color: const Color.fromARGB(198, 255, 255, 255),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Welcome back! ',
                                style: TextStyle(
                                  fontSize: 22.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Let's get your store set up!.",
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller:
                                    _nameController,
                                textCapitalization:
                                    TextCapitalization.words,
                                textInputAction:
                                    TextInputAction.done,
                                onFieldSubmitted: (_) =>
                                    _submitting
                                        ? null
                                        : _submit(),
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Store Name',
                                  hintText:
                                      'Example: Aaron Store',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    size: 20,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null ||
                                            value
                                                .trim()
                                                .isEmpty
                                        ? 'Enter your name.'
                                        : null,
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding:
                                    const EdgeInsets.all(14),
                                decoration:
                                    BoxDecoration(
                                  color: AppTheme.canvas,
                                  borderRadius:
                                      BorderRadius.circular(
                                    14,
                                  ),
                                ),
                                child: const Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.fingerprint,
                                      color:
                                          AppTheme.emerald,
                                      size: 26,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "To secure your access, you will be asked to use your phone's security feature (fingerprint, face scan, PIN, pattern, or password).",
                                        style: TextStyle(
                                          fontSize: 13.75,
                                          height: 1.65,
                                          color:
                                              AppTheme.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_error != null)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    top: 14,
                                  ),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color:
                                          Theme.of(context)
                                              .colorScheme
                                              .error,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: _submitting
                                    ? null
                                    : _submit,
                                icon: _submitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color:
                                              Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.fingerprint,
                                        size: 20,
                                      ),
                                label: Text(
                                  _submitting
                                      ? 'Checking phone security...'
                                      : 'Continue with Phone Security',
                                  textAlign:
                                      TextAlign.center,
                                ),
                              ),
                              if (widget
                                  .store
                                  .hasLocalAccount) ...[
                                const SizedBox(height: 14),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    TextButton(
                                      onPressed: _submitting
                                          ? null
                                          : _forgotName,
                                      child: const Text(
                                        'Forgot name?',
                                      ),
                                    ),
                                    const Text(
                                      '•',
                                      style: TextStyle(
                                        color:
                                            AppTheme.muted,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _submitting
                                          ? null
                                          : _changeName,
                                      child: const Text(
                                        'Change name',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.emerald,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.store.storageError ??
                          'Offline mode: all stored data stays on this phone.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Dedicated dialog widget for changing the store name.
///
/// The TextEditingController belongs to this widget's State,
/// so it stays alive for the entire lifetime of the dialog and
/// is disposed only when the dialog widget itself is disposed.
class ChangeNameDialog extends StatefulWidget {
  const ChangeNameDialog({
    super.key,
    required this.initialName,
  });

  final String initialName;

  @override
  State<ChangeNameDialog> createState() =>
      _ChangeNameDialogState();
}

class _ChangeNameDialogState
    extends State<ChangeNameDialog> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(
      text: widget.initialName,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _cancel() {
    Navigator.of(context).pop();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final newName = _controller.text.trim();

    Navigator.of(context).pop(newName);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Change store name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          textCapitalization:
              TextCapitalization.words,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'New store name',
          ),
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Enter a store name.';
            }

            return null;
          },
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _cancel,
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}