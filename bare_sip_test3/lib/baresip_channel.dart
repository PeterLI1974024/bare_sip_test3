import 'package:flutter/services.dart';

class BaresipChannel {
  static const MethodChannel _channel = MethodChannel('baresip');

  static Future<int> uaRegister(String aor, String authUser, String authPass) async {
    final result = await _channel.invokeMethod('ua_register', {
      'aor': aor,
      'authUser': authUser,
      'authPass': authPass,
    });
    return result;
  }

  static Future<int> callConnect(String target) async {
    final result = await _channel.invokeMethod('call_connect', {
      'target': target,
    });
    return result;
  }
}
