class AppConstants {
  // Hardcoded to verified IP — override in Nexus tab if it changes
  static String laptopIp = "192.168.2.61";
  static String get backendUrl => "http://$laptopIp:8000";
}
