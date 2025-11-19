import 'dart:convert';
import 'package:http/http.dart' as http;

class PredictService {
  final String endpoint;

  PredictService({this.endpoint = 'https://summative-ml-hliu.onrender.com/predict'});

  /// Sends prediction request to backend. Returns decoded JSON on success.
  Future<Map<String, dynamic>> predict({
    required double initialWeight,
    required int daysGrazed,
    required int year,
    required String treatment,
    required String pasture,
    http.Client? client,
  }) async {
    client ??= http.Client();

    final body = json.encode({
      'initial_weight': initialWeight,
      'days_grazed': daysGrazed,
      'year': year,
      'treatment': treatment,
      'pasture': pasture,
    });

    final response = await client.post(Uri.parse(endpoint), headers: {'Content-Type': 'application/json'}, body: body);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is Map<String, dynamic>) return data;
      return Map<String, dynamic>.from(data);
    }

    // try to decode error body if possible
    try {
      final err = json.decode(response.body);
      throw Exception('HTTP ${response.statusCode}: ${err}');
    } catch (_) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Check whether the API endpoint is reachable.
  /// Returns `true` when a successful response (status 200-399) is received within [timeoutSeconds].
  Future<bool> checkReachable({http.Client? client, int timeoutSeconds = 5}) async {
    client ??= http.Client();
    try {
      // Prefer checking the server root (health) rather than the POST endpoint,
      // because /predict accepts only POST and may return 405 for HEAD/GET.
      final ep = Uri.parse(endpoint);
      final uri = ep.replace(path: '/');
      // Try a HEAD request first — some servers may not support it, fall back to GET.
      final response = await client
          .head(uri)
          .timeout(Duration(seconds: timeoutSeconds), onTimeout: () => http.Response('timeout', 408));

        // If server responds with success (2xx-3xx) or responds 405 (Method Not Allowed)
        // then the host is reachable and the endpoint exists but doesn't accept HEAD/GET.
        if ((response.statusCode >= 200 && response.statusCode < 400) || response.statusCode == 405) return true;

        // Fall back to GET if HEAD didn't return success
        final getResp = await client
            .get(uri)
            .timeout(Duration(seconds: timeoutSeconds), onTimeout: () => http.Response('timeout', 408));
        return getResp.statusCode >= 200 && getResp.statusCode < 400;
    } catch (_) {
      return false;
    }
  }
}
