import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _manualController = TextEditingController();
  final _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );
  bool _manualEntry = false;
  bool _returningResult = false;

  void _onDetect(BarcodeCapture capture) {
    if (_returningResult) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;
      _returnResult(value);
      return;
    }
  }

  Future<void> _returnResult(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty || _returningResult) return;
    _returningResult = true;
    await HapticFeedback.mediumImpact();
    await _scannerController.stop();
    if (mounted) Navigator.pop(context, normalized);
  }

  @override
  void dispose() {
    _manualController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: const Text('Scan Barcode'),
        actions: [_TorchButton(controller: _scannerController)],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: MobileScanner(
                    controller: _scannerController,
                    tapToFocus: true,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => ColoredBox(
                      color: const Color(0xFF202020),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            error.errorCode ==
                                    MobileScannerErrorCode.permissionDenied
                                ? 'Camera permission was denied. Enable it in your phone settings, or enter the barcode manually.'
                                : 'The camera could not start. You can still enter the barcode manually.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                IgnorePointer(
                  child: Container(
                    width: 290,
                    height: 210,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(0xFF58C764),
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 38,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.68),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text(
                      'Point the camera at a product barcode',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ColoredBox(
            color: colors.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _manualEntry
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _manualController,
                              autofocus: true,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Barcode number',
                              ),
                              onSubmitted: _returnResult,
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            onPressed: () =>
                                _returnResult(_manualController.text),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      )
                    : OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          side: BorderSide(color: colors.primary, width: 2),
                        ),
                        onPressed: () => setState(() => _manualEntry = true),
                        icon: const Icon(Icons.keyboard_alt_outlined),
                        label: const Text(
                          'Enter Manually',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TorchButton extends StatelessWidget {
  const _TorchButton({required this.controller});

  final MobileScannerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, state, _) {
        if (!state.isInitialized || !state.isRunning) {
          return const SizedBox(width: 48);
        }
        return IconButton(
          tooltip: 'Toggle flashlight',
          onPressed: state.torchState == TorchState.unavailable
              ? null
              : controller.toggleTorch,
          icon: Icon(
            state.torchState == TorchState.on
                ? Icons.flash_on_rounded
                : state.torchState == TorchState.unavailable
                ? Icons.no_flash_rounded
                : Icons.flash_off_rounded,
          ),
        );
      },
    );
  }
}
