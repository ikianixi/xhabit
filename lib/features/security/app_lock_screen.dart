import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../core/theme/app_tokens.dart';
import '../../l10n/app_localizations.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({required this.onUnlocked, super.key});

  final VoidCallback onUnlocked;

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  static const _storage = FlutterSecureStorage();
  final _auth = LocalAuthentication();
  String _entry = '';
  String? _error;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _tryBiometric();
  }

  Future<void> _tryBiometric() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      if (!canCheck && !isSupported) return;
      final reason =
          mounted ? AppLocalizations.of(context).unlockWithBiometric : 'XHabit';
      final ok = await _auth.authenticate(
        localizedReason: reason,
        persistAcrossBackgrounding: true,
      );
      if (ok && mounted) widget.onUnlocked();
    } catch (_) {
      // Fallback silently to 4-digit PIN pad
    }
  }

  Future<void> _pressDigit(String key) async {
    if (_verifying) return;
    if (key == 'back') {
      if (_entry.isNotEmpty) {
        setState(() {
          _entry = _entry.substring(0, _entry.length - 1);
          _error = null;
        });
      }
      return;
    }
    if (_entry.length >= 4) return;
    final nextEntry = '$_entry$key';
    setState(() {
      _entry = nextEntry;
      _error = null;
    });
    if (nextEntry.length == 4) {
      _verifying = true;
      try {
        final saved = await _storage.read(key: 'xhabit_pin');
        if (saved != null && saved.isNotEmpty && nextEntry == saved) {
          if (mounted) widget.onUnlocked();
        } else if (mounted) {
          setState(() {
            _error = AppLocalizations.of(context).wrongPasscode;
            _entry = '';
          });
        }
      } catch (_) {
        if (mounted) {
          setState(() {
            _error = AppLocalizations.of(context).wrongPasscode;
            _entry = '';
          });
        }
      } finally {
        _verifying = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final xc = context.xc;
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', 'bio', '0', 'back'];

    return Scaffold(
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 40).clamp(0, double.infinity),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 260),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                Icon(Icons.lock_outline_rounded, size: 32, color: xc.lime),
                const SizedBox(height: 10),
                Text(
                  l10n.enterPasscode,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: xc.text,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style:
                        const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                  ),
                ],
                const SizedBox(height: 16),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = _entry.length > i;
                      return Container(
                        width: 13,
                        height: 13,
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? xc.lime : Colors.transparent,
                          border: Border.all(
                            color: filled ? xc.lime : xc.borderStrong,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 20),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.5,
                    physics: const NeverScrollableScrollPhysics(),
                    children: keys.map((k) {
                      return GestureDetector(
                        onTap: () {
                          if (k == 'bio') {
                            _tryBiometric();
                          } else {
                            _pressDigit(k);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: xc.card2,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: xc.border),
                          ),
                          alignment: Alignment.center,
                          child: k == 'bio'
                              ? Icon(Icons.fingerprint_rounded,
                                  size: 20, color: xc.lime)
                              : k == 'back'
                                  ? Icon(Icons.backspace_outlined,
                                      size: 18, color: xc.text)
                                  : Text(
                                      k,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: xc.text,
                                      ),
                                    ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
