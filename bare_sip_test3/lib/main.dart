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
  int initCode = -1;

  @override
  void initState() {
    super.initState();
    ver = bsVersion();
    initCode = bsInit();
  }

  @override
  void dispose() {
    bsClose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FFI 測試')),
      body: Center(
        child: Text('version=$ver\ninit=$initCode'),
      ),
    );
  }
}
