import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {

  String? selectedFile;

  Future<void> pickPdf() async {

    FilePickerResult? result =
        await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      setState(() {
        selectedFile = result.files.single.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ekstre Yükle"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [

            const SizedBox(height: 30),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),

              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.green,
                  width: 2,
                ),
              ),

              child: Column(
                children: [

                  const Icon(
                    Icons.picture_as_pdf,
                    size: 80,
                    color: Colors.red,
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    "Banka Ekstresi Yükle",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    selectedFile ??
                        "Henüz PDF seçilmedi",
                  ),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: pickPdf,
                    icon: const Icon(Icons.upload),
                    label: const Text("PDF Seç"),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            if(selectedFile != null)

              Card(
                child: ListTile(
                  leading: const Icon(Icons.check_circle,
                      color: Colors.green),
                  title: Text(selectedFile!),
                  subtitle:
                  const Text("Yüklenmeye hazır"),
                ),
              )
          ],
        ),
      ),
    );
  }
}