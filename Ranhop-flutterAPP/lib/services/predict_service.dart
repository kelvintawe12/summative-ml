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

    // Log full response for easier debugging (status + body)
    try {
      print('-- PredictService.predict response status: ${response.statusCode}');
      print('-- PredictService.predict response body: ${response.body}');
    } catch (_) {}

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
  /// Check whether the API endpoint is reachable by calling `/health`.
  /// Retries with exponential backoff up to [maxAttempts].
  Future<bool> checkReachable({http.Client? client, int timeoutSeconds = 3, int maxAttempts = 3}) async {
    client ??= http.Client();
    final ep = Uri.parse(endpoint);
    // Use /health endpoint which is GET-friendly
    final uri = ep.replace(path: '/health');

    int attempt = 0;
    while (attempt < maxAttempts) {
      attempt += 1;
      try {
        // First try /health
        final healthResp = await client
            .get(uri)
            .timeout(Duration(seconds: timeoutSeconds), onTimeout: () => http.Response('timeout', 408));

        try {
          print('-- PredictService.checkReachable attempt $attempt /health status: ${healthResp.statusCode}');
        } catch (_) {}

        if (healthResp.statusCode >= 200 && healthResp.statusCode < 400) return true;

        // If /health is not found (404), fall back to root /
        if (healthResp.statusCode == 404) {
          final rootUri = ep.replace(path: '/');
          final rootResp = await client
              .get(rootUri)
              .timeout(Duration(seconds: timeoutSeconds), onTimeout: () => http.Response('timeout', 408));
          try {
            print('-- PredictService.checkReachable attempt $attempt / status: ${rootResp.statusCode}');
          } catch (_) {}
          if (rootResp.statusCode >= 200 && rootResp.statusCode < 400) return true;
        }
      } catch (_) {
        // swallow and retry after backoff
      }

      // Exponential backoff (ms)
      final backoffMs = 200 * (1 << (attempt - 1));
      await Future.delayed(Duration(milliseconds: backoffMs));
    }

    return false;
  }

  /// Fetch the health JSON from `/health` (or throw on non-200).
  Future<Map<String, dynamic>> getHealth({http.Client? client, int timeoutSeconds = 5}) async {
    client ??= http.Client();
    final ep = Uri.parse(endpoint);
    final uri = ep.replace(path: '/health');

    final resp = await client.get(uri).timeout(Duration(seconds: timeoutSeconds), onTimeout: () => http.Response('timeout', 408));
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      final data = json.decode(resp.body);
      if (data is Map<String, dynamic>) return data;
      return Map<String, dynamic>.from(data);
    }

    throw Exception('Health check failed: HTTP ${resp.statusCode} - ${resp.body}');
  }
}
