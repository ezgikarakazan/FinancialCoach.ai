import 'package:flutter/material.dart';
import 'dart:html' as html;
import '../services/api_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  int _currentStep = 0;
  List<Map<String, dynamic>> _candidateTransactions = [];
  bool _isProcessing = false;

  Future<void> _pickPdf() async {
    try {
      final html.InputElement uploadInput = html.document.createElement('input') as html.InputElement;
      uploadInput.type = 'file';
      uploadInput.accept = '.pdf';
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files == null || files.isEmpty) return;

        final file = files[0];
        final reader = html.FileReader();

        reader.onLoadEnd.listen((e) async {
          setState(() {
            _currentStep = 1;
            _candidateTransactions = [];
          });

          // File buffer'ını API'ye gönder
          await _extractPdfFromWeb(file);
        });

        reader.readAsArrayBuffer(file);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Dosya seçme hatası: $e")),
        );
      }
    }
  }

  Future<void> _extractPdfFromWeb(html.File file) async {
    setState(() => _isProcessing = true);

    try {
      // Web'de file path kullanamadığımız için, direktmen extracted text'e mock data koyabiliriz
      // veya backend endpoint'ini değiştirebiliriz
      
      // Şimdilik örnek text ile ilerle
      final mockText = "15.06.2026 | Starbucks | 125.50\n"
          "16.06.2026 | Uber | 45.00\n"
          "17.06.2026 | Market | 200.00";

      setState(() {
        _candidateTransactions = _parseTransactions(mockText);
        _currentStep = 2;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("PDF yüklenirken hata: $e")),
        );
        setState(() => _currentStep = 0);
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  List<Map<String, dynamic>> _parseTransactions(String text) {
    final transactions = <Map<String, dynamic>>[];
    final lines = text.split('\n');

    final pattern = RegExp(
      r'(\d{1,2})[./\-](\d{1,2})[./\-](\d{4})\s*\|\s*([^|]+)\s*\|\s*([0-9,.]+)',
    );

    for (final line in lines) {
      final match = pattern.firstMatch(line.trim());
      if (match != null) {
        try {
          final day = int.parse(match.group(1)!);
          final month = int.parse(match.group(2)!);
          final year = int.parse(match.group(3)!);
          final title = match.group(4)!.trim();
          final amountStr = match.group(5)!.replaceAll(',', '.');
          final amount = double.parse(amountStr);

          if (month >= 1 && month <= 12 && day >= 1 && day <= 31) {
            transactions.add({
              'date': DateTime(year, month, day),
              'title': title,
              'amount': -amount,
              'category': _guessCategory(title),
              'selected': true,
            });
          }
        } catch (_) {}
      }
    }

    return transactions;
  }

  String _guessCategory(String title) {
    final lower = title.toLowerCase();

    if (lower.contains('rest') || lower.contains('yiyecek') || lower.contains('kafe') || lower.contains('starbucks')) {
      return 'Yiyecek';
    } else if (lower.contains('uber') || lower.contains('taxi') || lower.contains('otobüs') || lower.contains('metro')) {
      return 'Ulaşım';
    } else if (lower.contains('konut') || lower.contains('kira') || lower.contains('elektrik')) {
      return 'Konut';
    } else if (lower.contains('sinema') || lower.contains('oyun') || lower.contains('tiyatro')) {
      return 'Eğlence';
    } else if (lower.contains('eczane') || lower.contains('hastane') || lower.contains('doktor')) {
      return 'Sağlık';
    }
    return 'Diğer';
  }

  Future<void> _confirmImport() async {
    final selectedTxs = _candidateTransactions.where((tx) => tx['selected'] == true).toList();

    if (selectedTxs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("En az 1 işlem seçmelisin")),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      int successCount = 0;
      for (final tx in selectedTxs) {
        try {
          await ApiService.addTransaction(
            title: tx['title'],
            amount: tx['amount'],
            category: tx['category'],
            date: tx['date'],
          );
          successCount++;
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$successCount işlem başarıyla eklendi")),
        );
        _reset();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import sırasında hata: $e")),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _candidateTransactions = [];
    });
  }

  Color _categoryColor(String category) {
    final colors = {
      'Yiyecek': const Color(0xFF1E6B52),
      'Ulaşım': const Color(0xFFC96B3B),
      'Konut': const Color(0xFF7B887F),
      'Eğlence': const Color(0xFFB8606A),
      'Sağlık': const Color(0xFF6B8A7F),
      'Diğer': const Color(0xFF9B8C7E),
    };
    return colors[category] ?? const Color(0xFF7B887F);
  }

  IconData _categoryIcon(String category) {
    final icons = {
      'Yiyecek': Icons.restaurant_outlined,
      'Ulaşım': Icons.directions_car_outlined,
      'Konut': Icons.home_outlined,
      'Eğlence': Icons.local_movies_outlined,
      'Sağlık': Icons.local_hospital_outlined,
      'Diğer': Icons.shopping_bag_outlined,
    };
    return icons[category] ?? Icons.category_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : _currentStep == 0
                ? _buildStep0(theme)
                : _currentStep == 1
                    ? _buildStep1(theme)
                    : _buildStep2(theme),
      ),
    );
  }

  Widget _buildStep0(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Akıllı\nYükleme",
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: 10),
          Text(
            "Banka ekstresi PDF'sini yükle. İşlemler otomatik olarak ayrıştırılacak.",
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: _pickPdf,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF6),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: const Color(0xFFE8DFD3),
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E6B52).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Color(0xFF1E6B52),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "PDF dosyasını seç",
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Desteklenen format: PDF (banka ekstreleri)\nSınırlandırma: 10MB'a kadar",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF7B887F),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF6),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8DFD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "📋 Desteklenen format",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Tarih | İşlem Açıklaması | Tutar\n"
                  "Örnek: 15.06.2026 | Starbucks | 125.50",
                  style: TextStyle(
                    color: Color(0xFF64716B),
                    fontSize: 13,
                    height: 1.6,
                    fontFamily: 'Courier',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _currentStep = 0),
                child: const Icon(Icons.arrow_back_outlined, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Adım 2/2: İşlemleri Kontrol Et",
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "${_candidateTransactions.where((tx) => tx['selected'] == true).length}/${_candidateTransactions.length} seçildi",
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7B887F),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_candidateTransactions.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE9DED4)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 40,
                    color: Color(0xFF7B887F),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "İşlem bulunamadı",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "PDF'den işlem ayrıştırılamadı. Format kontrolü yap.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64716B),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() => _currentStep = 0),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E6B52),
                    ),
                    child: const Text("Başa Dön"),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _candidateTransactions.length,
              itemBuilder: (context, idx) {
                final tx = _candidateTransactions[idx];
                final isSelected = tx['selected'] == true;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _candidateTransactions[idx]['selected'] = !isSelected;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFCF6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF1E6B52) : const Color(0xFFE8DFD3),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: _categoryColor(tx['category']).withOpacity(0.12),
                            child: Icon(
                              _categoryIcon(tx['category']),
                              color: _categoryColor(tx['category']),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tx['title'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Color(0xFF1E2722),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${(tx['date'] as DateTime).day.toString().padLeft(2, '0')}.${(tx['date'] as DateTime).month.toString().padLeft(2, '0')}.${(tx['date'] as DateTime).year}",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7B887F),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                "₺${(tx['amount'] as num).abs().toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                  color: Color(0xFFB04242),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _categoryColor(tx['category']).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tx['category'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _categoryColor(tx['category']),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE8DFD3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("İptal"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _confirmImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E6B52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Ekle"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 120),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF6),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE8DFD3)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E6B52).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    size: 48,
                    color: Color(0xFF1E6B52),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Başarılı!",
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  "İşlemler portföyüne eklendi. Dashboard'u güncellemen gerek.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _reset,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E6B52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text("Yeni Dosya Yükle"),
          ),
        ],
      ),
    );
  }
}