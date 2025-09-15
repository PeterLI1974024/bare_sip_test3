import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CallScreen extends StatefulWidget {
  final String callId; // 初始 callId (可能是 local id)
  final bool isIncoming; // true = 來電, false = 去電
  final bool isCalling; // true = 撥號中, false = 已建立

  const CallScreen({
    super.key,
    required this.callId,
    this.isIncoming = false,
    this.isCalling = false,
  });

  @override
  State<CallScreen> createState() => CallScreenState();
}

class CallScreenState extends State<CallScreen> {
  late String _callId;
  Timer? _timer;
  int _seconds = 0;
  bool _muted = false;
  bool _speakerOn = true;
  bool _answered = false; // 是否已接通
  String? realCallId; // 🔑 真實 callId (native 回傳)
  bool _established = false; // 🔑 是否已經通話建立

  static const _channel = MethodChannel("baresip");

  @override
  void initState() {
    super.initState();
    _callId = widget.callId; // 🔑 先用初始的

    // 來電 → 等用戶接聽才開始計時
    // 去電 → 如果 isCalling=true 先顯示「撥號中」，等 call_established 才開始計時
    // 如果 isCalling=false → 已建立，直接跑計時
    if (!widget.isIncoming && !widget.isCalling) {
      _answered = true;
      _startTimer();
    }
  }

  void updateCallId(String newId) {
    setState(() {
      _callId = newId;
    });
    debugPrint("🔄 CallScreen 更新 callId=$_callId");
  }

  // 🔑 外部呼叫（call_established event 觸發）
  void markEstablished(String callIdFromNative) {
    setState(() {
      realCallId = callIdFromNative;
      _answered = true;
      _seconds = 0; // 重新從 00:00 開始
    });
    _startTimer(); // ✅ 確保開始跑
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _seconds++; // ✅ 每秒遞增
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String get _currentCallId => realCallId ?? widget.callId;

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
      await _channel.invokeMethod("call_hangup", {"callp": _currentCallId});
      debugPrint("✅ 已掛斷 callId=$_currentCallId");
    } catch (e) {
      debugPrint("❌ 掛斷失敗: $e");
    } finally {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _answer() async {
    try {
      await _channel.invokeMethod("call_answer", {"callp": _currentCallId});
      debugPrint("✅ 已接聽 callId=$_currentCallId");

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

    final statusText = () {
      if (!_answered && widget.isIncoming) return "來電中...";
      if (!_answered && widget.isCalling) return "撥號中...";
      return _formatDuration(_seconds); // ✅ 一旦接通就直接顯示秒數
    }();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage("https://i.pravatar.cc/200"),
            ),
            const SizedBox(height: 16),
            const Text(
              "測試用戶 2205",
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
            Text(
              statusText,
              style: const TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const Spacer(),
            if (!isActive)
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
