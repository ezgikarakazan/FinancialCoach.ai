import 'package:flutter/material.dart';
import 'dart:html' as html;
import 'dart:typed_data';
import '../services/api_service.dart';
import 'pdf_history_screen.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  int _currentStep = 0;
  int _reviewIndex = 0;
  int _addedCount = 0;
  int _skippedCount = 0;
  int? _currentUploadId;
  String _uploadedFileName = '';
  String? _emptyStateOverrideMessage;
  List<Map<String, dynamic>> _candidateTransactions = [];
  bool _isProcessing = false;
  bool _isDeciding = false;

  Future<void> _pickPdf() async {
    try {
      final html.InputElement uploadInput =
          html.document.createElement('input') as html.InputElement;
      uploadInput.type = 'file';
      uploadInput.accept = '.pdf';
      uploadInput.click();

      uploadInput.onChange.listen((e) async {
        final files = uploadInput.files;
        if (files == null || files.isEmpty) return;

        final file = files[0];
        setState(() {
          _isProcessing = true;
          _currentStep = 0;
        });

        final reader = html.FileReader();

        reader.onError.listen((_) {
          if (!mounted) return;
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Dosya okunamadı. Lütfen tekrar dene."),
            ),
          );
        });

        reader.onAbort.listen((_) {
          if (!mounted) return;
          setState(() => _isProcessing = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Dosya okuma iptal edildi.")),
          );
        });

        reader.onLoadEnd.listen((e) async {
          try {
            final bytes = _extractBytesFromReaderResult(reader.result);
            if (bytes == null || bytes.isEmpty) {
              throw Exception('Dosya byte verisi boş');
            }

            await _extractPdfFromWeb(fileName: file.name, bytes: bytes);
          } catch (err) {
            if (!mounted) return;
            setState(() => _isProcessing = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Dosya işlenemedi: $err")));
          }
        });

        reader.readAsArrayBuffer(file);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Dosya seçme hatası: $e")));
      }
    }
  }

  List<int>? _extractBytesFromReaderResult(Object? result) {
    if (result == null) return null;

    if (result is ByteBuffer) {
      return Uint8List.view(result);
    }

    if (result is Uint8List) {
      return result;
    }

    if (result is List<int>) {
      return result;
    }

    return null;
  }

  Future<void> _extractPdfFromWeb({
    required String fileName,
    required List<int> bytes,
  }) async {
    setState(() => _isProcessing = true);

    try {
      final response = await ApiService.uploadPdf(
        bytes: bytes,
        fileName: fileName,
      );

      final isDuplicate = response['duplicate'] == true;
      final uploadIdRaw = response['upload_id'];
      final uploadId = uploadIdRaw is int
          ? uploadIdRaw
          : int.tryParse(uploadIdRaw?.toString() ?? '');

      final allCandidates = _parseCandidatesFromResponse(response);
      final addedSoFar = allCandidates.where((c) => c['status'] == 'added').length;
      final skippedSoFar = allCandidates.where((c) => c['status'] == 'skipped').length;

      final reviewCandidates = isDuplicate
          ? allCandidates.where((c) => c['status'] == 'pending').toList()
          : allCandidates;

      setState(() {
        _currentUploadId = uploadId;
        _candidateTransactions = reviewCandidates;
        _addedCount = addedSoFar;
        _skippedCount = skippedSoFar;
        _reviewIndex = 0;
        _uploadedFileName = fileName;
        _emptyStateOverrideMessage = (isDuplicate && reviewCandidates.isEmpty)
            ? "Bu PDF'i daha önce yükledin ve tüm işlemler zaten incelenmiş. Geçmişten tekrar bakabilirsin."
            : null;
        _currentStep = reviewCandidates.isEmpty ? 2 : 1;
      });

      if (isDuplicate && mounted) {
        final message = reviewCandidates.isEmpty
            ? "Bu PDF'i daha önce yükledin, tüm işlemler zaten incelenmiş."
            : "Bu PDF'i daha önce yükledin. Kalan ${reviewCandidates.length} işlemi incelemeye devam ediyorsun.";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("PDF yüklenirken hata: $e")));
        setState(() => _currentStep = 0);
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  List<Map<String, dynamic>> _parseCandidatesFromResponse(
    Map<String, dynamic> response,
  ) {
    final backendParsed = response['parsed_transactions'];
    if (backendParsed is! List) return [];

    final converted = <Map<String, dynamic>>[];

    for (final item in backendParsed) {
      if (item is! Map) continue;

      final idRaw = item['id'];
      final id = idRaw is int ? idRaw : int.tryParse(idRaw?.toString() ?? '');
      final dateRaw = item['date']?.toString();
      final title = item['title']?.toString().trim() ?? '';
      final category = item['category']?.toString().trim() ?? 'Diğer';
      final amountRaw = item['amount'];
      final status = item['status']?.toString() ?? 'pending';

      final date = dateRaw == null ? null : DateTime.tryParse(dateRaw);
      final amount = amountRaw is num
          ? amountRaw.toDouble()
          : double.tryParse(amountRaw.toString());

      if (id == null || date == null || title.isEmpty || amount == null) {
        continue;
      }

      converted.add({
        'id': id,
        'date': date,
        'title': title,
        'amount': amount,
        'category': category,
        'status': status,
      });
    }

    return converted;
  }

  Future<void> _decideCurrentTransaction(bool shouldAdd) async {
    if (_isDeciding ||
        _candidateTransactions.isEmpty ||
        _reviewIndex >= _candidateTransactions.length ||
        _currentUploadId == null) {
      return;
    }

    final tx = _candidateTransactions[_reviewIndex];
    final status = shouldAdd ? 'added' : 'skipped';

    setState(() => _isDeciding = true);

    try {
      await ApiService.decidePdfUploadItem(
        uploadId: _currentUploadId!,
        itemId: tx['id'] as int,
        status: status,
      );

      setState(() {
        tx['status'] = status;
        if (shouldAdd) {
          _addedCount++;
        } else {
          _skippedCount++;
        }

        if (_reviewIndex < _candidateTransactions.length - 1) {
          _reviewIndex++;
        } else {
          _currentStep = 3;
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst("Exception: ", "")),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeciding = false);
    }
  }

  void _goToPreviousReview() {
    if (_reviewIndex == 0) return;
    setState(() {
      _reviewIndex--;
    });
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _reviewIndex = 0;
      _addedCount = 0;
      _skippedCount = 0;
      _currentUploadId = null;
      _uploadedFileName = '';
      _emptyStateOverrideMessage = null;
      _candidateTransactions = [];
    });
  }

  void _openHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PdfHistoryScreen()),
    );
  }

  Color _categoryColor(String category) {
    final colors = {
      'Alışveriş': const Color(0xFF2E6F5E),
      'Eğitim': const Color(0xFF4E6FAF),
      'Eğlence': const Color(0xFFB8606A),
      'Yeme İçme': const Color(0xFF1E6B52),
      'Ulaşım': const Color(0xFFC96B3B),
      'Faturalar': const Color(0xFF7B887F),
      'Sağlık': const Color(0xFF6B8A7F),
      'Diğer': const Color(0xFF9B8C7E),
    };
    return colors[category] ?? const Color(0xFF7B887F);
  }

  IconData _categoryIcon(String category) {
    final icons = {
      'Alışveriş': Icons.shopping_bag_outlined,
      'Eğitim': Icons.school_outlined,
      'Eğlence': Icons.local_movies_outlined,
      'Yeme İçme': Icons.restaurant_outlined,
      'Ulaşım': Icons.directions_car_outlined,
      'Faturalar': Icons.receipt_long_outlined,
      'Sağlık': Icons.local_hospital_outlined,
      'Diğer': Icons.category_outlined,
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
            : _currentStep == 2
            ? _buildStep2(theme)
            : _buildStep3(theme),
      ),
    );
  }

  Widget _buildStep0(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text("Akıllı\nYükleme", style: theme.textTheme.headlineLarge),
              ),
              IconButton(
                onPressed: _openHistory,
                tooltip: "PDF Geçmişi",
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFFCF6),
                  side: const BorderSide(color: Color(0xFFE8DFD3)),
                ),
                icon: const Icon(
                  Icons.folder_outlined,
                  color: Color(0xFF1E6B52),
                ),
              ),
            ],
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
                border: Border.all(color: const Color(0xFFE8DFD3), width: 2),
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
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
    if (_candidateTransactions.isEmpty) {
      return _buildStep2(theme);
    }

    final tx = _candidateTransactions[_reviewIndex];
    final date = tx['date'] as DateTime;
    final amount = tx['amount'] as num;

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
                      "Ekstredeki İşlemler",
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$_uploadedFileName · ${_reviewIndex + 1}/${_candidateTransactions.length} işlem",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF6),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE8DFD3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: _categoryColor(
                        tx['category'],
                      ).withOpacity(0.12),
                      child: Icon(
                        _categoryIcon(tx['category']),
                        color: _categoryColor(tx['category']),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tx['category'],
                        style: TextStyle(
                          color: _categoryColor(tx['category']),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      "₺${amount.abs().toStringAsFixed(2)}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: Color(0xFFB04242),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  tx['title'],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2722),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7B887F),
                  ),
                ),
                const SizedBox(height: 18),
                if (tx['status'] != 'pending')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: (tx['status'] == 'added'
                              ? const Color(0xFF1E6B52)
                              : const Color(0xFF9B8C7E))
                          .withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      tx['status'] == 'added' ? "Eklendi" : "Atlandı",
                      style: TextStyle(
                        color: tx['status'] == 'added'
                            ? const Color(0xFF1E6B52)
                            : const Color(0xFF9B8C7E),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  )
                else
                  const Text(
                    "Bu işlemi eklemek istiyor musun?",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF3D4A44),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: (_reviewIndex + 1) / _candidateTransactions.length,
            minHeight: 8,
            borderRadius: BorderRadius.circular(999),
            color: const Color(0xFF1E6B52),
            backgroundColor: const Color(0xFFE8DFD3),
          ),
          const SizedBox(height: 8),
          Text(
            "Şu ana kadar $_addedCount işlem eklendi, $_skippedCount işlem atlandı.",
            style: const TextStyle(fontSize: 12, color: Color(0xFF7B887F)),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_isDeciding || _reviewIndex == 0)
                      ? null
                      : _goToPreviousReview,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE8DFD3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Önceki"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isDeciding
                      ? null
                      : () => _decideCurrentTransaction(false),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFB8606A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Atla"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _isDeciding
                      ? null
                      : () => _decideCurrentTransaction(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E6B52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isDeciding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text("Ekle"),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep2(ThemeData theme) {
    final message = _emptyStateOverrideMessage ??
        "PDF'den işlem ayrıştırılamadı. Formatı kontrol edip tekrar dene.";

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 120),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE9DED4)),
        ),
        child: Column(
          children: [
            Icon(
              _emptyStateOverrideMessage != null
                  ? Icons.folder_copy_outlined
                  : Icons.inbox_outlined,
              size: 40,
              color: const Color(0xFF7B887F),
            ),
            const SizedBox(height: 12),
            Text(
              _emptyStateOverrideMessage != null
                  ? "Bu PDF zaten incelenmiş"
                  : "İşlem bulunamadı",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64716B), fontSize: 13),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_emptyStateOverrideMessage != null) ...[
                  OutlinedButton(
                    onPressed: _openHistory,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE8DFD3)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text("Geçmişi Gör"),
                  ),
                  const SizedBox(width: 12),
                ],
                FilledButton(
                  onPressed: _reset,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1E6B52),
                  ),
                  child: const Text("Yeni PDF Yükle"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep3(ThemeData theme) {
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
                Text("İnceleme tamamlandı!", style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  "$_addedCount işlem portföyüne eklendi, $_skippedCount işlem atlandı.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                if (_skippedCount > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    "Atladığın işlemleri PDF Geçmişi'nden istediğin zaman ekleyebilirsin.",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7B887F),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: _openHistory,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE8DFD3)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text("PDF Geçmişi"),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _reset,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E6B52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text("Yeni Dosya Yükle"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
