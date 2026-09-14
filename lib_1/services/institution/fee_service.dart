import 'dart:convert';
import '../../core/starlight_http.dart';
import '../../core/constants.dart';

class FeeService {
  final String _baseUrl = "${StarlightConstants.apiBaseUrl}/fee";

  Future<void> saveVoucherStructure(Map<String, dynamic> payload) async {
    final response = await StarlightHttp.post(
      Uri.parse("$_baseUrl/voucher/sync"),
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      throw Exception(error['detail'] ?? "Voucher Architect: Sync Failed");
    }
  }

  Future<List<dynamic>> getVoucherHistory() async {
    final response = await StarlightHttp.get(
      Uri.parse("$_baseUrl/voucher/history"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Fee Engine: History Retrieval Failed");
    }
  }
}
