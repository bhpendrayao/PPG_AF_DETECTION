import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert'; // For jsonDecode
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:typed_data';
import 'globals.dart';

class DeviceDataScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceDataScreen({Key? key, required this.device}) : super(key: key);

  @override
  _DeviceDataScreenState createState() => _DeviceDataScreenState();
}

class _DeviceDataScreenState extends State<DeviceDataScreen> {
  // Data Management
  List<String> displayedData = [];
  List<List<dynamic>> _csvData = [];
  List<double> _ppgValues = [];
  BluetoothCharacteristic? targetCharacteristic;

  // File Handling
  String? csvFilePath;

  // Batch Processing
  bool _isProcessingBatch = false;
  int _batchCounter = 0;

  // Server Communication
  String? _flaskResponse;
  String? _analysisResult; // Extracted result from Flask

  // Chart Configuration
  late TooltipBehavior _tooltipBehavior;
  late ZoomPanBehavior _zoomPanBehavior;
  final int _maxDataPoints = 3500;

  @override
  void initState() {
    super.initState();
    _tooltipBehavior = TooltipBehavior(enable: true);
    _zoomPanBehavior = ZoomPanBehavior(
      enablePinching: true,
      enableDoubleTapZooming: true,
    );
    _requestStoragePermission();
    _connectToDevice();
  }

  Future<void> _requestStoragePermission() async {
    if (await Permission.storage.request().isGranted) {
      print("Storage permission granted.");
    }
  }

  void _connectToDevice() async {
    await widget.device.connect();
    List<BluetoothService> services = await widget.device.discoverServices();

    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.uuid.toString().toLowerCase().contains("2a37")) {
          targetCharacteristic = characteristic;
          _startListening();
        }
      }
    }
  }

  Future<void> _saveCSV() async {
    try {
      Directory directory = await getApplicationDocumentsDirectory();
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String filePath = '${directory.path}/ppg_batch_${_batchCounter}_$timestamp.csv';
      File file = File(filePath);
      String csvData = const ListToCsvConverter().convert(_csvData);
      await file.writeAsString(csvData, flush: true);

      setState(() {
        csvFilePath = filePath;
      });

      print("CSV saved at: $filePath");
    } catch (e) {
      print("Error saving CSV: $e");
    }
  }

  Future<void> _shareCSV() async {
    if (csvFilePath == null) return;
    await Share.shareXFiles([XFile(csvFilePath!)], text: "PPG Data Batch #$_batchCounter");
  }

  Future<void> _sendCSVFile() async {
    if (csvFilePath == null) return;

    try {
      var uri = Uri.parse("${Global().serverIP}/upload_csv");
      var file = File(csvFilePath!);
      var request = http.MultipartRequest("POST", uri)
        ..files.add(await http.MultipartFile.fromPath("file", file.path));

      print("Sending Batch #$_batchCounter to Flask...");

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      // Parse JSON response
      var jsonResponse = jsonDecode(responseData);

      setState(() {
        _flaskResponse = responseData;
        _analysisResult = jsonResponse['result']; // Extract the result field
      });

      print("Flask Response: $_flaskResponse");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Analysis Result: $_analysisResult"),
          duration: Duration(seconds: 5),
        ),
      );

    } catch (e) {
      print("Error sending CSV: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to get analysis: ${e.toString()}")),
      );
    }
  }

  void _startListening() async {
    if (targetCharacteristic == null) return;
    await targetCharacteristic!.setNotifyValue(true);

    targetCharacteristic!.value.listen((List<int> value) async {
      try {
        if (_isProcessingBatch || value.length != 4) return;

        ByteData byteData = ByteData.sublistView(Uint8List.fromList(value));
        double ppgValue = byteData.getFloat32(0, Endian.little);

        setState(() {
          // Add new data
          displayedData.add(ppgValue.toStringAsFixed(6));
          _csvData.add([ppgValue]);
          _ppgValues.add(ppgValue);
        });

        // Process batch when reaching threshold
        if (_csvData.length >= _maxDataPoints && !_isProcessingBatch) {
          _isProcessingBatch = true;
          _batchCounter++;

          await _saveCSV();
          await _sendCSVFile();

          setState(() {
            _csvData.clear(); // Clear CSV data
            _ppgValues.clear(); // Clear plot data
            displayedData.clear(); // Clear displayed data
          });

          _isProcessingBatch = false;
        }
      } catch (e) {
        print("Error processing data: $e");
      }
    });
  }

  @override
  void dispose() {
    widget.device.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("PPG Data Collector"),
        actions: [
          Chip(label: Text("Batch: $_batchCounter")),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Real-time Plot (60% of screen)
            Expanded(
              flex: 6,
              child: SfCartesianChart(
                tooltipBehavior: _tooltipBehavior,
                zoomPanBehavior: _zoomPanBehavior,
                primaryXAxis: NumericAxis(
                  title: AxisTitle(text: "Data Points"),
                ),
                primaryYAxis: NumericAxis(
                  title: AxisTitle(text: "PPG Value"),
                ),
                series: <LineSeries<double, int>>[
                  LineSeries<double, int>(
                    dataSource: _ppgValues,
                    xValueMapper: (value, index) => index,
                    yValueMapper: (value, _) => value,
                    name: 'PPG',
                    color: Colors.red,
                    animationDuration: 0,
                  ),
                ],
              ),
            ),

            // Results Section (40% of screen)
            Expanded(
              flex: 4,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Analysis Result Card
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            "Latest Analysis",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            _analysisResult ?? "No results yet",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (_analysisResult != null)
                            Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text(
                                "From Batch #$_batchCounter",
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Buttons Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _saveCSV,
                        child: Text("Save CSV"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _shareCSV,
                        child: Text("Share CSV"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
