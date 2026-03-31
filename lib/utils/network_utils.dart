// ignore_for_file: constant_pattern_never_matches_value_type, unrelated_type_equality_checks

import 'package:connectivity_plus/connectivity_plus.dart';

class NetworkUtils {
  // Check if device has internet connection
  static Future<bool> isNetworkAvailable() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Get network type (WiFi, Mobile, etc.)
  static Future<String> getNetworkType() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    
    switch (connectivityResult) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return 'Mobile Data';
      case ConnectivityResult.ethernet:
        return 'Ethernet';
      case ConnectivityResult.none:
        return 'No Connection';
      default:
        return 'Unknown';
    }
  }

  // Check if connected to WiFi
  static Future<bool> isWiFiConnected() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.wifi;
  }
}