import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants/asset_paths.dart';
import '../services/auth_service.dart';

class OTPScreen extends StatefulWidget {
  final String? verificationId;
  final ConfirmationResult? confirmationResult;
  final String? phoneNumber;
  final int? resendToken;

  const OTPScreen({
    super.key,
    this.verificationId,
    this.confirmationResult,
    this.phoneNumber,
    this.resendToken,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final TextEditingController _otpController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _errorText;
  int _resendCountdown = 60;
  Timer? _resendTimer;
  bool _autoSubmitting = false;
  late String _verificationId;

  /// The latest Firebase resend token from `codeSent`. Forwarded to
  /// [AuthService.verifyPhoneNumber] as `forceResendingToken` so a resend
  /// continues the existing verification session instead of silently opening
  /// a fresh one (which would reject the original OTP).
  int? _resendToken;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId ?? '';
    _resendToken = widget.resendToken;
    _startResendTimer();
    _otpController.addListener(_onOtpChanged);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _otpController.removeListener(_onOtpChanged);
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCountdown = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) {
          timer.cancel();
        }
      });
    });
  }

  void _onOtpChanged() {
    final code = _otpController.text.trim();
    if (code.length == 6 && !_isLoading && !_autoSubmitting) {
      _verifyOTP();
    }
  }

  String _friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-verification-code':
          return 'The OTP entered is incorrect. Please try again.';
        case 'session-expired':
          return 'The verification session has expired. Please request a new code.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        default:
          return e.message ?? 'Verification failed. Please try again.';
      }
    }
    return 'An unexpected error occurred. Please try again.';
  }

  Future<void> _verifyOTP() async {
    final code = _otpController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'Please enter the OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _autoSubmitting = true;
      _errorText = null;
    });

    try {
      if (widget.confirmationResult != null) {
        await widget.confirmationResult!.confirm(code);
      } else {
        await _authService.signInWithOTP(
          verificationId: _verificationId,
          smsCode: code,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _autoSubmitting = false;
          _errorText = _friendlyError(e);
        });
      }
      return;
    }
    if (mounted) setState(() => _isLoading = false);
    // Sign-in succeeded. The login + OTP screens were pushed on top of the
    // AuthGate host route, so pop everything down to the first route to reveal
    // the post-login UI rather than leaving the customer stranded here.
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _resendOTP() async {
    if (widget.phoneNumber == null) return;

    setState(() {
      _errorText = null;
    });

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: widget.phoneNumber!,
        resendToken: _resendToken,
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (!mounted) return;
          try {
            await _authService.signInWithPhoneCredential(credential);
            if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Auto sign-in failed: $e')),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          if (mounted) {
            setState(() => _errorText = _friendlyError(e));
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken ?? _resendToken;
            _errorText = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('A new OTP has been sent.')),
          );
          _otpController.clear();
          _startResendTimer();
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = 'Failed to resend OTP. Please try again.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  AssetPaths.appLogo,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter the 6-digit code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.phoneNumber != null
                    ? 'Sent to ${widget.phoneNumber}'
                    : 'Sent to your mobile number',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                decoration: const InputDecoration(
                  labelText: 'OTP',
                  hintText: '------',
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _verifyOTP,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Verify OTP'),
                    ),
              const SizedBox(height: 16),
              Center(
                child: _resendCountdown > 0
                    ? Text(
                        'Resend OTP in ${_resendCountdown}s',
                        style: const TextStyle(color: Colors.grey),
                      )
                    : TextButton(
                        onPressed: _resendOTP,
                        child: const Text('Resend OTP'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
