import 'package:bare_sip_test3/callscreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_callkit_incoming/entities/call_event.dart';
import 'package:flutter_callkit_incoming/entities/call_kit_params.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:permission_handler/permission_handler.dart'; // 🔑 新增

void main() => runApp(const MaterialApp(home: Demo()));

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  static const _channel = MethodChannel("baresip");
  String log = "";
  final GlobalKey<CallScreenState> callScreenKey = GlobalKey();

  Future<void> _checkMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) {
      setState(() => log += "麥克風權限允許 ✅\n");
    } else if (status.isDenied) {
      setState(() => log += "麥克風權限被拒絕 ❌\n");
    } else if (status.isPermanentlyDenied) {
      setState(() => log += "麥克風權限永久拒絕，請去設定開啟  ⚠️\n");
      openAppSettings();
    }
  }

  Future<void> _checkNotificationPermission() async {
    // 只在 Android 13+ 需要檢查
    if (await Permission.notification.isDenied || await Permission.notification.isPermanentlyDenied) {
      final status = await Permission.notification.request();

      if (status.isGranted) {
        debugPrint("🔔 通知權限允許 ✅");
      } else if (status.isDenied) {
        debugPrint("❌ 通知權限被拒絕");
      } else if (status.isPermanentlyDenied) {
        debugPrint("⚠️ 通知權限永久拒絕，請去設定手動開啟");
        openAppSettings();
      }
    } else {
      debugPrint("🔔 通知權限已允許 (不需再請求)");
    }
  }

  Future<void> _startNative() async {
    try {
      final ret = await _channel.invokeMethod<int>("baresip_start");
      setState(() => log += "baresip_start=$ret\n");
    } catch (e) {
      setState(() => log += "baresip_start error: $e\n");
    }
  }

  Future<void> _testNative() async {
    const _channel = MethodChannel("baresip");
    try {
      final result = await _channel.invokeMethod<int>("testNative", {"value": 7});
      debugPrint("testNative 回傳結果 = $result");
    } catch (e) {
      debugPrint("testNative 發生錯誤: $e");
    }
  }

  Future<void> _register() async {
    try {
      debugPrint("[Flutter] 呼叫 ua_register...");
      final ret = await _channel.invokeMethod<num>("ua_register", {
        "user": "2204",
        "domain": "e003529",
        "proxy": "stage.twmfspbx.taiwanmobile.com",
        "authUser": "2204",
        "authPass": "Twm09350935",
      });

      debugPrint("[Flutter] ua_register 回傳=$ret");
      setState(() => log += "ua_register result=$ret\n");
    } catch (e) {
      debugPrint("[Flutter] ua_register 發生錯誤: $e");
      setState(() => log += "ua_register error: $e\n");
    }
  }

  Future<void> _call() async {
    try {
      final ret = await _channel.invokeMethod<num>(
        "call_connect",
        {"target": "sip:2205@e003529"},
      );
      setState(() => log += "call_connect result=$ret\n");

      // 🚀 不等 event，直接進到 CallScreen
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CallScreen(
              key: callScreenKey,
              callId: "local-${DateTime.now().millisecondsSinceEpoch}", // 臨時 id
              isIncoming: false,
              isCalling: true, // 新增參數，表示撥號中
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => log += "call_connect error: $e\n");
    }
  }

  @override
  void initState() {
    super.initState();
    // Future.delayed(const Duration(seconds: 5), () {
    //   _showIncomingCallKit("test-12345");
    // });

    _checkMicPermission(); // ✅ 啟動時檢查麥克風
    _checkNotificationPermission();
    _startNative();
    _setupCallkitListener();
    _channel.setMethodCallHandler((call) async {
      if (call.method == "started") {
        setState(() => log += "== Baresip 已啟動 ==\n");
        await Future.delayed(const Duration(seconds: 1));
        await _register();
      } else if (call.method == "ua_event") {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final event = args["event"];
        final ua = args["uap"];
        final callId = args["callp"].toString();
        setState(() {
          print('ua event=$ua event=$event args=$args');
          log += "== UA Event == $event\n";
          log += "   raw=$args\n";
        });

        if (event == "incoming_call") {
          print("進到 incoming_call event, callId=$callId");
          _showIncomingCallKit(callId);
        } else if (event == "outgoing_call") {
          final callId = args["callp"].toString(); // ✅ 拿到 call pointer
          print("📞 去電中 callId=$callId");

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                callId: callId,
                isIncoming: false,
              ),
            ),
          );
        } else if (event == "call_established") {
          final realCallId = args["callp"].toString();
          print("✅ 通話接通 callId=$realCallId");

          callScreenKey.currentState?.markEstablished(realCallId);
        } else if (event == "call_closed") {
          debugPrint("📴 通話結束 callId=$callId reason=${args["reason"]}");

          if (context.mounted) {
            Navigator.pop(context); // ✅ 自動關閉 CallScreen
          }
        }
      } else if (call.method == "stopped") {
        setState(() => log += "== Baresip 已停止 ==\n");
      }
    });
  }

  Future<void> _showIncomingCallKit(String callId) async {
    print('有盡到incoming畫面');
    final params = CallKitParams.fromJson({
      'id': callId,
      'nameCaller': '測試用戶 2205',
      'appName': 'Baresip Demo',
      'avatar': 'https://i.pravatar.cc/100', // 可換成聯絡人頭像
      'handle': '2205',
      'type': 0, // 0 = audio, 1 = video
      'extra': <String, dynamic>{'userId': '2205'},
      'headers': <String, dynamic>{},
      'ios': <String, dynamic>{
        'iconName': 'CallKitLogo', // iOS AppIcon 名稱
        'handleType': 'number',
        'supportsVideo': true,
        'maximumCallGroups': 2,
        'maximumCallsPerCallGroup': 1,
        'audioSessionMode': 'default',
        'audioSessionActive': true,
        'audioSessionPreferredSampleRate': 44100.0,
        'audioSessionPreferredIOBufferDuration': 0.005,
        'supportsDTMF': true,
        'supportsHolding': true,
        'supportsGrouping': false,
        'supportsUngrouping': false,
      },
      'android': <String, dynamic>{
        'isCustomNotification': true,
        'ringtonePath': 'system_ringtone_default',
        'backgroundColor': '#0955fa',
        'backgroundUrl': 'https://i.pravatar.cc/500',
        'actionColor': '#4CAF50',
      }
    });

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  Future<void> _setupCallkitListener() async {
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) async {
      if (event == null) return;

      switch (event.event) {
        case Event.actionCallAccept:
          debugPrint("📞 接聽 callId=${event.body['id']}");
          await FlutterCallkitIncoming.endCall(event.body['id']);

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CallScreen(callId: event.body['id']),
              ),
            );
          }

          await _channel.invokeMethod("call_answer", {"callp": event.body['id']});
          break;

        case Event.actionCallDecline:
          debugPrint("❌ 掛斷 callId=${event.body['id']}");
          await FlutterCallkitIncoming.endCall(event.body['id']);

          await _channel.invokeMethod("call_hangup", {"callp": event.body['id']});
          break;

        case Event.actionCallIncoming:
          debugPrint("📲 來電顯示 callId=${event.body['id']}");
          break;

        case Event.actionCallEnded:
          await FlutterCallkitIncoming.endCall(event.body['id']);

          debugPrint("📴 通話結束 callId=${event.body['id']}");
          break;

        default:
          debugPrint("⚡ 其他事件: ${event.event}");
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Baresip 測試")),
      body: Column(
        children: [
          Expanded(child: SingleChildScrollView(child: Text(log))),
          Row(
            children: [
              ElevatedButton(onPressed: _register, child: const Text("註冊 UA")),
              const SizedBox(width: 8),
              ElevatedButton(onPressed: _call, child: const Text("撥打 2205")),
            ],
          ),
        ],
      ),
    );
  }
}
