import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

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
        primaryColor: const Color(0xFF3D2817),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8B4513), secondary: const Color(0xFF2E7D32)),
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
  Map<String, dynamic>? healthInfo;
  bool healthLoading = false;
  // prediction history (most recent first)
  List<Map<String, dynamic>> predictions = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (!widget.disableInitialApiCheck) _checkApi();
  }

  @override
  void dispose() {
    weightCtrl.dispose();
    daysCtrl.dispose();
    yearCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final s = prefs.getString('prediction_history');
      if (s != null && s.isNotEmpty) {
        final decoded = jsonDecode(s) as List<dynamic>;
        setState(() {
          predictions = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('prediction_history', jsonEncode(predictions));
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    setState(() => predictions = []);
    await _saveHistory();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prediction history cleared')));
  }

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
      try {
        // debug log
        // ignore: avoid_print
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

      final entry = {
        'timestamp': DateTime.now().toIso8601String(),
        'inputs': {
          'initialWeight': initialWeight,
          'daysGrazed': daysGrazed,
          'year': year,
          'treatment': treatment,
          'pasture': pasture,
        },
        'response': resp,
        'gain': gain,
      };
      setState(() => predictions.insert(0, entry));
      await _saveHistory();
      _showPredictionModal(entry);
    } catch (e) {
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

  Future<void> _showPredictionModal(Map<String, dynamic> entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Prediction Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
                const SizedBox(height: 8),
                Text('When: ${entry['timestamp']}'),
                const SizedBox(height: 8),
                const Text('Inputs:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                ...((entry['inputs'] as Map<String, dynamic>).entries.map((e) => Text('${e.key}: ${e.value}'))),
                const SizedBox(height: 10),
                const Text('Result:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(entry['gain'] != null ? '${entry['gain']} lbs' : 'No numeric gain returned'),
                const SizedBox(height: 10),
                const Text('Raw Response:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(entry['response'].toString()),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final jsonText = jsonEncode(entry);
                        await Clipboard.setData(ClipboardData(text: jsonText));
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied prediction JSON to clipboard')));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        final jsonText = jsonEncode(entry);
                        Navigator.of(context).pop();
                        Share.share(jsonText, subject: 'Prediction');
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showHistoryModal() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Prediction History', style: TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              if (predictions.isEmpty)
                const Padding(padding: EdgeInsets.all(12), child: Text('No predictions yet.'))
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: predictions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (ctx, i) {
                      final e = predictions[i];
                      return ListTile(
                        title: Text(e['gain'] != null ? '${e['gain']} lbs' : 'No gain'),
                        subtitle: Text(e['timestamp'] ?? ''),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          Future.delayed(const Duration(milliseconds: 100), () => _showPredictionModal(e));
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _checkApi() async {
    setState(() => apiReachable = false);
    try {
      final ok = await _service.checkReachable(client: http.Client());
      setState(() => apiReachable = ok);
      if (!ok) {
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

  Future<void> _fetchHealth() async {
    setState(() {
      healthLoading = true;
      healthInfo = null;
    });
    try {
      final data = await _service.getHealth(client: http.Client());
      setState(() {
        healthInfo = data;
        apiReachable = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Health fetched')));
    } catch (e) {
      setState(() {
        healthInfo = null;
        apiReachable = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Health fetch failed: $e'), action: SnackBarAction(label: 'Retry', onPressed: _fetchHealth)));
    } finally {
      setState(() => healthLoading = false);
    }
  }

  Widget _buildChart() {
    final values = <double>[];
    for (var i = 0; i < predictions.length; i++) {
      final g = predictions[i]['gain'];
      final y = (g is num) ? g.toDouble() : double.tryParse(g?.toString() ?? '') ?? double.nan;
      if (!y.isNaN) values.add(y);
    }

    if (values.isEmpty) return const SizedBox(height: 80, child: Center(child: Text('No chart data')));

    return SizedBox(
      height: 140,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: CustomPaint(
          painter: _SimpleLineChartPainter(values, lineColor: Colors.green),
          size: Size.infinite,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cattle Gain Predictor'),
        backgroundColor: const Color(0xFF3D2817),
        actions: [
          IconButton(
            tooltip: 'Check API',
            icon: Icon(apiReachable ? Icons.cloud_done : Icons.cloud_off, color: apiReachable ? Colors.greenAccent : Colors.redAccent),
            onPressed: _checkApi,
          ),
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: predictions.isEmpty ? null : _showHistoryModal,
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
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Prediction Chart', style: TextStyle(fontWeight: FontWeight.bold)),
                        Row(children: [
                          TextButton.icon(onPressed: predictions.isEmpty ? null : _showHistoryModal, icon: const Icon(Icons.history), label: const Text('History')),
                          const SizedBox(width: 4),
                          TextButton.icon(onPressed: predictions.isEmpty ? null : _clearHistory, icon: const Icon(Icons.delete_forever), label: const Text('Clear')),
                        ])
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildChart(),
                    const SizedBox(height: 6),
                    Text('Points: ${predictions.length}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('API Health', style: TextStyle(fontWeight: FontWeight.bold)),
                        TextButton.icon(
                          onPressed: healthLoading ? null : _fetchHealth,
                          icon: healthLoading
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.refresh),
                          label: const Text('Fetch'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (healthInfo != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${healthInfo!["status"]}', style: TextStyle(color: healthInfo!["status"] == 'ok' ? Colors.green[700] : Colors.red[700])),
                          const SizedBox(height: 6),
                          Text('Uptime: ${healthInfo!["uptime"] ?? '-'}s'),
                          const SizedBox(height: 6),
                          Text('Version: ${healthInfo!["version"] ?? '-'}'),
                        ],
                      )
                    else
                      const Text('No health info loaded. Tap Fetch to retrieve API status.', style: TextStyle(color: Colors.black54)),
                  ],
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

// Simple custom painter for a small sparkline/line chart (no external packages)
class _SimpleLineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  _SimpleLineChartPainter(this.values, {this.lineColor = Colors.green});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = lineColor..strokeWidth = 2..style = PaintingStyle.stroke;
    final bg = Paint()..color = Colors.grey.withOpacity(0.06);
    canvas.drawRect(Offset.zero & size, bg);

    if (values.isEmpty) return;
    final double minY = values.reduce((a, b) => a < b ? a : b);
    final double maxY = values.reduce((a, b) => a > b ? a : b);
    final yRange = (maxY - minY) == 0 ? 1 : (maxY - minY);

    final stepX = size.width / (values.length - 1);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i * stepX;
      final y = size.height - ((values[i] - minY) / yRange) * size.height;
      if (i == 0) path.moveTo(x, y);
      else path.lineTo(x, y);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = lineColor);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SimpleLineChartPainter oldDelegate) => oldDelegate.values != values || oldDelegate.lineColor != lineColor;
}