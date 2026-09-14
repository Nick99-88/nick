import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/platform_gate.dart';
import '../../core/storage.dart';
import '../../core/utils.dart';
import '../api_service.dart';
import 'firebase_phone_service.dart';

/// Runs the MFA secondary-verification challenge (SMS OTP to the registered
/// phone number). On success, [onCompleted] is called with the finalized
/// handshake returned by /auth/secondary-verification/finalize.
Future<void> launchSecondaryVerificationChallenge(
  BuildContext context, {
  required String phoneHint,
  required String userId,
  required Future<void> Function(Map<String, dynamic> handshake) onCompleted,
  VoidCallback? onCancel,
}) async {
  final TextEditingController otpCtrl = TextEditingController();
  final TextEditingController confirmPhoneCtrl = TextEditingController();
  bool isOTPSent = false;
  bool isVerifying = false;
  String errorMessage = "";
  String verificationId = "";

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.shield_rounded, color: Colors.orange, size: 24),
                SizedBox(width: 8),
                Text(
                  "MFA VERIFICATION",
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isOTPSent
                      ? "Verify OTP sent to your registered phone ending in $phoneHint."
                      : "Secondary Verification is active. We need to verify your identity by sending an SMS OTP to your registered phone ending in $phoneHint.",
                  style: const TextStyle(color: Colors.white60, fontSize: 11),
                ),
                const SizedBox(height: 16),
                if (!isOTPSent) ...[
                  TextField(
                    controller: confirmPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: "Confirm Complete Phone Number",
                      labelStyle: TextStyle(color: Colors.white38),
                      prefixText: "+92 ",
                      prefixStyle: TextStyle(color: Colors.white70, fontSize: 13),
                      counterText: "",
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                    ),
                  ),
                ] else ...[
                  TextField(
                    controller: otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 8, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: "000000",
                      hintStyle: TextStyle(color: Colors.white24),
                      counterText: "",
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                    ),
                  ),
                ],
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  onCancel?.call();
                },
                child: const Text("Cancel", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF38BDF8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isVerifying
                    ? null
                    : () async {
                        setDialogState(() {
                          isVerifying = true;
                          errorMessage = "";
                        });

                        try {
                          final num = confirmPhoneCtrl.text.trim();
                          if (num.length != 10) {
                            throw Exception("Please enter a valid 10-digit phone number");
                          }
                          final completePhone = "+92$num";
                          final lastThreeDigits = phoneHint.replaceAll(".", "").trim();
                          if (!completePhone.endsWith(lastThreeDigits)) {
                            throw Exception("Phone number mismatch. Please enter the complete registered phone ending in $lastThreeDigits.");
                          }

                          if (!isOTPSent) {
                            await FirebasePhoneService.initialize();
                            await FirebaseAuth.instance.verifyPhoneNumber(
                              phoneNumber: completePhone,
                              verificationCompleted: (PhoneAuthCredential credential) async {
                                await FirebaseAuth.instance.signInWithCredential(credential);
                                setDialogState(() {
                                  isOTPSent = true;
                                  isVerifying = false;
                                });
                              },
                              verificationFailed: (FirebaseAuthException e) {
                                setDialogState(() {
                                  errorMessage = e.message ?? "Firebase SMS dispatch failed";
                                  isVerifying = false;
                                });
                              },
                              codeSent: (String vid, int? resendToken) {
                                verificationId = vid;
                                setDialogState(() {
                                  isOTPSent = true;
                                  isVerifying = false;
                                });
                              },
                              codeAutoRetrievalTimeout: (String vid) {
                                verificationId = vid;
                              },
                            );
                          } else {
                            final otpCode = otpCtrl.text.trim();
                            if (otpCode.length != 6) {
                              throw Exception("Enter full 6-digit verification code");
                            }
                            final credential = PhoneAuthProvider.credential(
                              verificationId: verificationId,
                              smsCode: otpCode,
                            );
                            await FirebaseAuth.instance.signInWithCredential(credential);

                            final activeAppId = await StarlightStorage.getAppId() ?? "starlight";
                            final String deviceId = await PlatformGate.getDeviceId();
                            final String deviceName = await PlatformGate.getDeviceName();

                            final finalizedHandshake = await ApiService.post(
                              '/auth/secondary-verification/finalize',
                              {
                                'user_id': userId,
                                'device_id': deviceId,
                                'device_name': deviceName,
                                'app_id': activeAppId,
                                'phone_number': completePhone,
                              },
                              requireAuth: false,
                            );

                            Navigator.pop(context); // Close OTP Dialog
                            await onCompleted(finalizedHandshake);
                          }
                        } catch (e) {
                          setDialogState(() {
                            errorMessage = e.toString().replaceAll("Exception: ", "");
                            isVerifying = false;
                          });
                        }
                      },
                child: isVerifying
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                    : Text(
                        isOTPSent ? "Verify Code" : "Send OTP",
                        style: const TextStyle(color: Colors.black87, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          );
        },
      );
    },
  );
}
