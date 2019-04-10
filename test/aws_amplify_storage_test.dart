import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aws_amplify_storage/aws_amplify_storage.dart';

void main() {
  const MethodChannel channel = MethodChannel('aws_amplify_storage');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  // test('getPlatformVersion', () async {
  //   expect(await AwsAmplifyStorage.platformVersion, '42');
  // });
}
