import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:password_strength/password_strength.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/storage.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/api_service.dart';
import '../../services/auth/firebase_phone_service.dart';
import '../../services/auth/auth_service.dart';
import '../../core/platform_gate.dart';
import '../../core/router_gateway.dart';
import '../../core/identity_controller.dart';
import 'otp_screen.dart';
import '../../l10n/strings.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Tabs
  String _activeTab = "EMAIL"; // "EMAIL" or "PHONE"

  // Email controllers
  final _fNameController = TextEditingController();
  final _lNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();

  // Phone controllers
  final _phoneController = TextEditingController();
  final _phoneNameController = TextEditingController();
  final _phonePassController = TextEditingController();
  final _phoneConfirmPassController = TextEditingController();
  final _phoneOtpController = TextEditingController();

  final AuthService _authService = AuthService();

  double _strength = 0;
  bool _isObscure = true;
  bool _isLoading = false;

  bool _isPhoneOtpSent = false;
  String _verificationId = "";

  @override
  void dispose() {
    _fNameController.dispose();
    _lNameController.dispose();
    _emailController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    
    _phoneController.dispose();
    _phoneNameController.dispose();
    _phonePassController.dispose();
    _phoneConfirmPassController.dispose();
    _phoneOtpController.dispose();
    super.dispose();
  }

  void _checkPassword(String value) {
    setState(() {
      _strength = estimatePasswordStrength(value);
    });
  }

  Future<void> _handleEmailSignup() async {
    if (_fNameController.text.isEmpty || _lNameController.text.isEmpty) {
      StarlightUtils.showErrorBox(context, tr('fullNameRequiredDot'));
      return;
    }

    if (_emailController.text.isEmpty || !_emailController.text.contains('@')) {
      StarlightUtils.showErrorBox(context, tr('validInstitutionEmailRequired'));
      return;
    }

    if (_passController.text != _confirmPassController.text) {
      StarlightUtils.showErrorBox(context, tr('passwordsDoNotMatchExcl'));
      return;
    }

    if (_strength < 0.4) {
      StarlightUtils.showErrorBox(context, tr('passwordTooWeak'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final deviceId = await PlatformGate.getDeviceId();
      final activeAppId = await StarlightStorage.getAppId();

      if (activeAppId == null || activeAppId.isEmpty) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, tr('hardwareContextMissing'));
        return;
      }

      final result = await _authService.signup(
        name: "${_fNameController.text} ${_lNameController.text}",
        email: _emailController.text.trim(),
        password: _passController.text,
        appId: activeAppId,
        deviceId: deviceId,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, result['message'] ?? tr('otpIssued'));

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OTPScreen(
              email: _emailController.text.trim(),
              action: "signup_verification",
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handlePhoneSignupOTP() async {
    final phone = _phoneController.text.trim();
    final name = _phoneNameController.text.trim();
    final password = _phonePassController.text;
    final confirmPass = _phoneConfirmPassController.text;

    if (phone.length != 10) {
      StarlightUtils.showErrorBox(context, tr('enterValidTenDigit'));
      return;
    }
    if (name.isEmpty) {
      StarlightUtils.showErrorBox(context, tr('fullNameRequired'));
      return;
    }
    if (password.isEmpty || password.length < 6) {
      StarlightUtils.showErrorBox(context, tr('passwordMin'));
      return;
    }
    if (password != confirmPass) {
      StarlightUtils.showErrorBox(context, tr('passwordsDoNotMatch'));
      return;
    }
    if (_strength < 0.4) {
      StarlightUtils.showErrorBox(context, tr('passwordTooWeak'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formatted = "+92$phone";
      // 1. Check if phone exists
      final checkRes = await ApiService.post('/auth/phone-check', {'phone_number': formatted}, requireAuth: false);
      final bool exists = checkRes['exists'] ?? false;

      if (exists) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, tr('accountExistsPhone'));
        return;
      }

      // 2. Trigger Firebase SMS OTP
      await FirebasePhoneService.initialize();
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formatted,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
          setState(() {
            _isPhoneOtpSent = true;
            _isLoading = false;
          });
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          StarlightUtils.showErrorBox(context, e.message ?? tr('firebaseSmsDispatchFailed'));
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _isPhoneOtpSent = true;
            _isLoading = false;
          });
          StarlightUtils.showSuccessBox(context, tr('smsOtpSentSuccess'));
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  Future<void> _handlePhoneVerifyAndRegister() async {
    final otp = _phoneOtpController.text.trim();
    final phone = _phoneController.text.trim();
    final formatted = "+92$phone";
    final name = _phoneNameController.text.trim();
    final password = _phonePassController.text;

    if (otp.length != 6) {
      StarlightUtils.showErrorBox(context, tr('fullSixDigitSmsOtp'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verify OTP with Firebase
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otp,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);

      // 2. Register on server
      final activeAppId = await StarlightStorage.getAppId() ?? "starlight";
      final deviceId = await PlatformGate.getDeviceId();

      final loginData = await ApiService.post('/auth/phone-signup', {
        'phone_number': formatted,
        'name': name,
        'password': password,
        'app_id': activeAppId,
        'device_id': deviceId,
      }, requireAuth: false);

      // Save locally
      await StarlightStorage.setUserPhoneNumber(formatted);
      await StarlightStorage.setVerifiedPhone(formatted);
      await StarlightStorage.setPhoneVerified(true);
      await StarlightStorage.setChatVerified(true);

      // Perform Handshake Finalization
      final String token = loginData['access_token'];
      final String role = loginData['role'] ?? 'user';
      final bool hasIdentity = loginData['identity'] ?? false;
      final bool isProfileComplete = loginData['data_identifier'] ?? false;
      final String roleId = loginData['role_id']?.toString() ?? "0";
      final String? instToken = loginData['institution_id']?.toString();
      final String otkSeed = loginData['otk'] ?? "";
      final Map<String, dynamic> userData = loginData['user_data'] ?? {};

      await _authService.finalizeLink(token: token, deviceId: deviceId, seed: otkSeed);

      await StarlightStorage.saveUserSession(token, roleId);
      await StarlightStorage.setUserRole(role);
      await StarlightStorage.setIdentity(hasIdentity);
      if (isProfileComplete) {
        await StarlightStorage.setIdentityVerifyToken("IDENTITY_LOCKED");
      } else {
        await StarlightStorage.setIdentityVerifyToken("");
      }
      if (instToken != null && instToken.isNotEmpty) {
        await StarlightStorage.setInstitutionalToken(instToken);
        if (role == 'owner') {
          await StarlightStorage.setOwnerVerifyToken("OWNERSHIP_VERIFIED");
        }
      }

      if (userData.isNotEmpty) {
        await IdentityController.setFullIdentity(userData);
      }

      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showSuccessBox(context, tr('phoneRegistrationComplete'));
        await UniversalRouter.routeUser(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: StarlightTheme.primaryBlue),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr('createAccount'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
                ),
                Text(tr('joinStarlightNetwork'), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 24),

                // TAB SELECTOR
                Row(
                  children: [
                    Expanded(child: _buildTabButton("EMAIL", tr('tabEmail'))),
                    const SizedBox(width: 12),
                    Expanded(child: _buildTabButton("PHONE", tr('tabPhone'))),
                  ],
                ),
                const SizedBox(height: 32),

                if (_activeTab == "EMAIL") ..._buildEmailForm() else ..._buildPhoneForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String value, String label) {
    final bool isActive = _activeTab == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeTab = value;
          _isLoading = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? StarlightTheme.primaryBlue : Colors.grey.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isActive ? StarlightTheme.primaryBlue : Colors.grey.withOpacity(0.2)),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEmailForm() {
    return [
      Row(
        children: [
          Expanded(
            child: TextFormField(
              controller: _fNameController,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(
                labelText: tr('firstName'),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _lNameController,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              decoration: InputDecoration(labelText: tr('lastName')),
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _emailController,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        decoration: InputDecoration(
          labelText: tr('email'),
          prefixIcon: Icon(Icons.email_outlined),
        ),
        keyboardType: TextInputType.emailAddress,
      ),
      const SizedBox(height: 16),
      TextFormField(
        controller: _passController,
        obscureText: _isObscure,
        onChanged: _checkPassword,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        decoration: InputDecoration(
          labelText: tr('password'),
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _isObscure = !_isObscure),
          ),
        ),
      ),
      const SizedBox(height: 8),
      _buildStrengthBar(),
      const SizedBox(height: 16),
      TextFormField(
        controller: _confirmPassController,
        obscureText: true,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        decoration: InputDecoration(
          labelText: tr('confirmPassword'),
          prefixIcon: Icon(Icons.shield_outlined),
        ),
      ),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: _isLoading ? null : _handleEmailSignup,
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(tr('createAccountButton'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
  }

  List<Widget> _buildPhoneForm() {
    if (_isPhoneOtpSent) {
      // Step 2: Verify SMS OTP and complete registration
      return [
        TextField(
          controller: _phoneOtpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 8, fontSize: 16),
          decoration: InputDecoration(
            labelText: tr('smsOtpCode'),
            prefixIcon: Icon(Icons.vibration_rounded),
            counterText: "",
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _isLoading ? null : _handlePhoneVerifyAndRegister,
          child: _isLoading
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Text(tr('verifyRegisterButton'), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ];
    }

    // Step 1: Input details to receive SMS OTP
    return [
      TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        decoration: InputDecoration(
          labelText: tr('phoneNumber'),
          prefixText: "+92 ",
          prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70),
          prefixIcon: Icon(Icons.phone_android_rounded),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _phoneNameController,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        decoration: InputDecoration(
          labelText: tr('fullName'),
          prefixIcon: Icon(Icons.person_outline),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _phonePassController,
        obscureText: _isObscure,
        onChanged: _checkPassword,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        decoration: InputDecoration(
          labelText: tr('password'),
          prefixIcon: const Icon(Icons.lock_outline),
          suffixIcon: IconButton(
            icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _isObscure = !_isObscure),
          ),
        ),
      ),
      const SizedBox(height: 8),
      _buildStrengthBar(),
      const SizedBox(height: 16),
      TextField(
        controller: _phoneConfirmPassController,
        obscureText: true,
        style: const TextStyle(color: Colors.white70, fontSize: 14),
        decoration: InputDecoration(
          labelText: tr('confirmPassword'),
          prefixIcon: Icon(Icons.shield_outlined),
        ),
      ),
      const SizedBox(height: 32),
      ElevatedButton(
        onPressed: _isLoading ? null : _handlePhoneSignupOTP,
        child: _isLoading
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Text(tr('sendSmsOtpButton'), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    ];
  }

  Widget _buildStrengthBar() {
    Color strengthColor = _strength < 0.3 ? Colors.red : _strength < 0.7 ? Colors.orange : Colors.green;
    String label = _strength < 0.3
        ? tr('strengthWeak')
        : _strength < 0.7
            ? tr('strengthFair')
            : tr('strengthStrong');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: _strength,
            backgroundColor: Colors.grey[300],
            color: strengthColor,
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('strengthPrefix', {'level': label}),
          style: TextStyle(fontSize: 12, color: strengthColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
