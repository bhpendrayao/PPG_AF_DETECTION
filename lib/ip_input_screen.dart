import 'package:flutter/material.dart';
import 'globals.dart';
import 'bluetooth_scanner_screen.dart';

class IPInputScreen extends StatefulWidget {
  @override
  _IPInputScreenState createState() => _IPInputScreenState();
}

class _IPInputScreenState extends State<IPInputScreen> {
  final TextEditingController _ipController = TextEditingController(text: 'http://');
  bool _isValidInput = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _ipController.addListener(_validateInput);
  }

  @override
  void dispose() {
    _ipController.removeListener(_validateInput);
    _ipController.dispose();
    super.dispose();
  }

  void _validateInput() {
    final text = _ipController.text.trim();
    // Basic validation for IP address with port
    final regex = RegExp(
      r'^https?://(\d{1,3}\.){3}\d{1,3}:\d{1,5}$',
      caseSensitive: false,
    );

    setState(() {
      _isValidInput = regex.hasMatch(text);
      _errorMessage = _isValidInput ? '' : 'Please enter a valid IP with port (e.g., http://192.168.1.2:8000)';
    });
  }

  void _saveIPAndNavigate() {
    if (!_isValidInput) {
      setState(() {
        _errorMessage = 'Please enter a valid IP with port (e.g., http://192.168.1.2:8000)';
      });
      return;
    }

    Global().serverIP = _ipController.text.trim();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => BluetoothScannerScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            'IP CONFIGURATION',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          ),
        ),
        backgroundColor: Colors.blueGrey,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // App Icon Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/app_icon.jpg',
                  width: 100,
                  height: 200,
                ),
              ],
            ),
            SizedBox(height: 20),
            // Text Field with http:// pre-filled
            TextField(
              controller: _ipController,
              decoration: InputDecoration(
                labelText: 'Server IP with Port (e.g., 192.168.1.2:8000)',
                errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isValidInput ? _saveIPAndNavigate : null,
              child: Text(
                'Continue',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isValidInput ? Colors.teal : Colors.grey,
                minimumSize: Size(double.infinity, 50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}