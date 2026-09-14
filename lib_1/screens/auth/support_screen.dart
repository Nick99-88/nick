import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../services/auth/support_service.dart';
import '../../l10n/strings.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _emailController = TextEditingController();
  final _complaintController = TextEditingController();
  final SupportService _supportService = SupportService();
  bool _isSubmitting = false;

  // 🏛️ Quick Help Data for Animation
  final List<Map<String, dynamic>> _helpTopics = [
    {
      "icon": Icons.vpn_key_outlined,
      "titleKey": "helpForgotPassword",
      "descKey": "helpForgotPasswordDesc",
    },
    {
      "icon": Icons.devices_outlined,
      "titleKey": "helpDeviceSync",
      "descKey": "helpDeviceSyncDesc",
    },
    {
      "icon": Icons.account_balance_outlined,
      "titleKey": "helpFindInstitution",
      "descKey": "helpFindInstitutionDesc",
    },
  ];

  Future<void> _launchWebsite() async {
    final Uri url = Uri.parse('https://institution.site/');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) StarlightUtils.showErrorBox(context, tr('couldNotLaunchWebsite'));
    }
  }

  void _submitComplaint() async {
    final email = _emailController.text.trim();
    final issue = _complaintController.text.trim();

    if (email.isEmpty || issue.isEmpty) {
      StarlightUtils.showErrorBox(context, tr('allFieldsRequired'));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final result = await _supportService.submitTicket(email, issue);
      if (mounted) {
        setState(() => _isSubmitting = false);
        _emailController.clear();
        _complaintController.clear();
        StarlightUtils.showSuccessBox(
            context,
            tr('ticketRegistered', {'ticketId': '${result['ticket_id']}'}),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        StarlightUtils.showErrorBox(context, e.toString().replaceAll("Exception: ", ""));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('supportHub'), style: const TextStyle(color: Colors.white)),
        backgroundColor: StarlightTheme.primaryBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🏛️ Animative Header
            TweenAnimationBuilder(
              duration: const Duration(milliseconds: 800),
              tween: Tween<double>(begin: 0, end: 1),
              builder: (context, double value, child) {
                return Opacity(
                  opacity: value,
                  child: Padding(
                    padding: EdgeInsets.only(top: 20 * (1 - value)),
                    child: child,
                  ),
                );
              },
              child: Text(
                tr('commonHelpTopics'),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
              ),
            ),
            const SizedBox(height: 16),

            // 🏛️ Animated Help Tiles
            ...List.generate(_helpTopics.length, (index) {
              return _buildAnimatedTile(index, _helpTopics[index]);
            }),

            const Divider(height: 60, thickness: 1),

            Text(
              tr('submitComplaintTitle'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                  labelText: tr('yourContactEmail'),
                  prefixIcon: Icon(Icons.email_outlined)
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _complaintController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: tr('describeYourIssue'),
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // 🏛️ Submit Button with Animation
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: 55,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitComplaint,
                child: _isSubmitting
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
                    : Text(tr('submitComplaintButton'), style: const TextStyle(letterSpacing: 1.2)),
              ),
            ),

            const SizedBox(height: 32),

            // 🏛️ Website Link Button
            FadeInAnimation(
              delay: 1.0,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.language),
                label: Text(tr('visitOfficialWebsite')),
                onPressed: _launchWebsite,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: StarlightTheme.primaryBlue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedTile(int index, Map<String, dynamic> topic) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: 400 + (index * 200)),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(50 * (1 - value), 0),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: Icon(topic['icon'], color: StarlightTheme.primaryBlue),
          title: Text(tr(topic['titleKey']), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(tr(topic['descKey'])),
        ),
      ),
    );
  }
}

// 🏛️ Small Helper for the Bottom Button Fade
class FadeInAnimation extends StatelessWidget {
  final double delay;
  final Widget child;
  const FadeInAnimation({super.key, required this.delay, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: Duration(milliseconds: (800 * delay).toInt()),
      tween: Tween<double>(begin: 0, end: 1),
      builder: (context, double value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}