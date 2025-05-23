import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

import 'device_data_screen.dart';

class BluetoothScannerScreen extends StatefulWidget {
  @override
  _BluetoothScannerScreenState createState() => _BluetoothScannerScreenState();
}

class _BluetoothScannerScreenState extends State<BluetoothScannerScreen> {
  List<ScanResult> scanResults = [];
  StreamSubscription<List<ScanResult>>? scanSubscription;
  StreamSubscription<BluetoothAdapterState>? adapterStateSubscription;
  StreamSubscription<BluetoothConnectionState>? connectionSubscription;
  BluetoothDevice? connectedDevice;

  @override
  void initState() {
    super.initState();
    requestPermissions();
    handleBluetoothState();
  }

  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.locationWhenInUse
      ].request();
    }
  }

  void handleBluetoothState() {
    adapterStateSubscription = FlutterBluePlus.adapterState.listen((state) {
      if (state == BluetoothAdapterState.on) {
        startScan();
      } else {
        print("Bluetooth is off.");
      }
    });

    if (!kIsWeb && Platform.isAndroid) {
      FlutterBluePlus.turnOn();
    }
  }

  void startScan() async {
    scanResults.clear();
    scanSubscription = FlutterBluePlus.onScanResults.listen((results) {
      if (results.isNotEmpty) {
        setState(() {
          scanResults = results;
        });
      }
    }, onError: (e) => print("Scan Error: $e"));

    FlutterBluePlus.cancelWhenScanComplete(scanSubscription!);

    await FlutterBluePlus.startScan(timeout: Duration(seconds: 15));
    await FlutterBluePlus.isScanning.where((val) => val == false).first;
  }

  void connectToDevice(BluetoothDevice device) async {
    connectionSubscription = device.connectionState.listen((state) async {
      if (state == BluetoothConnectionState.connected) {
        setState(() {
          connectedDevice = device;
        });

        Future.delayed(Duration(milliseconds: 300), () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DeviceDataScreen(device: device),
            ),
          );
        });
      } else if (state == BluetoothConnectionState.disconnected) {
        setState(() {
          connectedDevice = null;
        });
      }
    });

    device.cancelWhenDisconnected(connectionSubscription!, delayed: true, next: true);

    try {
      await device.connect();
      print("Connecting...");
    } catch (e) {
      print("Connection failed: $e");
    }
  }

  void disconnectDevice() async {
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
        setState(() {
          connectedDevice = null;
        });
      } catch (e) {
        print("Disconnect error: $e");
      }
    }
  }

  @override
  void dispose() {
    scanSubscription?.cancel();
    adapterStateSubscription?.cancel();
    connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Bluetooth Scanner',style: TextStyle(color: Colors.white,fontWeight:FontWeight.w500),),
        backgroundColor: Colors.blueGrey,
        centerTitle: true,
      ),
      body: Column(
        children: [
          ElevatedButton(
            onPressed: startScan,
            child: Text('Scan for Devices',style: TextStyle(color: Colors.white,fontWeight:FontWeight.w500),),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: scanResults.length,
              itemBuilder: (context, index) {
                final device = scanResults[index].device;
                bool isConnected = connectedDevice?.id == device.id;
                return ListTile(
                  title: Text(device.name.isNotEmpty ? device.name : "Unknown Device"),
                  subtitle: Text(device.id.toString()),
                  trailing: ElevatedButton(
                    onPressed: isConnected ? disconnectDevice : () => connectToDevice(device),
                    child: Text(isConnected ? "Disconnect" : "Connect",style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
