import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import 'services/predict_service.dart';
import 'services/prediction_storage.dart';
import 'utils/validators.dart';

// Shared in-memory notifier so screens see updates immediately
final ValueNotifier<List<Map<String, dynamic>>> predictionStore = ValueNotifier<List<Map<String, dynamic>>>([]);

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
      home: const MainShell(),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with SingleTickerProviderStateMixin {
  int _index = 0;
  late final AnimationController _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
  // Key to access PredictorContent state (used to show header actions in AppBar)
  final GlobalKey<_PredictorContentState> _predictorKey = GlobalKey<_PredictorContentState>();

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titles = ['Predict', 'History', 'Charts'];
    return Stack(
      children: [
        // flowing waves animated background
        AnimatedBuilder(
          animation: _bgController,
          builder: (ctx, child) {
            final t = _bgController.value;
            return CustomPaint(
              painter: _WavePainter(t),
              child: Container(),
            );
          },
        ),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.white.withOpacity(0.9),
            foregroundColor: const Color(0xFF3D2817),
            elevation: 2,
            toolbarHeight: 44, // compact header
            // Hide the top label on the Predict screen (index 0)
            title: _index == 0 ? const SizedBox.shrink() : Text(titles[_index], style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: _index == 0 ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _index = 0)),
            bottom: _index == 0
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(86),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Builder(builder: (ctx) {
                        final s = _predictorKey.currentState;
                        final apiReachable = s?.apiReachable ?? false;
                        final loading = s?.loading ?? false;
                        final predictions = s?.predictions ?? <Map<String, dynamic>>[];
                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(color: const Color(0xFF3D2817), borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.all(8),
                                  child: const Icon(Icons.grass, color: Colors.white, size: 26),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('RanchGain', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(apiReachable ? 'API: Reachable' : 'API: Unreachable', style: TextStyle(fontSize: 12, color: apiReachable ? Colors.green[700] : Colors.red[700])),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Tooltip(message: 'Quick Predict', child: IconButton(icon: const Icon(Icons.flash_on, color: Color(0xFF2E7D32)), onPressed: loading ? null : () => _predictorKey.currentState?._onPredict())),
                                    Tooltip(message: 'Load Last', child: IconButton(icon: const Icon(Icons.history_toggle_off), onPressed: () => _predictorKey.currentState?._loadLastPrediction())),
                                    Tooltip(message: 'Export Last', child: IconButton(icon: const Icon(Icons.share), onPressed: () {
                                      final last = predictions.isNotEmpty ? predictions.first : null;
                                      if (last != null) Share.share(jsonEncode(last), subject: 'Last Prediction');
                                    })),
                                    Tooltip(message: 'Clear All', child: IconButton(icon: const Icon(Icons.delete_forever, color: Colors.redAccent), onPressed: predictions.isEmpty ? null : () => _predictorKey.currentState?._clearHistory())),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      }),
                    ),
                  )
                : null,
          ),
          body: IndexedStack(
            index: _index,
            children: [
              PredictorContent(key: _predictorKey, disableInitialApiCheck: false),
              HistoryScreen(),
              ChartsScreen(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Predict'),
              BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Charts'),
            ],
          ),
        ),
      ],
    );
  }
}

class PredictorContent extends StatefulWidget {
  final bool disableInitialApiCheck;
  const PredictorContent({super.key, this.disableInitialApiCheck = false});

  @override
  State<PredictorContent> createState() => _PredictorContentState();
}

class _PredictorContentState extends State<PredictorContent> {
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

  void _loadLastPrediction() {
    if (predictions.isEmpty) return;
    final last = predictions.first;
    final inputs = last['inputs'] as Map<String, dynamic>?;
    if (inputs != null) {
      setState(() {
        weightCtrl.text = (inputs['initialWeight'] ?? weightCtrl.text).toString();
        daysCtrl.text = (inputs['daysGrazed'] ?? daysCtrl.text).toString();
        yearCtrl.text = (inputs['year'] ?? yearCtrl.text).toString();
        treatment = (inputs['treatment'] ?? treatment).toString();
        pasture = (inputs['pasture'] ?? pasture).toString();
      });
    }
  }

  Future<void> _loadHistory() async {
    try {
      final loaded = await PredictionStorage.load();
      if (loaded.isNotEmpty) {
        setState(() {
          predictions = loaded;
          predictionStore.value = List<Map<String, dynamic>>.from(predictions);
        });
      }
    } catch (_) {}
  }

  Future<void> _saveHistory() async {
    try {
      await PredictionStorage.save(predictions);
      // publish to shared notifier so other screens update immediately
      predictionStore.value = List<Map<String, dynamic>>.from(predictions);
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    setState(() => predictions = []);
    // persist and notify
    await PredictionStorage.clear();
    await _loadHistory();
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
    final entries = <Map<String, dynamic>>[];
    for (var i = 0; i < predictions.length; i++) {
      final g = predictions[i]['gain'];
      final y = (g is num) ? g.toDouble() : double.tryParse(g?.toString() ?? '') ?? double.nan;
      if (!y.isNaN) {
        entries.add({'value': y, 'label': predictions[i]['timestamp'] ?? ''});
      }
    }

    if (entries.isEmpty) {
      return SizedBox(
        height: 140,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.bar_chart, size: 36, color: Colors.black26),
                SizedBox(height: 8),
                Text('No chart data — make a prediction', style: TextStyle(color: Colors.black45)),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            color: Colors.transparent,
            child: _HistogramChart(entries: entries),
          ),
        ),
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const SizedBox(height: 8),
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
                      Expanded(child: const Text('Prediction Chart', style: TextStyle(fontWeight: FontWeight.bold))),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'History',
                            onPressed: predictions.isEmpty ? null : _showHistoryModal,
                            icon: const Icon(Icons.history),
                          ),
                          IconButton(
                            tooltip: 'Clear',
                            onPressed: predictions.isEmpty ? null : _clearHistory,
                            icon: const Icon(Icons.delete_forever),
                          ),
                        ],
                      )
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildChart(),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: Text('Points: ${predictions.length}', key: ValueKey<int>(predictions.length), style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
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
    );
  }
}

// (Removed unused simple line painter — histogram is used now.)

// Top-level histogram widget (moved here so it's a proper top-level declaration)
class _HistogramChart extends StatefulWidget {
  final List<Map<String, dynamic>> entries; // each entry: {'value': double, 'label': String}
  const _HistogramChart({Key? key, required this.entries}) : super(key: key);

  @override
  State<_HistogramChart> createState() => _HistogramChartState();
}

class _HistogramChartState extends State<_HistogramChart> with SingleTickerProviderStateMixin {
  int? _hoveredIndex;
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    final values = widget.entries.map((e) => e['value'] as double).toList();
    final labels = widget.entries.map((e) => (e['label'] ?? '') as String).toList();
    final maxVal = values.isEmpty ? 1.0 : values.reduce(max);
    final minVal = values.isEmpty ? 0.0 : values.reduce(min);
    final span = (maxVal - minVal) == 0 ? (maxVal == 0 ? 1.0 : maxVal) : (maxVal - minVal);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Y-axis with ticks and labels
        SizedBox(
          width: 56,
          child: Column(
            children: [
              const SizedBox(height: 0),
              Expanded(
                child: LayoutBuilder(builder: (ctx, axisConstraints) {
                  const tickCount = 5;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(tickCount, (i) {
                      final v = maxVal - i * (span / (tickCount - 1));
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Text(v.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                      );
                    }),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Chart area
        Expanded(
          child: LayoutBuilder(builder: (context, constraints) {
            final barGap = 6.0;
            final totalWidth = constraints.maxWidth;
            final availableForBars = max(0.0, totalWidth - (values.length - 1) * barGap);
            final unitWidth = availableForBars / values.length;
            final barMaxHeight = constraints.maxHeight; // chart area height

            // Build bars as Expanded children to guarantee they fit
            final children = <Widget>[];
            for (var i = 0; i < values.length; i++) {
              final v = values[i];
              final heightFactor = (v - minVal) / span;
              final barHeight = (barMaxHeight * heightFactor).clamp(4.0, barMaxHeight);
              final isHovered = _hoveredIndex == i;
              final isSelected = _selectedIndex == i;

              children.add(Expanded(
                child: MouseRegion(
                  onEnter: (_) => setState(() => _hoveredIndex = i),
                  onExit: (_) => setState(() => _hoveredIndex = null),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedIndex = i == _selectedIndex ? null : i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.7,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeInOut,
                            height: isSelected ? barHeight + 8 : barHeight,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.green.shade700 : (isHovered ? Colors.green.shade400 : Colors.green.shade300),
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: isSelected ? [BoxShadow(color: Colors.black26, blurRadius: 6, offset: const Offset(0, 3))] : [],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(values[i].toStringAsFixed(0), textAlign: TextAlign.center, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),
                ),
              ));

              if (i != values.length - 1) children.add(SizedBox(width: barGap));
            }

            // Tooltip position calculations based on unitWidth
            double tooltipLeft = 0;
            double tooltipTop = 0;
            String tooltipText = '';
            const tooltipMaxW = 140.0;
            if ((_hoveredIndex ?? _selectedIndex) != null) {
              final idx = _hoveredIndex ?? _selectedIndex!;
              final x = idx * (unitWidth + barGap);
              final v = values[idx];
              final h = (barMaxHeight * ((v - minVal) / span)).clamp(4.0, barMaxHeight);
              final centerX = x + unitWidth / 2;
              final rawLeft = centerX - tooltipMaxW / 2;
              final leftClamped = rawLeft.clamp(0.0, totalWidth - tooltipMaxW);
              tooltipLeft = leftClamped;
              tooltipTop = (barMaxHeight - h - 44).clamp(0.0, constraints.maxHeight - 30);
              tooltipText = '${labels[idx]}\n${v.toStringAsFixed(1)} lbs';
            }

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                // Ensure the row fits exactly the available width
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: SizedBox(
                      width: totalWidth,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: children),
                    ),
                  ),
                ),
                if ((_hoveredIndex ?? _selectedIndex) != null)
                  Positioned(
                    left: tooltipLeft,
                    top: tooltipTop,
                    child: IgnorePointer(
                      ignoring: true,
                      child: Material(
                        elevation: 4,
                        color: Colors.transparent,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 160),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6)]),
                          child: Text(tooltipText, style: const TextStyle(fontSize: 11)),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }
}

// Simple History screen — loads saved predictions and shows a list
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _search = '';
  final Set<String> _selectedTreatments = {};
  final Set<String> _selectedPastures = {};
  DateTime? _startDate;
  DateTime? _endDate;
  bool _sortDesc = true;
  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (predictionStore.value.isNotEmpty) return;
    try {
      final loaded = await PredictionStorage.load();
      if (loaded.isNotEmpty) predictionStore.value = loaded;
    } catch (_) {}
  }
  void _showDetail(Map<String, dynamic> e) {
    showModalBottomSheet<void>(context: context, builder: (_) {
      return Padding(
        padding: EdgeInsets.fromLTRB(16,16,16, MediaQuery.of(context).viewInsets.bottom + 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Prediction', style: TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop())]),
              const SizedBox(height:8),
              Text('When: ${e['timestamp']}'),
              const SizedBox(height:8),
              Text('Inputs: ${jsonEncode(e['inputs'])}'),
              const SizedBox(height:8),
              Text('Gain: ${e['gain'] ?? 'N/A'}'),
              const SizedBox(height:12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton.icon(onPressed: () { Clipboard.setData(ClipboardData(text: jsonEncode(e))); Navigator.of(context).pop(); }, icon: const Icon(Icons.copy), label: const Text('Copy')),
                const SizedBox(width:8),
                TextButton.icon(onPressed: () { Navigator.of(context).pop(); Share.share(jsonEncode(e), subject: 'Prediction'); }, icon: const Icon(Icons.share), label: const Text('Share')),
              ])
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: predictionStore,
      builder: (context, list, _) {
        final treatments = <String>{};
        final pastures = <String>{};
        for (var e in list) {
          final inputs = e['inputs'] as Map<String, dynamic>?;
          if (inputs != null) {
            if (inputs['treatment'] != null) treatments.add(inputs['treatment'].toString());
            if (inputs['pasture'] != null) pastures.add(inputs['pasture'].toString());
          }
        }

        List<Map<String, dynamic>> filtered = List.from(list);
        if (_selectedTreatments.isNotEmpty) {
          filtered = filtered.where((e) => _selectedTreatments.contains((e['inputs']?['treatment'] ?? '').toString())).toList();
        }
        if (_selectedPastures.isNotEmpty) {
          filtered = filtered.where((e) => _selectedPastures.contains((e['inputs']?['pasture'] ?? '').toString())).toList();
        }
        if (_startDate != null || _endDate != null) {
          filtered = filtered.where((e) {
            final ts = e['timestamp'] ?? '';
            try {
              final dt = DateTime.parse(ts).toLocal();
              if (_startDate != null && dt.isBefore(_startDate!)) return false;
              if (_endDate != null && dt.isAfter(_endDate!.add(const Duration(days:1)))) return false;
              return true;
            } catch (_) {
              return false;
            }
          }).toList();
        }
        if (_search.isNotEmpty) {
          filtered = filtered.where((e) {
            final ts = (e['timestamp'] ?? '').toString();
            final sn = e['gain']?.toString() ?? '';
            return ts.contains(_search) || sn.contains(_search) || jsonEncode(e['inputs'] ?? {}).contains(_search);
          }).toList();
        }
        filtered.sort((a, b) {
          final at = DateTime.tryParse(a['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bt = DateTime.tryParse(b['timestamp'] ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
          return _sortDesc ? bt.compareTo(at) : at.compareTo(bt);
        });

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search by timestamp, value, or inputs', border: OutlineInputBorder()),
                      onChanged: (v) => setState(() => _search = v.trim()),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: Icon(_sortDesc ? Icons.arrow_downward : Icons.arrow_upward), onPressed: () => setState(() => _sortDesc = !_sortDesc)),
                  const SizedBox(width: 4),
                  // Date range picker
                  TextButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final initialStart = _startDate ?? now.subtract(const Duration(days: 30));
                      final initialEnd = _endDate ?? now;
                      final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(now.year + 1), initialDateRange: DateTimeRange(start: initialStart, end: initialEnd));
                      if (picked != null) setState(() {
                        _startDate = picked.start;
                        _endDate = picked.end;
                      });
                    },
                    icon: const Icon(Icons.date_range),
                    label: Text(_startDate == null ? 'Date Range' : '${_startDate!.toLocal().toString().split(' ')[0]} — ${_endDate!.toLocal().toString().split(' ')[0]}'),
                  ),
                ],
              ),
            ),
            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text('Filters:'),
                  const SizedBox(width: 8),
                  Wrap(
                    spacing: 6,
                    children: [
                      FilterChip(label: const Text('All Treatments'), selected: _selectedTreatments.isEmpty, onSelected: (_) => setState(() => _selectedTreatments.clear())),
                      ...treatments.map((t) => FilterChip(label: Text(t), selected: _selectedTreatments.contains(t), onSelected: (sel) => setState(() => sel ? _selectedTreatments.add(t) : _selectedTreatments.remove(t)))).toList(),
                      const SizedBox(width: 8),
                      FilterChip(label: const Text('All Pastures'), selected: _selectedPastures.isEmpty, onSelected: (_) => setState(() => _selectedPastures.clear())),
                      ...pastures.map((p) => FilterChip(label: Text(p), selected: _selectedPastures.contains(p), onSelected: (sel) => setState(() => sel ? _selectedPastures.add(p) : _selectedPastures.remove(p)))).toList(),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No matching history'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final e = filtered[i];
                        final ts = e['timestamp'] ?? '';
                        String prettyTime;
                        try {
                          prettyTime = _formatRelative(DateTime.parse(ts).toLocal());
                        } catch (_) {
                          prettyTime = ts.toString();
                        }
                        return TweenAnimationBuilder(
                          tween: Tween<double>(begin: 0.96, end: 1.0),
                          duration: Duration(milliseconds: 260 + (i % 6) * 40),
                          builder: (context, double scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(e['gain'] != null ? '${e['gain']} lbs' : 'No gain', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                    Text(prettyTime, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text('Inputs: ' + (jsonEncode(e['inputs'] ?? {})), style: const TextStyle(fontSize: 12)),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(icon: const Icon(Icons.visibility), onPressed: () => _showDetail(e)),
                                    IconButton(icon: const Icon(Icons.copy), onPressed: () { Clipboard.setData(ClipboardData(text: jsonEncode(e))); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied'))); }),
                                    IconButton(icon: const Icon(Icons.share), onPressed: () => Share.share(jsonEncode(e), subject: 'Prediction')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  String _formatRelative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';
  }
}

// Charts screen — renders histogram using saved history
class ChartsScreen extends StatefulWidget {
  const ChartsScreen({super.key});
  @override
  State<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends State<ChartsScreen> {
  final Set<String> _selectedTreatments = {};
  final Set<String> _selectedPastures = {};
  DateTime? _startDate;
  DateTime? _endDate;
  String _agg = 'mean';

  @override
  void initState() {
    super.initState();
    _ensureLoaded();
  }

  Future<void> _ensureLoaded() async {
    if (predictionStore.value.isNotEmpty) return;
    try {
      final loaded = await PredictionStorage.load();
      if (loaded.isNotEmpty) predictionStore.value = loaded;
    } catch (_) {}
  }

  double _mean(List<double> values) => values.isEmpty ? double.nan : values.reduce((a, b) => a + b) / values.length;
  double _median(List<double> values) {
    if (values.isEmpty) return double.nan;
    final s = List<double>.from(values)..sort();
    final mid = s.length ~/ 2;
    return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: predictionStore,
      builder: (context, list, _) {
        final treatments = <String>{};
        final pastures = <String>{};
        final raw = <Map<String, dynamic>>[];
        for (var e in list) {
          final inputs = e['inputs'] as Map<String, dynamic>?;
          if (inputs != null) {
            if (inputs['treatment'] != null) treatments.add(inputs['treatment'].toString());
            if (inputs['pasture'] != null) pastures.add(inputs['pasture'].toString());
          }
          final g = e['gain'];
          final y = (g is num) ? g.toDouble() : double.tryParse(g?.toString() ?? '') ?? double.nan;
          if (!y.isNaN) raw.add({'value': y, 'label': e['timestamp'] ?? '', 'inputs': e['inputs']});
        }

        // Apply filters
        var filtered = raw.where((e) {
          final inputs = (e['inputs'] ?? {}) as Map<String, dynamic>;
          if (_selectedTreatments.isNotEmpty && !_selectedTreatments.contains((inputs['treatment'] ?? '').toString())) return false;
          if (_selectedPastures.isNotEmpty && !_selectedPastures.contains((inputs['pasture'] ?? '').toString())) return false;
          if (_startDate != null || _endDate != null) {
            try {
              final dt = DateTime.parse(e['label']).toLocal();
              if (_startDate != null && dt.isBefore(_startDate!)) return false;
              if (_endDate != null && dt.isAfter(_endDate!.add(const Duration(days:1)))) return false;
            } catch (_) {
              return false;
            }
          }
          return true;
        }).toList();

        final values = filtered.map((e) => e['value'] as double).toList();
        if (values.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(12), child: Text('No chart data — make a prediction first.')));

        final mean = _mean(values);
        final median = _median(values);
        final count = values.length;

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // Controls: filters / stats / actions
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text('Charts — $count points • Mean: ${mean.isNaN ? '-' : mean.toStringAsFixed(1)} • Median: ${median.isNaN ? '-' : median.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          IconButton(onPressed: () async {
                            final prefs = await SharedPreferences.getInstance();
                            final s = prefs.getString('prediction_history');
                            if (s != null && s.isNotEmpty) {
                              final decoded = jsonDecode(s) as List<dynamic>;
                              predictionStore.value = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
                            }
                          }, icon: const Icon(Icons.refresh)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Date range + aggregation
                      Row(
                        children: [
                          TextButton.icon(onPressed: () async {
                            final now = DateTime.now();
                            final initial = DateTimeRange(start: _startDate ?? now.subtract(const Duration(days: 30)), end: _endDate ?? now);
                            final picked = await showDateRangePicker(context: context, firstDate: DateTime(2000), lastDate: DateTime(now.year + 1), initialDateRange: initial);
                            if (picked != null) setState(() { _startDate = picked.start; _endDate = picked.end; });
                          }, icon: const Icon(Icons.date_range), label: Text(_startDate == null ? 'Date range' : '${_startDate!.toLocal().toString().split(' ')[0]} — ${_endDate!.toLocal().toString().split(' ')[0]}')),
                          const SizedBox(width: 8),
                          DropdownButton<String>(value: _agg, items: const [DropdownMenuItem(value: 'mean', child: Text('Mean')), DropdownMenuItem(value: 'median', child: Text('Median'))], onChanged: (v) => setState(() => _agg = v ?? 'mean')),
                          const Spacer(),
                          TextButton.icon(onPressed: () {
                            setState(() { _selectedPastures.clear(); _selectedTreatments.clear(); _startDate = null; _endDate = null; });
                          }, icon: const Icon(Icons.clear), label: const Text('Clear')),
                          const SizedBox(width: 8),
                          TextButton.icon(onPressed: () {
                            // export filtered data as CSV
                            final csv = StringBuffer();
                            csv.writeln('timestamp,gain');
                            for (var r in filtered) csv.writeln('${r['label']},${(r['value'] as double).toStringAsFixed(2)}');
                            Share.share(csv.toString(), subject: 'Chart data CSV');
                          }, icon: const Icon(Icons.download), label: const Text('Export')),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Text('Filter:'),
                            const SizedBox(width: 8),
                            Wrap(spacing: 6, children: [
                              FilterChip(label: const Text('All Treatments'), selected: _selectedTreatments.isEmpty, onSelected: (_) => setState(() => _selectedTreatments.clear())),
                              ...treatments.map((t) => FilterChip(label: Text(t), selected: _selectedTreatments.contains(t), onSelected: (sel) => setState(() => sel ? _selectedTreatments.add(t) : _selectedTreatments.remove(t)))).toList(),
                              const SizedBox(width: 8),
                              FilterChip(label: const Text('All Pastures'), selected: _selectedPastures.isEmpty, onSelected: (_) => setState(() => _selectedPastures.clear())),
                              ...pastures.map((p) => FilterChip(label: Text(p), selected: _selectedPastures.contains(p), onSelected: (sel) => setState(() => sel ? _selectedPastures.add(p) : _selectedPastures.remove(p)))).toList(),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Chart area
              Expanded(child: _HistogramChart(entries: filtered.map((e) => {'value': e['value'], 'label': e['label']}).toList())),
            ],
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = Colors.white.withOpacity(0.12);
    final paint2 = Paint()..color = Colors.white.withOpacity(0.08);
    final path1 = Path();
    final path2 = Path();
    final h = size.height;
    final w = size.width;

    // Wave 1
    path1.moveTo(0, h * 0.6);
    for (double x = 0; x <= w; x += 1) {
      final dx = x / w * 2 * pi;
      final y = h * 0.5 + sin(dx * 1.5 + t * 2 * pi) * 20;
      path1.lineTo(x, y);
    }
    path1.lineTo(w, h);
    path1.lineTo(0, h);
    path1.close();

    // Wave 2 (slower, offset)
    path2.moveTo(0, h * 0.7);
    for (double x = 0; x <= w; x += 1) {
      final dx = x / w * 2 * pi;
      final y = h * 0.65 + sin(dx * 1.2 + t * 2 * pi + 1.0) * 14;
      path2.lineTo(x, y);
    }
    path2.lineTo(w, h);
    path2.lineTo(0, h);
    path2.close();

    canvas.drawPath(path2, paint2);
    canvas.drawPath(path1, paint1);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => oldDelegate.t != t;
}