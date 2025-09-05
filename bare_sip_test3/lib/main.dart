import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const MaterialApp(home: Demo()));

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  static const _channel = MethodChannel("baresip");

  String log = "";

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
        "proxy": "175.99.74.33:5060",
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
      final ret = await _channel.invokeMethod<num>("call_connect", {
        "target": "sip:2205@stage.twmfspbx.taiwanmobile.com",
      });
      setState(() => log += "call_connect result=$ret\n");
    } catch (e) {
      setState(() => log += "call_connect error: $e\n");
    }
  }

  @override
  void initState() {
    super.initState();
    // _testNative(); // 測試呼叫 C 函式
    _startNative();

    _channel.setMethodCallHandler((call) async {
      if (call.method == "started") {
        setState(() => log += "== Baresip 已啟動 ==\n");
        // 等待一秒讓 baresip 完全初始化後再註冊
        await Future.delayed(const Duration(seconds: 1));
        await _register();
      } else if (call.method == "ua_event") {
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final event = args["event"];
        final ua = args["ua"];
        final callId = args["call"];
        final scode = args["scode"];
        final reason = args["reason"];

        setState(() {
          log += "== UA Event == $event\n";
          if (ua != null) log += "   ua=$ua\n";
          if (callId != null) log += "   call=$callId\n";
          if (scode != null) log += "   scode=$scode\n";
          if (reason != null) log += "   reason=$reason\n";
          log += "   raw=$args\n"; // 最後再印原始 map，避免遺漏
        });
      } else if (call.method == "stopped") {
        setState(() => log += "== Baresip 已停止 ==\n");
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
