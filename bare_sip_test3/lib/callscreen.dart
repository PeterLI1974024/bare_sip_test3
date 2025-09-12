import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CallScreen extends StatefulWidget {
  final String callId;

  const CallScreen({super.key, required this.callId});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _speakerOn = true;
  static const _channel = MethodChannel("baresip");

  @override
  void initState() {
    super.initState();
    // 開始計時
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return "${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}";
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    // TODO: 呼叫 native API 開關靜音
  }

  void _toggleSpeaker() {
    setState(() => _speakerOn = !_speakerOn);
    // TODO: 呼叫 native API 開關擴音
  }

  void _hangUp() async {
    try {
      await _channel.invokeMethod("call_hangup", {"callp": widget.callId});
      debugPrint("✅ 已掛斷 callId=${widget.callId}");
    } catch (e) {
      debugPrint("❌ 掛斷失敗: $e");
    } finally {
      if (mounted) Navigator.pop(context); // 回上一頁
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),

            // 頭像
            const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage("https://i.pravatar.cc/200"),
            ),
            const SizedBox(height: 16),

            // 名稱
            const Text(
              "測試用戶 2205",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),

            // 通話時間
            Text(
              _seconds == 0 ? "連線中..." : _formatDuration(_seconds),
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const Spacer(),

            // 控制按鈕
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCircleButton(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: _muted ? "取消靜音" : "靜音",
                  onTap: _toggleMute,
                ),
                _buildCircleButton(
                  icon: Icons.call_end,
                  label: "掛斷",
                  color: Colors.red,
                  onTap: _hangUp,
                ),
                _buildCircleButton(
                  icon: _speakerOn ? Icons.volume_up : Icons.hearing,
                  label: _speakerOn ? "擴音" : "聽筒",
                  onTap: _toggleSpeaker,
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.grey,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: CircleAvatar(
            radius: 30,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
