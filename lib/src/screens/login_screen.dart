import 'package:flutter/material.dart';

import '../services/phone_security_service.dart';
import '../store/app_store.dart';

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
    final nameError = widget.store.validateOwnerName(_nameController.text);
    if (nameError != null) {
      setState(() => _error = nameError);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final securityResult = await widget.phoneSecurity.authenticate();
    if (!mounted) return;
    if (!securityResult.authenticated) {
      setState(() {
        _submitting = false;
        _error = securityResult.message;
      });
      return;
    }

    final error = await widget.store.openSecureSession(_nameController.text);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF0FAF2), Color(0xFFF8FCF7)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF2E8B3A),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.16),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.storefront_outlined,
                          color: Colors.white,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SariScan',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
                          ),
                    ),
                    Text(
                      "Your Store's Best Friend",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 38),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(height: 4, color: colors.primary),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(22, 16, 22, 24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  TextFormField(
                                    controller: _nameController,
                                    autofocus: true,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [AutofillHints.name],
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: const InputDecoration(
                                      labelText: 'Your Name',
                                      hintText: 'e.g., Maria Santos',
                                      prefixIcon: Icon(Icons.person_outline),
                                    ),
                                    validator: (value) =>
                                        value == null || value.trim().isEmpty
                                        ? 'Enter your name.'
                                        : null,
                                  ),
                                  const SizedBox(height: 22),
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FBF8),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          Icons.fingerprint_rounded,
                                          color: colors.primary,
                                          size: 28,
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'To secure your access, you will be '
                                            "asked to use your phone's security "
                                            'feature (fingerprint, face scan, PIN, '
                                            'pattern, or password).',
                                            style: TextStyle(height: 1.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 14),
                                    Text(
                                      _error!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 22),
                                  FilledButton.icon(
                                    onPressed: _submitting ? null : _submit,
                                    icon: _submitting
                                        ? const SizedBox.square(
                                            dimension: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.fingerprint_rounded),
                                    label: Text(
                                      _submitting
                                          ? 'Checking phone security...'
                                          : 'Continue with Phone Security',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    Text(
                      widget.store.storageError ??
                          'Offline mode: all store data stays on this phone.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
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
