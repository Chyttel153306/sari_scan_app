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
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -.7),
            radius: 1.2,
            colors: [Color(0xFFD1FAE5), Color(0xFFF8FAFC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: BrandMark(size: 84)),
                    const SizedBox(height: 24),
                    Text(
                      'SariScan',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      "Your Store's Best Friend",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 34),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Welcome to your store',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.4,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'A secure start to a better business day.',
                                style: TextStyle(
                                  color: AppTheme.muted,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 24),
                              TextFormField(
                                controller: _nameController,
                                textCapitalization: TextCapitalization.words,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.name],
                                onFieldSubmitted: (_) =>
                                    _submitting ? null : _submit(),
                                decoration: const InputDecoration(
                                  labelText: 'Your Name',
                                  hintText: 'e.g., Maria Santos',
                                  prefixIcon: Icon(
                                    Icons.person_outline,
                                    size: 20,
                                  ),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'Enter your name.'
                                    : null,
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppTheme.canvas,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.fingerprint,
                                      color: AppTheme.emerald,
                                      size: 26,
                                    ),
                                    SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        "To secure your access, you will be asked to use your phone's security feature (fingerprint, face scan, PIN, pattern, or password).",
                                        style: TextStyle(
                                          fontSize: 11,
                                          height: 1.65,
                                          color: AppTheme.muted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 14),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 22),
                              FilledButton.icon(
                                onPressed: _submitting ? null : _submit,
                                icon: _submitting
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.fingerprint, size: 20),
                                label: Text(
                                  _submitting
                                      ? 'Checking phone security...'
                                      : 'Continue with Phone Security',
                                  textAlign: TextAlign.center,
                                ),
                              ),
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
                          'Offline mode: all store data stays on this phone.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
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
