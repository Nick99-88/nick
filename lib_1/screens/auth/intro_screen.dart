import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/storage.dart';
import '../../core/router_gateway.dart';
import '../../core/db_functions.dart';
import '../../l10n/strings.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  List<Map<String, String>> get _introData {
    return [
      {
        "title": tr('introSlide1Title'),
        "desc": tr('introSlide1Desc'),
        "icon": "🏛️"
      },
      {
        "title": tr('introSlide2Title'),
        "desc": tr('introSlide2Desc'),
        "icon": "🚀"
      },
      {
        "title": tr('introSlide3Title'),
        "desc": tr('introSlide3Desc'),
        "icon": "🌍"
      },
    ];
  }

  /// 🏛️ The Termination Protocol
  /// Saves the intro token and hands over control to the Universal Router
  Future<void> _finishIntro() async {
    // 1. Persist the fact that the intro is complete
    await StarlightStorage.setIntroToken(true);
    await VaultController.markIntroAsSeen();

    if (mounted) {
      // 2. 🏛️ Call the Router Gateway
      // This is better than manual navigation because the Gateway will
      // check if the user is already logged in or needs an Identity Hub link.
      await UniversalRouter.routeUser(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _introData.length,
            itemBuilder: (context, index) => _buildSlide(index),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  Widget _buildSlide(int index) {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_introData[index]['icon']!, style: const TextStyle(fontSize: 80)),
          const SizedBox(height: 40),
          Text(
            _introData[index]['title']!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: StarlightTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _introData[index]['desc']!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 50,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 🏛️ Skip: Saves token immediately and exits
          TextButton(
            onPressed: _finishIntro,
            child: Text(tr('skip'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          // Dots Indicator
          Row(
            children: List.generate(
              _introData.length,
                  (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: StarlightTheme.primaryBlue,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          // 🏛️ Next/Finish: Saves token on the last page
          IconButton(
            onPressed: () {
              if (_currentPage == _introData.length - 1) {
                _finishIntro();
              } else {
                _pageController.nextPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeIn,
                );
              }
            },
            icon: CircleAvatar(
              backgroundColor: StarlightTheme.primaryBlue,
              child: Icon(
                _currentPage == _introData.length - 1 ? Icons.check : Icons.arrow_forward,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}