import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final bool isIncoming; // 🔑 true = 來電, false = 去電

  const CallScreen({
    super.key,
    required this.callId,
    this.isIncoming = false,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _speakerOn = true;
  bool _answered = false; // 🔑 來電是否已接聽
  static const _channel = MethodChannel("baresip");

  @override
  void initState() {
    super.initState();

    // 去電馬上開始計時
    if (!widget.isIncoming) {
      _startTimer();
      _answered = true;
    }
  }

  void _startTimer() {
    _timer?.cancel();
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

  Future<void> _hangUp() async {
    try {
      await _channel.invokeMethod("call_hangup", {"callp": widget.callId});
      debugPrint("✅ 已掛斷 callId=${widget.callId}");
    } catch (e) {
      debugPrint("❌ 掛斷失敗: $e");
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _answer() async {
    try {
      await _channel.invokeMethod("call_answer", {"callp": widget.callId});
      debugPrint("✅ 已接聽 callId=${widget.callId}");

      setState(() {
        _answered = true;
      });

      _startTimer();
    } catch (e) {
      debugPrint("❌ 接聽失敗: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = _answered || !widget.isIncoming;

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

            // 通話狀態 / 計時
            Text(
              !isActive ? "來電中..." : (_seconds == 0 ? "連線中..." : _formatDuration(_seconds)),
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const Spacer(),

            // 按鈕區塊
            if (!isActive)
              // 來電未接聽 → 顯示 接聽/掛斷
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCircleButton(
                    icon: Icons.call,
                    label: "接聽",
                    color: Colors.green,
                    onTap: _answer,
                  ),
                  _buildCircleButton(
                    icon: Icons.call_end,
                    label: "掛斷",
                    color: Colors.red,
                    onTap: _hangUp,
                  ),
                ],
              )
            else
              // 已接通 / 去電 → 顯示 靜音/掛斷/擴音
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
