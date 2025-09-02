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

  Future<void> _register() async {
    try {
      final ret = await _channel.invokeMethod<int>("ua_register", {
        "aor": "sip:2204@stage.twmfspbx.taiwanmobile.com",
        "authUser": "2204",
        "authPass": "Twm09350935",
      });
      setState(() => log += "ua_register result=$ret\n");
    } catch (e) {
      setState(() => log += "ua_register error: $e\n");
    }
  }

  Future<void> _call() async {
    try {
      final ret = await _channel.invokeMethod<int>("call_connect", {
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
    _startNative();

    _channel.setMethodCallHandler((call) async {
      if (call.method == "started") {
        setState(() => log += "== Baresip 已啟動 ==\n");
      } else if (call.method == "ua_event") {
        final args = call.arguments as Map;
        setState(() => log += "== UA Event == ${args["event"]}\n");
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
