import 'package:flutter/material.dart';
import 'baresip_ffi.dart';
import 'dart:ffi' as ffi;
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MaterialApp(home: Demo()));

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  String log = "";
  ffi.Pointer<ffi.Void>? ua;

  @override
  void initState() {
    super.initState();
    _initBaresip();
  }

  /// 把 assets/baresip 下的檔案複製到 app documents
  Future<String> _prepareBaresipConfig() async {
    final dir = await getApplicationDocumentsDirectory();
    final baresipDir = Directory("${dir.path}/baresip");
    if (!baresipDir.existsSync()) {
      baresipDir.createSync(recursive: true);
    }

    for (final name in ["config", "accounts", "contacts"]) {
      final data = await rootBundle.load("assets/baresip/$name");
      final file = File("${baresipDir.path}/$name");
      await file.writeAsBytes(data.buffer.asUint8List());
    }

    return baresipDir.path;
  }

  Future<void> _initBaresip() async {
    final configPath = await _prepareBaresipConfig();

    // 告訴 baresip config 路徑
    final confRes = confPathSet(configPath);
    setState(() => log += "confPathSet=$confRes (0=成功)\n");

    final version = bsVersion();
    final r0 = reInit();
    final r1 = bsInit();

    setState(() {
      log += "version=$version\nlibre=$r0 (0=成功)\ninit=$r1 (0=成功)\n";
    });

    // 延遲一下再 init UA
    await Future.delayed(const Duration(milliseconds: 200));
    final r2 = uaInit("flutter_sip");
    setState(() => log += "ua_init=$r2 (0=成功)\n");

    // 再等一下，確保 accounts 載入
    await Future.delayed(const Duration(seconds: 1));

    ua = createUa("sip:2204@stage.twmfspbx.taiwanmobile.com;"
        "auth_user=2204;"
        "auth_pass=Twm09350935");

    if (ua == null) {
      setState(() => log += "UA 建立失敗\n");
    } else {
      final regRes = uaRegister(ua!);
      setState(() => log += "ua_register result=$regRes (0=成功)\n");
    }
  }

  void _call() {
    if (ua == null) return;
    final res = uaConnect(ua!, "sip:2205@stage.twmfspbx.taiwanmobile.com");
    setState(() => log += "call connect result=$res (0=成功)\n");
  }

  @override
  void dispose() {
    bsClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Baresip FFI 測試")),
      body: Column(
        children: [
          Expanded(child: SingleChildScrollView(child: Text(log))),
          ElevatedButton(onPressed: _call, child: const Text("撥打 2205")),
        ],
      ),
    );
  }
}
