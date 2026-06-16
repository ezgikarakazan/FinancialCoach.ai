import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("İşlemler"),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: ApiService.getTransactions(),
        builder: (context, snapshot) {

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(snapshot.error.toString()),
            );
          }

          final transactions = snapshot.data!;

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {

              final item = transactions[index];

              return ListTile(
                leading: const Icon(Icons.payments),
                title: Text(item["title"]),
                subtitle: Text(item["category"]),
                trailing: Text(
                  "${item["amount"]} TL",
                ),
              );
            },
          );
        },
      ),
    );
  }
}