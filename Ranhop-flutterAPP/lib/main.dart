import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'services/predict_service.dart';
import 'utils/validators.dart';

void main() => runApp(const RanchApp());

class RanchApp extends StatelessWidget {
  const RanchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RanchGain • Sustainable Ranching',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF3D2817), // Rich brown
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF8B4513),
          secondary: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const PredictorPage(),
    );
  }
}

class PredictorPage extends StatefulWidget {
  final bool disableInitialApiCheck;
  const PredictorPage({super.key, this.disableInitialApiCheck = false});

  @override
  State<PredictorPage> createState() => _PredictorPageState();
}

class _PredictorPageState extends State<PredictorPage> {
  final _formKey = GlobalKey<FormState>();
  final weightCtrl = TextEditingController(text: '680');
  final daysCtrl = TextEditingController(text: '140');
  final yearCtrl = TextEditingController(text: '2025');
  String treatment = 'light';
  String pasture = '23W';
  String result = '';
  bool loading = false;

  final PredictService _service = PredictService();
  bool apiReachable = false;

  Future<void> _onPredict() async {
    if (!_formKey.currentState!.validate()) return;
    if (!apiReachable) {
      setState(() => result = 'API not reachable — please check connection');
      return;
    }

    setState(() {
      loading = true;
      result = '';
    });

    final double initialWeight = double.parse(weightCtrl.text);
    final int daysGrazed = int.parse(daysCtrl.text);
    final int year = int.parse(yearCtrl.text);

    try {
      final resp = await _service.predict(
        initialWeight: initialWeight,
        daysGrazed: daysGrazed,
        year: year,
        treatment: treatment,
        pasture: pasture,
        client: http.Client(),
      );
      // Log the raw response map for debugging
      try {
        print('-- App received response: $resp');
      } catch (_) {}

      final gain = resp['predicted_weight_gain_lbs'] ?? resp['predicted_gain'] ?? resp['predicted'];
      setState(() {
        if (gain != null) {
          result = 'Predicted Gain: ${gain.toString()} lbs';
        } else {
          result = 'Prediction received but unexpected response format.';
        }
      });
    } catch (e) {
      // Show SnackBar with error and retry option for predictive errors
      setState(() => result = 'Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prediction failed: $e'),
          action: SnackBarAction(label: 'Retry', onPressed: _onPredict),
        ),
      );
    } finally {
      setState(() => loading = false);
    }
  }

  Future<void> _checkApi() async {
    setState(() => apiReachable = false);
    try {
      final ok = await _service.checkReachable(client: http.Client());
      setState(() => apiReachable = ok);
      if (!ok) {
        // Show a SnackBar with Retry when API is unreachable
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('API unreachable'),
            action: SnackBarAction(label: 'Retry', onPressed: _checkApi),
          ),
        );
      }
    } catch (_) {
      setState(() => apiReachable = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('API unreachable'),
          action: SnackBarAction(label: 'Retry', onPressed: _checkApi),
        ),
      );
    }
  }

  @override
  void dispose() {
    weightCtrl.dispose();
    daysCtrl.dispose();
    yearCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Check API reachability on startup
    if (!widget.disableInitialApiCheck) _checkApi();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cattle Gain Predictor'),
        backgroundColor: const Color(0xFF3D2817),
        actions: [
          // API reachability indicator and manual check
          IconButton(
            tooltip: 'Check API',
            icon: Icon(apiReachable ? Icons.cloud_done : Icons.cloud_off, color: apiReachable ? Colors.greenAccent : Colors.redAccent),
            onPressed: _checkApi,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const SizedBox(height: 8),
            const Text(
              'USDA CPER Sustainable Ranching',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF5D4037)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('API:'),
                const SizedBox(width: 8),
                Icon(apiReachable ? Icons.check_circle : Icons.cancel, color: apiReachable ? Colors.green : Colors.red),
                const SizedBox(width: 6),
                Text(apiReachable ? 'Reachable' : 'Unreachable', style: TextStyle(color: apiReachable ? Colors.green[700] : Colors.red[700])),
              ],
            ),
            const SizedBox(height: 8),
            // Header with icon and title
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(color: const Color(0xFF3D2817), borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.all(10),
                  child: const Icon(Icons.grass, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('RanchGain', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Sustainable Ranching Predictor', style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: weightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Initial Weight (lbs)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.monitor_weight),
                        ),
                        validator: validateWeight,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Days Grazed',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        validator: validateDays,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: yearCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Year',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.event),
                        ),
                        validator: validateYear,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: treatment,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Grazing Treatment'),
                        items: ['light', 'moderate', 'heavy']
                            .map((e) => DropdownMenuItem(value: e, child: Text(e.toUpperCase())))
                            .toList(),
                        onChanged: (v) => setState(() => treatment = v ?? treatment),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: pasture,
                        decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'Pasture'),
                        items: ['15E', '23E', '23W']
                            .map((e) => DropdownMenuItem(value: e, child: Text('Pasture $e')))
                            .toList(),
                        onChanged: (v) => setState(() => pasture = v ?? pasture),
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: loading ? null : _onPredict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: loading
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('PREDICT GAIN'),
                      ),
                      const SizedBox(height: 16),
                      if (result.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: result.startsWith('Error') ? Colors.red[50] : Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            result,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: result.startsWith('Error') ? Colors.red[800] : Colors.green[800],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Note: Ensure the API is reachable from your device. For emulator use, host must be accessible.',
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}