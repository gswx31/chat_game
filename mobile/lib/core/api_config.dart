import 'dart:io';

class ApiConfig {
  ApiConfig._();

  static String get host {
    if (Platform.isAndroid) return '10.0.2.2'; // Android emulator → host loopback
    return 'localhost'; // iOS simulator / desktop
  }

  static const int port = 8000;
  static String get baseUrl => 'http://$host:$port/api';
  static String get wsBase => 'ws://$host:$port';
}
