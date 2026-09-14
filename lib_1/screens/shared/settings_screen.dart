import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/storage.dart';
import '../../../core/sign.dart';
import '../../../core/platform_gate.dart';
import '../../../core/constants.dart';
import '../../../core/app_routes.dart';
import '../../../l10n/strings.dart';
import '../language_selection_screen.dart';
import '../owner/profile_tabs/AdvancedSecurity.dart';
import '../../../services/api_service.dart';
import '../../../services/auth/firebase_phone_service.dart';

class SettingsScreen extends StatefulWidget {
  final VoidCallback onBack;
  const SettingsScreen({super.key, required this.onBack});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 🏛️ Use constants instead of hardcoded URL
  final String apiBase = StarlightConstants.apiBaseUrl;

  bool cloudSync = true;
  bool pushNotif = true;
  bool darkMode = false;
  bool autoBackup = true;
  bool secondaryVerification = false;
  String _languageName = 'English';

  Map<String, dynamic> identity = {
    'phone': 'Not Linked',
    'recovery_email': 'Not Set',
    'storage_used': 128
  };

  @override
  void initState() {
    super.initState();
    _loadStoredSettings();
  }

  Future<void> _loadStoredSettings() async {
    try {
setState(() {
          identity['phone'] = 'Loading...';
          identity['recovery_email'] = 'Loading...';
          identity['storage_used'] = 128; // Mock storage usage

          // Load preference settings
          cloudSync = true; // Default to true
          pushNotif = true; // Default to true
          darkMode = false; // Default to false
          autoBackup = true; // Default to true
        });

        final lang = await StarlightStorage.getSelectedLanguage();
        setState(() {
          _languageName = lang == 'ur' ? 'اردو' : 'English';
        });

      // 1. Fetch phone verification status from backend
      try {
        final phoneRes = await ApiService.get('/firebase/check-verification');
        if (phoneRes['phone_verified'] == true) {
          final verifiedPhone = phoneRes['verified_phone_number'];
          if (verifiedPhone != null) {
            setState(() {
              identity['phone'] = verifiedPhone;
            });
            await StarlightStorage.setUserPhoneNumber(verifiedPhone);
            await StarlightStorage.setVerifiedPhone(verifiedPhone);
          }
        } else {
          setState(() {
            identity['phone'] = 'Not Linked';
          });
          await StarlightStorage.setUserPhoneNumber("");
          await StarlightStorage.setVerifiedPhone("");
        }
      } catch (_) {
        final cachedPhone = await StarlightStorage.getUserPhoneNumber();
        setState(() {
          identity['phone'] = cachedPhone ?? 'Not Linked';
        });
      }

      // 2. Fetch freshest profile from backend
      try {
        final profileRes = await ApiService.get('/profile/identity');
        if (profileRes['has_identity'] == true) {
          final email = profileRes['email'] ?? '';
          setState(() {
            identity['recovery_email'] = email.isNotEmpty ? email : 'Not Set';
            secondaryVerification = profileRes['secondary_verification'] ?? false;
          });
          if (email.isNotEmpty) await StarlightStorage.setUserEmail(email);
        } else {
          final cachedEmail = await StarlightStorage.getUserEmail();
          final dashboardData = await StarlightStorage.getDashboardStats();
          setState(() {
            identity['recovery_email'] = cachedEmail ?? dashboardData?['email'] ?? 'Not Set';
          });
        }
      } catch (_) {
        final cachedEmail = await StarlightStorage.getUserEmail();
        final dashboardData = await StarlightStorage.getDashboardStats();
        setState(() {
          identity['recovery_email'] = cachedEmail ?? dashboardData?['email'] ?? 'Not Set';
        });
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
      final phone = await StarlightStorage.getUserPhoneNumber();
      final cachedEmail = await StarlightStorage.getUserEmail();
      final dashboardData = await StarlightStorage.getDashboardStats();
      setState(() {
        identity['phone'] = phone ?? 'Not Linked';
        identity['recovery_email'] = cachedEmail ?? dashboardData?['email'] ?? 'Not Set';
      });
    }
  }

  Future<void> _toggleSetting(String key, bool value) async {
    setState(() {
      if (key == 'cloudSync') cloudSync = value;
      if (key == 'pushNotif') pushNotif = value;
      if (key == 'darkMode') darkMode = value;
    });

    StarlightUtils.showSuccessBox(context, tr('preferenceSynced'));
  }

  Future<void> _verifyPhoneNumber() async {
    final TextEditingController phoneCtrl = TextEditingController();
    final TextEditingController codeCtrl = TextEditingController();
    bool isOTPSent = false;
    bool isVerifying = false;
    String errorMessage = "";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.phone_iphone_rounded, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text(
                    isOTPSent ? tr('enterOtpCode') : tr('verifyPhoneTitle'),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isOTPSent
                        ? tr('smsVerificationSent', {'phone': phoneCtrl.text.trim()})
                        : tr('enterPakistanPhone'),
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  if (!isOTPSent)
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: tr('phoneNumber'),
                        labelStyle: const TextStyle(color: Colors.white38),
                        prefixText: "+92 ",
                        prefixStyle: TextStyle(color: Colors.white70, fontSize: 13),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                      ),
                    )
                  else
                    TextField(
                      controller: codeCtrl,
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                            if (!isOTPSent) {
                              final num = phoneCtrl.text.trim();
                              if (num.length != 10) {
                                throw Exception(tr('invalidPakistaniPhone'));
                              }
                              final formatted = "+92$num";
                              await FirebasePhoneService.initialize();
                              final sent = await FirebasePhoneService.sendOTPToPakistan(formatted);
                              if (sent) {
                                setDialogState(() {
                                  isOTPSent = true;
                                });
                              } else {
                                throw Exception(tr('failedSendOtp'));
                              }
                            } else {
                              final otp = codeCtrl.text.trim();
                              if (otp.length != 6) {
                                throw Exception(tr('enterFullOtp'));
                              }
                              final verified = await FirebasePhoneService.verifyOTP(otp);
                              if (verified) {
                                final formatted = "+92${phoneCtrl.text.trim()}";
                                // Sync/verify with server
                                await ApiService.post('/firebase/verify-phone', {'phone_number': formatted});

                                // Save locally
                                await StarlightStorage.setUserPhoneNumber(formatted);
                                await StarlightStorage.setVerifiedPhone(formatted);
                                await StarlightStorage.setPhoneVerified(true);
                                await StarlightStorage.setChatVerified(true);

                                if (mounted) {
                                  setState(() {
                                    identity['phone'] = formatted;
                                  });
                                  StarlightUtils.showSuccessBox(context, tr('phoneVerifiedSuccess'));
                                }
                                Navigator.pop(context);
                              } else {
                                throw Exception(tr('invalidOtp'));
                              }
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorMessage = e.toString().replaceAll("Exception: ", "");
                            });
                          } finally {
                            setDialogState(() {
                              isVerifying = false;
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                      : Text(
                          isOTPSent ? tr('verifyCode') : tr('sendOtp'),
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

  Future<void> _verifyEmail() async {
    final TextEditingController emailCtrl = TextEditingController();
    final TextEditingController codeCtrl = TextEditingController();
    bool isOTPSent = false;
    bool isVerifying = false;
    String errorMessage = "";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF0F172A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.mark_email_read_rounded, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 8),
                  Text(
                    isOTPSent ? tr('enterVerificationOtp') : tr('verifyEmailTitle'),
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isOTPSent
                        ? tr('emailCodeSent', {'email': emailCtrl.text.trim()})
                        : tr('enterEmailOtp'),
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  if (!isOTPSent)
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: tr('email'),
                        labelStyle: const TextStyle(color: Colors.white38),
                        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF38BDF8))),
                      ),
                    )
                  else
                    TextField(
                      controller: codeCtrl,
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                            final targetEmail = emailCtrl.text.trim();
                            if (!isOTPSent) {
                              if (targetEmail.isEmpty || !targetEmail.contains("@")) {
                                throw Exception(tr('invalidEmail'));
                              }
                              await ApiService.post('/profile/verify-email/send-otp', {'email': targetEmail});
                              setDialogState(() {
                                isOTPSent = true;
                              });
                            } else {
                              final otp = codeCtrl.text.trim();
                              if (otp.length != 6) {
                                throw Exception(tr('enterFullOtp'));
                              }
                              await ApiService.post('/profile/verify-email/verify-otp', {
                                'email': targetEmail,
                                'otp': otp,
                              });

                              if (mounted) {
                                setState(() {
                                  identity['recovery_email'] = targetEmail;
                                });
                                StarlightUtils.showSuccessBox(context, tr('emailVerifiedSuccess'));
                              }
                              Navigator.pop(context);
                            }
                          } catch (e) {
                            setDialogState(() {
                              errorMessage = e.toString().replaceAll("Exception: ", "");
                            });
                          } finally {
                            setDialogState(() {
                              isVerifying = false;
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                      : Text(
                          isOTPSent ? tr('verifyCode') : tr('sendOtp'),
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

  Future<void> _handleSecondaryVerificationToggle(bool value) async {
    final bool isPhoneSet = identity['phone'] != null && 
                            identity['phone'] != 'Not Linked' && 
                            identity['phone'] != 'Loading...' && 
                            identity['phone'].toString().trim().isNotEmpty;

    if (value && !isPhoneSet) {
      StarlightUtils.showErrorBox(context, tr('verifyPhoneFirst'));
      return;
    }

    final String targetPhone = identity['phone'];
    final TextEditingController otpCtrl = TextEditingController();
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
              title: Row(
                children: [
                  const Icon(Icons.shield_rounded, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    value ? tr('enableMfa') : tr('disableMfa'),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    isOTPSent
                        ? tr('verifyOtpAuthorize', {'phone': '$targetPhone'})
                        : tr(value ? 'mfaEnableMsg' : 'mfaDisableMsg', {'phone': '$targetPhone'}),
                    style: const TextStyle(color: Colors.white60, fontSize: 11),
                  ),
                  const SizedBox(height: 16),
                  if (isOTPSent)
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
                  onPressed: () => Navigator.pop(context),
                  child: Text(tr('cancel'), style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                            if (!isOTPSent) {
                              await FirebasePhoneService.initialize();
                              await FirebaseAuth.instance.verifyPhoneNumber(
                                phoneNumber: targetPhone,
                                verificationCompleted: (PhoneAuthCredential credential) async {
                                  await FirebaseAuth.instance.signInWithCredential(credential);
                                  setDialogState(() {
                                    isOTPSent = true;
                                    isVerifying = false;
                                  });
                                },
                                verificationFailed: (FirebaseAuthException e) {
                                  setDialogState(() {
                                    errorMessage = e.message ?? tr('firebaseSmsFailed');
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
                                throw Exception(tr('enterFullVerificationCode'));
                              }
                              final credential = PhoneAuthProvider.credential(
                                verificationId: verificationId,
                                smsCode: otpCode,
                              );
                              await FirebaseAuth.instance.signInWithCredential(credential);

                              // Verified! Call toggle endpoint
                              final String deviceId = await PlatformGate.getDeviceId();
                              final toggleRes = await ApiService.post(
                                '/profile/secondary-verification/toggle',
                                {
                                  'enabled': value,
                                  'device_id': deviceId,
                                },
                              );

                              if (mounted) {
                                setState(() {
                                  secondaryVerification = toggleRes['secondary_verification'] ?? value;
                                });
                                StarlightUtils.showSuccessBox(
                                  context,
                                  tr(value ? 'mfaEnabledSuccess' : 'mfaDisabledSuccess'),
                                );
                              }
                              Navigator.pop(context);
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
                          isOTPSent ? tr('verifyCode') : tr('sendOtp'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF263238)),
          onPressed: widget.onBack,
        ),
        title: Text(tr('settingsTitle'),
            style: const TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
        backgroundColor: Colors.white,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildGeneralSection(),
            const SizedBox(height: 20),
            _buildAccountSection(),
            const SizedBox(height: 20),
            _buildPreferencesSection(),
            const SizedBox(height: 20),
            _buildAISection(),
            const SizedBox(height: 20),
            _buildAdvancedSection(),
          ],
        ),
      ),
    );
  }

  Future<void> _openLanguagePicker() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LanguageSelectionScreen(fromSettings: true)),
    );
    if (!mounted) return;
    final lang = await StarlightStorage.getSelectedLanguage();
    setState(() => _languageName = lang == 'ur' ? 'اردو' : 'English');
  }

  Widget _buildGeneralSection() {
    return _sectionWrapper(
      title: tr('general'),
      children: [
        _infoTile(
          tr('languageLbl'),
          _languageName,
          Icons.translate_rounded,
          onTap: _openLanguagePicker,
          buttonText: tr('change'),
        ),
      ],
    );
  }

  Widget _buildAccountSection() {
    final bool isPhoneSet = identity['phone'] != null && 
                            identity['phone'] != 'Not Linked' && 
                            identity['phone'] != 'Loading...' && 
                            identity['phone'].toString().trim().isNotEmpty;
                            
    final bool isEmailSet = identity['recovery_email'] != null && 
                            identity['recovery_email'] != 'Not Set' && 
                            identity['recovery_email'] != 'Loading...' && 
                            identity['recovery_email'].toString().trim().isNotEmpty;

    return _sectionWrapper(
      title: tr('accountVerification'),
      children: [
        _infoTile(
          tr('phoneNumber'),
          isPhoneSet ? identity['phone'] : tr('notLinked'),
          Icons.phone_android_rounded,
          onTap: _verifyPhoneNumber,
          buttonText: isPhoneSet ? tr('changePhone') : tr('addPhone'),
        ),
        _infoTile(
          tr('email'),
          isEmailSet ? identity['recovery_email'] : tr('notSet'),
          Icons.mark_email_read_rounded,
          onTap: _verifyEmail,
          buttonText: isEmailSet ? tr('changeEmail') : tr('addEmail'),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: LinearProgressIndicator(
            value: 0.4,
            backgroundColor: Colors.grey.shade200,
            color: Colors.blue,
            minHeight: 6,
          ),
        ),
        Text(tr('vaultStorage', {'used': '${identity['storage_used']}'}),
            style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPreferencesSection() {
    return _sectionWrapper(
      title: tr('appPreferences'),
      children: [
        _switchTile(tr('cloudSyncLbl'), tr('cloudSyncSub'), cloudSync, (v) => _toggleSetting('cloudSync', v)),
        _switchTile(tr('pushNotifLbl'), tr('pushNotifSub'), pushNotif, (v) => _toggleSetting('pushNotif', v)),
        _switchTile(tr('darkModeLbl'), tr('darkModeSub'), darkMode, (v) => _toggleSetting('darkMode', v)),
        _switchTile(tr('secondaryVerificationLbl'), tr('secondaryVerificationSub'), secondaryVerification, _handleSecondaryVerificationToggle),
      ],
    );
  }

  Widget _buildAISection() {
    return InkWell(
      onTap: () {
        Navigator.pushNamed(context, AppRoutes.aiPackages);
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2332),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.purple.withOpacity(0.3),
                    Colors.blue.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.psychology, color: Colors.purple, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('aiPackagesTitle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(tr('aiPackagesSub'), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSection() {
    return InkWell(
      onTap: () {
        // 🏛️ Navigation to Advanced Security
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AdvancedSecurityScreen(
              onClose: () => Navigator.pop(context),
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF263238),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_rounded, color: Colors.amber, size: 28),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('advancedSecurityTitle'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(tr('advancedSecuritySub'), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: Colors.white.withOpacity(0.3), size: 16),
          ],
        ),
      ),
    );
  }

  Widget _sectionWrapper({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black26, letterSpacing: 1)),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, {VoidCallback? onTap, String buttonText = "EDIT"}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (onTap != null)
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(buttonText, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w900, fontSize: 10)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _switchTile(String title, String sub, bool value, Function(bool) onChanged) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeColor: Colors.blue,
      title: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      subtitle: Text(sub, style: const TextStyle(fontSize: 11, color: Colors.grey)),
    );
  }
}