import 'package:flutter/foundation.dart';

import '../network/api_service.dart';

enum AppFlavor { development, production }

@immutable
class ServiceBaseUrls {
  const ServiceBaseUrls({
    required this.common,
    required this.core,
    required this.cad,
    required this.multiWinding,
    required this.storage,
  });

  final Uri common;
  final Uri core;
  final Uri cad;
  final Uri multiWinding;
  final Uri storage;

  Uri forService(ApiService service) {
    return switch (service) {
      ApiService.common => common,
      ApiService.core => core,
      ApiService.cad => cad,
      ApiService.multiWinding => multiWinding,
      ApiService.storage => storage,
    };
  }
}

@immutable
class AppEnvironment {
  const AppEnvironment({
    required this.flavor,
    required this.baseUrls,
    required this.connectTimeout,
    required this.receiveTimeout,
  });

  factory AppEnvironment.fromDefines() {
    const rawFlavor = String.fromEnvironment(
      'APP_ENV',
      defaultValue: 'development',
    );

    final flavor = switch (rawFlavor.toLowerCase()) {
      'production' => AppFlavor.production,
      _ => AppFlavor.development,
    };

    final isProduction = flavor == AppFlavor.production;

    return AppEnvironment(
      flavor: flavor,
      baseUrls: ServiceBaseUrls(
        common: _resolveUri(
          isProduction: isProduction,
          devKey: 'DEV_COMMON_SERVICE_URL',
          prodKey: 'PROD_COMMON_SERVICE_URL',
          devFallback: _defaultCommonServiceUrl(),
          prodFallback: _defaultCommonServiceUrl(),
        ),
        core: _resolveUri(
          isProduction: isProduction,
          devKey: 'DEV_CORE_SERVICE_URL',
          prodKey: 'PROD_CORE_SERVICE_URL',
          devFallback: 'http://127.0.0.1:8080',
          prodFallback: 'https://core.trafointel.invalid',
        ),
        cad: _resolveUri(
          isProduction: isProduction,
          devKey: 'DEV_CAD_SERVICE_URL',
          prodKey: 'PROD_CAD_SERVICE_URL',
          devFallback: 'http://127.0.0.1:8080',
          prodFallback: 'https://cad.trafointel.invalid',
        ),
        multiWinding: _resolveUri(
          isProduction: isProduction,
          devKey: 'DEV_MULTI_WDG_SERVICE_URL',
          prodKey: 'PROD_MULTI_WDG_SERVICE_URL',
          devFallback: 'http://127.0.0.1:8081',
          prodFallback: 'https://multiwdg.trafointel.invalid',
        ),
        storage: _resolveUri(
          isProduction: isProduction,
          devKey: 'DEV_STORAGE_SERVICE_URL',
          prodKey: 'PROD_STORAGE_SERVICE_URL',
          devFallback: 'http://127.0.0.1:8080',
          prodFallback: 'https://storage.trafointel.invalid',
        ),
      ),
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    );
  }

  final AppFlavor flavor;
  final ServiceBaseUrls baseUrls;
  final Duration connectTimeout;
  final Duration receiveTimeout;

  static Uri _resolveUri({
    required bool isProduction,
    required String devKey,
    required String prodKey,
    required String devFallback,
    required String prodFallback,
  }) {
    final value = isProduction
        ? String.fromEnvironment(prodKey, defaultValue: prodFallback)
        : String.fromEnvironment(devKey, defaultValue: devFallback);

    return Uri.parse(value);
  }

  static String _defaultCommonServiceUrl() {
    const tenantHost = String.fromEnvironment(
      'COMMON_SERVICE_TENANT_HOST',
      defaultValue: 'design.trafointel.com',
    );

    return 'https://tf-common-service.trafointel.com/tf/api/$tenantHost';
  }
}
