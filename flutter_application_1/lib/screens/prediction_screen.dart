import 'package:flutter/material.dart';
import '../services/api_service.dart';

class PredictionScreen extends StatelessWidget {
  const PredictionScreen({super.key});

  String _formatMoney(dynamic value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return "₺${number.toStringAsFixed(2)}";
  }

  Color _confidenceColor(int confidence) {
    if (confidence >= 80) return const Color(0xFF1E6B52);
    if (confidence >= 60) return const Color(0xFFC96B3B);
    return const Color(0xFFB04242);
  }

  String _confidenceLabel(int confidence) {
    if (confidence >= 80) return "Yüksek";
    if (confidence >= 60) return "Orta";
    return "Düşük";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService.getPrediction(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _PredictionLoadingState();
          }

          if (snapshot.hasError) {
            return const _PredictionMessageState(
              icon: Icons.show_chart_outlined,
              title: "Tahmin verisi alınamadı",
              subtitle: "Backend bağlantısını veya prediction endpoint'ini kontrol et.",
            );
          }

          final data = snapshot.data ?? {};
          final predictedExpense = (data["predicted_expense"] as num?)?.toDouble() ?? 0;
          final confidence = (data["confidence"] as num?)?.toInt() ?? 0;
          final message = data["message"]?.toString() ?? "Tahmin verisi alınamadı.";

          final hasData = predictedExpense > 0 && confidence > 0;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "AI\ntahminleri",
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Geçmiş harcama trendine dayalı gelecek ay beklentileri.",
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  if (!hasData)
                    const _PredictionMessageCard(
                      title: "Henüz tahmin oluşturulamıyor",
                      subtitle: "Tahmin modeli en az 1 ay gider verisi gerektirir. Lütfen farklı tarihlerde birkaç işlem ekle.",
                    )
                  else
                    Column(
                      children: [
                        _PredictionHeroCard(
                          predictedExpense: _formatMoney(predictedExpense),
                          confidence: confidence,
                          confidenceColor: _confidenceColor(confidence),
                          confidenceLabel: _confidenceLabel(confidence),
                        ),
                        const SizedBox(height: 20),
                        _PredictionInsightCard(
                          message: message,
                          accent: _confidenceColor(confidence),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          "Tahmin kalitesi",
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        _ConfidenceBreakdownCard(
                          confidence: confidence,
                          color: _confidenceColor(confidence),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          "Aksiyon önerileri",
                          style: theme.textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 12),
                        _ActionTipCard(
                          icon: Icons.trending_down_rounded,
                          title: "Harcama kesintisi",
                          subtitle: "Tahmin edilen tutarı %10 azaltmak için en yüksek kategoriyi %5 ve ikinci yüksek kategoriyi %10 azalt.",
                          tone: const Color(0xFFF4E0D6),
                          iconColor: const Color(0xFFC96B3B),
                        ),
                        const SizedBox(height: 12),
                        _ActionTipCard(
                          icon: Icons.savings_rounded,
                          title: "Otomatik birikim",
                          subtitle: "Aylık birikim planı oluştur. Harcama tahmini ile gelir farkını sabit olarak ayır.",
                          tone: const Color(0xFFDDEEE7),
                          iconColor: const Color(0xFF1E6B52),
                        ),
                        const SizedBox(height: 12),
                        _ActionTipCard(
                          icon: Icons.analytics_rounded,
                          title: "Kategori analizi",
                          subtitle: "En yüksek harcama kategorisindeki işlemleri analiz ekranında detaylı incele.",
                          tone: const Color(0xFFF1EEE5),
                          iconColor: const Color(0xFF7B887F),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PredictionHeroCard extends StatelessWidget {
  final String predictedExpense;
  final int confidence;
  final Color confidenceColor;
  final String confidenceLabel;

  const _PredictionHeroCard({
    required this.predictedExpense,
    required this.confidence,
    required this.confidenceColor,
    required this.confidenceLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            confidenceColor.withOpacity(0.95),
            confidenceColor.withOpacity(0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: confidenceColor.withOpacity(0.3),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Gelecek ay tahmini",
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            predictedExpense,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Tahmin güveni",
                      style: TextStyle(
                        color: Color(0xCCFFFFFF),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "$confidence%",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0x2AFFFFFF),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0x33FFFFFF)),
                ),
                child: Text(
                  confidenceLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PredictionInsightCard extends StatelessWidget {
  final String message;
  final Color accent;

  const _PredictionInsightCard({
    required this.message,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE8E0D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "💡 AI İçgörü",
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: Color(0xFF55635D),
              fontSize: 15,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConfidenceBreakdownCard extends StatelessWidget {
  final int confidence;
  final Color color;

  const _ConfidenceBreakdownCard({
    required this.confidence,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    String reason;
    if (confidence >= 80) {
      reason = "3+ ay veri ile oluşturulmuş yüksek kaliteli tahmin";
    } else if (confidence >= 60) {
      reason = "2-3 ay veri ile orta kalitede tahmin";
    } else {
      reason = "Tek ay veri ile düşük güvenirlilik. Daha fazla veri ekle.";
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E0D2)),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 12,
              value: confidence / 100,
              backgroundColor: const Color(0xFFEFE9DD),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  reason,
                  style: const TextStyle(
                    color: Color(0xFF64716B),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionTipCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color tone;
  final Color iconColor;

  const _ActionTipCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE8E0D2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: tone,
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2722),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64716B),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionMessageCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _PredictionMessageCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7DED2)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.auto_graph_rounded,
            size: 40,
            color: Color(0xFF7B887F),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E2722),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64716B),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _PredictionMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PredictionMessageState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE9DED4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 42,
                  color: const Color(0xFFC96B3B),
                ),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF5B6761),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PredictionLoadingState extends StatelessWidget {
  const _PredictionLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}