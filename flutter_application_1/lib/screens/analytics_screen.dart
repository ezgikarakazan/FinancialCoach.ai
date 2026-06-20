import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/expense_pie_chart.dart';
import '../widgets/trend_line_chart.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  String _formatMoney(dynamic value) {
    final number = (value as num?)?.toDouble() ?? 0;
    return "₺${number.toStringAsFixed(2)}";
  }

  Color _getCategoryColor(String category) {
    final colors = {
      "Market": const Color(0xFF1E6B52),
      "Yeme İçme": const Color(0xFFC96B3B),
      "Ulaşım": const Color(0xFF3C6E71),
      "Eğlence": const Color(0xFF9C6ADE),
      "Alışveriş": const Color(0xFFD96C8A),
      "Diger": const Color(0xFF7B887F),
      "Diğer": const Color(0xFF7B887F),
    };
    return colors[category] ?? const Color(0xFF5C7C6D);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
        future: ApiService.getAnalytics(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _AnalyticsLoadingState();
          }

          if (snapshot.hasError) {
            return const _AnalyticsMessageState(
              icon: Icons.analytics_outlined,
              title: "Analiz verisi alınamadı",
              subtitle: "Backend bağlantısını veya analytics endpoint çıktısını kontrol et.",
            );
          }

          final data = snapshot.data ?? {};
          final categories = (data["categories"] as List<dynamic>? ?? []);
          final monthly = (data["monthly_expenses"] as List<dynamic>? ?? []);

          final totalExpense = categories.fold<double>(
            0,
            (sum, item) => sum + (((item as Map<String, dynamic>)["amount"] as num?)?.toDouble() ?? 0),
          );

          final topCategory = categories.isNotEmpty
              ? (categories.first as Map<String, dynamic>)["name"]?.toString() ?? "-"
              : "Yok";

          final topCategoryAmount = categories.isNotEmpty
              ? (((categories.first as Map<String, dynamic>)["amount"] as num?)?.toDouble() ?? 0)
              : 0.0;

          final lastMonthAmount = monthly.isNotEmpty
              ? (((monthly.last as Map<String, dynamic>)["amount"] as num?)?.toDouble() ?? 0)
              : 0.0;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Harcama\nanalitiği",
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Kategori yoğunluğu ve aylık değişim tek ekranda özetlenir.",
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _AnalyticsHeroCard(
                    totalExpense: _formatMoney(totalExpense),
                    topCategory: topCategory,
                    topCategoryAmount: _formatMoney(topCategoryAmount),
                    lastMonthAmount: _formatMoney(lastMonthAmount),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniAnalyticsCard(
                          label: "Kategori",
                          value: categories.length.toString(),
                          icon: Icons.grid_view_rounded,
                          tone: const Color(0xFFDDEEE7),
                          iconColor: const Color(0xFF1E6B52),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _MiniAnalyticsCard(
                          label: "Aylık nokta",
                          value: monthly.length.toString(),
                          icon: Icons.show_chart_rounded,
                          tone: const Color(0xFFF4E0D6),
                          iconColor: const Color(0xFFC96B3B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    "Kategori dağılımı",
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  if (categories.isEmpty)
                    const _AnalyticsMessageCard(
                      title: "Henüz kategori verisi yok",
                      subtitle: "Negatif tutarlı işlemler eklendiğinde burada dağılım oluşacak.",
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF6),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFE7DED2)),
                      ),
                      child: ExpensePieChart(
                        categories: categories,
                      ),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    "Kategori detayları",
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  if (categories.isEmpty)
                    const _AnalyticsMessageCard(
                      title: "Detay kartları hazır değil",
                      subtitle: "Önce birkaç gider işlemi ekleyip kategorileri çeşitlendir.",
                    )
                  else
                    ...categories.map((item) {
                      final map = item as Map<String, dynamic>;
                      final categoryName = map["name"]?.toString() ?? "-";
                      final amount = (map["amount"] as num?)?.toDouble() ?? 0;
                      final share = totalExpense > 0 ? (amount / totalExpense) * 100 : 0.0;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _CategoryDetailCard(
                          title: categoryName,
                          amount: _formatMoney(amount),
                          share: "%${share.toStringAsFixed(1)}",
                          color: _getCategoryColor(categoryName),
                        ),
                      );
                    }),
                  const SizedBox(height: 28),
                  Text(
                    "Aylık trend",
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  if (monthly.isEmpty)
                    const _AnalyticsMessageCard(
                      title: "Trend için yeterli veri yok",
                      subtitle: "Farklı tarihlerde gider eklediğinde aylık akış burada çizilecek.",
                    )
                  else
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF6),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: const Color(0xFFE7DED2)),
                      ),
                      child: TrendLineChart(
                        monthlyExpenses: monthly,
                      ),
                    ),
                  const SizedBox(height: 28),
                  Text(
                    "Aylık harcamalar",
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  if (monthly.isEmpty)
                    const _AnalyticsMessageCard(
                      title: "Aylık özet görünmüyor",
                      subtitle: "Aynı ay içinde birkaç gider oluşturarak bu listeyi doldurabilirsin.",
                    )
                  else
                    ...monthly.map((item) {
                      final map = item as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MonthRowCard(
                          month: map["month"]?.toString() ?? "-",
                          amount: _formatMoney(map["amount"]),
                        ),
                      );
                    }),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsHeroCard extends StatelessWidget {
  final String totalExpense;
  final String topCategory;
  final String topCategoryAmount;
  final String lastMonthAmount;

  const _AnalyticsHeroCard({
    required this.totalExpense,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.lastMonthAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF352419),
            Color(0xFF5A3B28),
            Color(0xFF7A5640),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Toplam izlenen gider",
            style: TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            totalExpense,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 38,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _HeroMiniInfo(
                  label: "En yoğun kategori",
                  value: topCategory,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMiniInfo(
                  label: "Kategori tutarı",
                  value: topCategoryAmount,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HeroMiniInfo(
                  label: "Son ay",
                  value: lastMonthAmount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroMiniInfo extends StatelessWidget {
  final String label;
  final String value;

  const _HeroMiniInfo({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x1AFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x22FFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xCCFFFFFF),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniAnalyticsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color tone;
  final Color iconColor;

  const _MiniAnalyticsCard({
    required this.label,
    required this.value,
    required this.icon,
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
        border: Border.all(color: const Color(0xFFE6E1D7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: tone,
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF64726C),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1E2722),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryDetailCard extends StatelessWidget {
  final String title;
  final String amount;
  final String share;
  final Color color;

  const _CategoryDetailCard({
    required this.title,
    required this.amount,
    required this.share,
    required this.color,
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
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 12),
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
              Text(
                amount,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 10,
                    value: (double.tryParse(share.replaceAll("%", "")) ?? 0) / 100,
                    backgroundColor: const Color(0xFFEFE9DD),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                share,
                style: const TextStyle(
                  color: Color(0xFF68756E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthRowCard extends StatelessWidget {
  final String month;
  final String amount;

  const _MonthRowCard({
    required this.month,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE9E2D8)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF3E6DB),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_month_rounded,
              color: Color(0xFF9A5A36),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              month,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E2722),
              ),
            ),
          ),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF9A5A36),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsMessageCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _AnalyticsMessageCard({
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
            Icons.insights_rounded,
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

class _AnalyticsMessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _AnalyticsMessageState({
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

class _AnalyticsLoadingState extends StatelessWidget {
  const _AnalyticsLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}