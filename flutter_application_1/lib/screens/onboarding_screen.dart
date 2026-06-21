import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final Future<void> Function() onFinished;

  const OnboardingScreen({super.key, required this.onFinished});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingPageData> _pages = const [
    _OnboardingPageData(
      title: 'Paranı tek bakışta gör',
      description: 'Gelir, gider ve tasarrufu sade bir akışta takip et. Finansal resim dağılmadan tek ekranda toplansın.',
      icon: Icons.insights_rounded,
      tone: Color(0xFF1E6B52),
    ),
    _OnboardingPageData(
      title: 'Belgeleri yükle, işlem çıkar',
      description: 'Ekstre ve fişleri yükleyerek işlem akışını otomatikleştir. Tekrarlı giriş yükünü azalt.',
      icon: Icons.upload_file_rounded,
      tone: Color(0xFFC96B3B),
    ),
    _OnboardingPageData(
      title: 'AI ile risk ve trend yakala',
      description: 'Harcamalardaki baskıyı ve fırsatları erken gör. Sonraki adımını daha net planla.',
      icon: Icons.auto_awesome_rounded,
      tone: Color(0xFF304238),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.onFinished();
  }

  Future<void> _next() async {
    if (_currentPage == _pages.length - 1) {
      await _finish();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _skip() async {
    await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF5F3EC), Color(0xFFFDF9F1), Color(0xFFEAF3ED)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'AI Finance Coach',
                      style: theme.textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: _skip,
                      child: const Text('Atla'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: _OnboardingPage(page: page),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_pages.length, (index) {
                        final selected = index == _currentPage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: selected ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFF1E6B52)
                                : const Color(0xFFB8C4BC),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF1E6B52),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? 'Başlayalım' : 'Devam et',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;
  final Color tone;

  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
    required this.tone,
  });
}

class _OnboardingPage extends StatelessWidget {
  final _OnboardingPageData page;

  const _OnboardingPage({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6).withOpacity(0.82),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE8DFD3)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(height: 6),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: page.tone.withOpacity(0.14),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(page.icon, size: 40, color: page.tone),
          ),
          const SizedBox(height: 28),
          Text(
            page.title,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 30,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            page.description,
            style: theme.textTheme.bodyLarge,
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  page.tone.withOpacity(0.18),
                  page.tone.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: page.tone),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kurulum olmadan birkaç adımda başla',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF304238),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}