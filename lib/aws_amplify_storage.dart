import 'dart:async';

import 'package:flutter/services.dart';

class AwsAmplifyStorage {
  static const MethodChannel _channel =
      const MethodChannel('aws_amplify_storage');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
