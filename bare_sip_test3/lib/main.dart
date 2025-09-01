import 'package:flutter/material.dart';
import 'baresip_ffi.dart';

void main() => runApp(const MaterialApp(home: Demo()));

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  String ver = '';
  int libreCode = -1;
  int initCode = -1;
  int uaCode = -1;

  @override
  void initState() {
    super.initState();

    ver = bsVersion();
    libreCode = reInit(); // Step 1: 初始化 event loop
    initCode = bsInit(); // Step 2: 初始化 baresip core
    uaCode = uaInit("flutter_app"); // Step 3: 建立 User Agent
  }

  @override
  void dispose() {
    bsClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Baresip FFI 測試')),
      body: Center(
        child: Text(
          'version=$ver\nlibre=$libreCode\ninit=$initCode\nua=$uaCode',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
