import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';

class TransferInfo {
  final Map<String, dynamic> _data;

  TransferInfo._(this._data);

  int get id => _data["id"] as int;

  String get transferState => _data["transferState"];

  int get progress => _data["progress"];

  String get location => _data["location"];

  @override
  String toString() {
    return '$runtimeType($_data)';
  }
}

class AwsAmplifyStorage {
  final Map<int, StreamController<TransferInfo>>
      _transferStateChangedControllers =
      <int, StreamController<TransferInfo>>{};

  AwsAmplifyStorage._() {
    _channel.setMethodCallHandler(_callHandler);
  }

  static const MethodChannel _channel =
      const MethodChannel('aws_amplify_storage');

  static final AwsAmplifyStorage instance = AwsAmplifyStorage._();

  Future<int> upload(
      {@required String bucket,
      @required String bucketKey,
      @required String pathname,
      @required String contentType}) {
    Future<int> handle = _channel.invokeMethod('upload', <String, String>{
      'bucket': bucket,
      'bucketKey': bucketKey,
      'pathname': pathname,
      'contentType': contentType,
    }).then<int>((dynamic v) => v);
    return handle;
  }

  Future<int> download(
      {@required String bucket,
      @required String bucketKey,
      @required String pathname}) {
    Future<int> handle = _channel.invokeMethod('download', <String, String>{
      'bucket': bucket,
      'bucketKey': bucketKey,
      'pathname': pathname,
    }).then<int>((dynamic v) => v);
    return handle;
  }

  Future<bool> pause({@required int id}) {
    return _channel.invokeMethod('pause', <String, int>{
      'id': id,
    });
  }

  Future<int> resume({@required int id}) {
    Future<int> handle = _channel.invokeMethod('resume', <String, int>{
      'id': id,
    }).then<int>((dynamic v) => v);
    return handle;
  }

  Future<bool> cancel({@required int id}) {
    return _channel.invokeMethod('cancel', <String, int>{
      'id': id,
    });
  }

  Stream<TransferInfo> onTransferStateChanged({@required int id}) {
    // The id of the transfer returned by invoking the method
    Future<int> _handle;
    StreamController<TransferInfo> controller;
    controller = StreamController<TransferInfo>.broadcast(onListen: () {
      _handle = _channel.invokeMethod('startListeningTransferState',
          <String, int>{'id': id}).then<int>((dynamic v) => v);
      _handle.then((int handle) {
        // The handle will be stored for later reference
        _transferStateChangedControllers[handle] = controller;
      });
    }, onCancel: () {
      // The handle should be the same, so let's make use of it
      _handle.then((int handle) async {
        await _channel.invokeMethod(
            'stopListeningTransferState', <String, int>{'id': id});
        _transferStateChangedControllers.remove(handle);
        controller.close();
      });
    });
    return controller.stream;
  }

  Future<void> _callHandler(MethodCall call) async {
    switch (call.method) {
      case 'onTransferStateChanged':
        _onTransferStateChangedHandler(call);
        break;
    }
  }

  void _onTransferStateChangedHandler(MethodCall call) {
    final Map<String, dynamic> data = call.arguments;

    final transferInfo = TransferInfo._(data);

    final int id = data["id"] as int;

    // Send the event to the listeners, onListen of the controller is called
    _transferStateChangedControllers[id].add(transferInfo);
  }
}
