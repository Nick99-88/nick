import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:starlight_flutter/core/storage.dart';
import 'package:starlight_flutter/l10n/strings.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final bool fromSettings;
  const LanguageSelectionScreen({super.key, this.fromSettings = false});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  String _selectedLanguage = 'default';

  @override
  void initState() {
    super.initState();
    _loadStoredLanguage();
  }

  Future<void> _loadStoredLanguage() async {
    final stored = await StarlightStorage.getSelectedLanguage();
    if (stored != null && mounted) {
      setState(() => _selectedLanguage = stored);
    }
  }

  Future<void> _saveLanguageAndContinue() async {
    await setLocale(_selectedLanguage);

    if (!mounted) return;
    if (widget.fromSettings) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacementNamed(context, '/intro');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.deepPurple.shade900,
              Colors.blue.shade900,
              Colors.indigo.shade800,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.shade400,
                          Colors.orange.shade500,
                        ],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.language,
                      size: 60,
                      color: Colors.white,
                    ),
                  )
                      .animate()
                      .scale(duration: 600.ms, curve: Curves.elasticOut)
                      .fadeIn(duration: 600.ms),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    tr('selectLanguage'),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 200.ms),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    tr('choosePreferredLanguage'),
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ).animate().fadeIn(duration: 600.ms, delay: 300.ms),

                  const SizedBox(height: 48),

                  // Language Options
                  _buildLanguageOption(
                    'default',
                    tr('defaultLanguage'),
                    tr('systemDefault'),
                    Icons.phone_android,
                  ).animate().fadeIn(duration: 600.ms, delay: 400.ms),

                  const SizedBox(height: 16),

                  _buildLanguageOption(
                    'en',
                    'English',
                    tr('englishLanguage'),
                    Icons.flag,
                  ).animate().fadeIn(duration: 600.ms, delay: 500.ms),

                  const SizedBox(height: 16),

                  _buildLanguageOption(
                    'ur',
                    'اردو',
                    tr('urduLanguage'),
                    Icons.translate,
                  ).animate().fadeIn(duration: 600.ms, delay: 600.ms),

                  const SizedBox(height: 48),

                  // Continue Button
                  _buildContinueButton().animate().fadeIn(duration: 600.ms, delay: 700.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
      String value,
      String title,
      String subtitle,
      IconData icon,
      ) {
    final isSelected = _selectedLanguage == value;

    return InkWell(
      onTap: () {
        setState(() => _selectedLanguage = value);
        setLocale(value);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [
              Colors.amber.shade400,
              Colors.orange.shade500,
            ],
          )
              : LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.amber.shade300 : Colors.white.withOpacity(0.2),
            width: 2,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.amber.withOpacity(0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.7),
                size: 28,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.white.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 28,
              ).animate().scale(
                duration: 300.ms,
                curve: Curves.elasticOut,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saveLanguageAndContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber.shade500,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          shadowColor: Colors.amber.withOpacity(0.4),
        ),
        child: Text(
          tr(widget.fromSettings ? 'save' : 'continueAction'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}