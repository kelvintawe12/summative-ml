import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:ranch_conservation_predictor/services/predict_service.dart';

void main() {
  test('PredictService returns decoded JSON on 200', () async {
    final mockClient = MockClient((request) async {
      return http.Response(json.encode({'predicted_weight_gain_lbs': 55}), 200);
    });

    final service = PredictService();
    final resp = await service.predict(
      initialWeight: 600,
      daysGrazed: 120,
      year: 2025,
      treatment: 'light',
      pasture: '23W',
      client: mockClient,
    );

    expect(resp['predicted_weight_gain_lbs'], 55);
  });

  test('PredictService throws on non-200', () async {
    final mockClient = MockClient((request) async {
      return http.Response('Server error', 500);
    });

    final service = PredictService();
    expect(
      () => service.predict(
        initialWeight: 600,
        daysGrazed: 120,
        year: 2025,
        treatment: 'light',
        pasture: '23W',
        client: mockClient,
      ),
      throwsA(isA<Exception>()),
    );
  });
}
