// globals.dart

class Global {
  static final Global _instance = Global._internal();

  factory Global() => _instance;

  Global._internal();

  String serverIP = '';
}
