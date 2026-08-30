abstract final class RoutePaths {
  static const String login = '/';
  static const String signUp = '/signUp';
  static const String forgotPassword = '/forgotPassword';
  static const String home = '/home';
  static const String twoWindings = '/2windings';
  static String twoWindingsDesign(String designId) => '$twoWindings/$designId';
  static const String multiWindings = '/multiwindings';
  static String multiWindingsDesign(String designId) =>
      '$multiWindings/$designId';
  static const String core = '/core';
  static String coreDesign(String designId) => '$core/$designId';
  static const String fabrication = '/fabrication';
  static String fabricationDesign(String designId) => '$fabrication/$designId';
  static const String files = '/files';
  static String filesDesign(String designId) => '$files/$designId';
  static const String profile = '/profile';
  static const String users = '/users';
  static const String lomCost = '/lomCost';
}
