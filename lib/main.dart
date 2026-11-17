import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

void main() => runApp(const BadAppleApp());

class BadAppleApp extends StatelessWidget {
  const BadAppleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        useMaterial3: true,
      ),
      home: const BadApplePage(),
    );
  }
}

class BadApplePage extends StatefulWidget {
  const BadApplePage({super.key});

  @override
  State<BadApplePage> createState() => _BadApplePageState();
}

class _BadApplePageState extends State<BadApplePage>
    with TickerProviderStateMixin {
  /// 白线位置，0.0 = 顶部，1.0 = 底部。
  double _lineY = 0.28;
  static const double _targetY = 0.5;
  static const double _snapThreshold = 0.025;
  static const double _lineHeight = 4.0;

  /// 白线是否已经对准屏幕中间。
  bool _aligned = false;

  /// 过渡动画是否已经开始。
  bool _revealed = false;

  /// 视频是否已经开始播放。
  bool _playing = false;

  bool _videoReady = false;

  VideoPlayerController? _controller;

  late final AnimationController _expandController;
  late final AnimationController _fadeController;
  late final Animation<double> _expand;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expand = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOutCubic,
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _expandController.addListener(_repaint);
    _prepareVideo();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  /// 在用户对准白线之前就把播放器准备好，这样切换时不用再等解码。
  Future<void> _prepareVideo() async {
    final controller = VideoPlayerController.asset('assets/badapple.mp4');
    _controller = controller;
    try {
      await controller.setLooping(true);
      await controller.initialize();
    } catch (_) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        await controller.initialize();
      } catch (_) {
        return;
      }
    }
    if (!mounted) return;
    setState(() => _videoReady = true);
    _maybeReveal();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_revealed) return;
    final double screenH = MediaQuery.of(context).size.height;
    setState(() {
      _lineY = (_lineY + details.delta.dy / screenH).clamp(0.02, 0.98);
      if ((_lineY - _targetY).abs() < _snapThreshold) {
        _lineY = _targetY;
        _aligned = true;
      } else {
        _aligned = false;
      }
    });
    _maybeReveal();
  }

  /// 对准与播放器就绪是两条独立的时间线：无论谁后到，都在这里汇合。
  Future<void> _maybeReveal() async {
    if (_revealed || !_aligned || !_videoReady) return;
    _revealed = true;
    setState(() => _lineY = _targetY);

    await _expandController.forward();
    if (!mounted) return;
    await _fadeController.forward();
    if (!mounted) return;

    setState(() => _playing = true);
    await _controller?.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    _expandController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenH = MediaQuery.of(context).size.height;
    final double expandProgress = _expand.value;
    final double lineHeight = _revealed
        ? _lineHeight + (screenH - _lineHeight) * expandProgress
        : _lineHeight;
    final double lineTop = _revealed
        ? (screenH - lineHeight) / 2
        : screenH * _lineY - _lineHeight / 2;

    final VideoPlayerController? controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            // 视频层：初始化完成后一直挂载在遮罩下面，切换时不再重建。
            if (controller != null && controller.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              ),

            // 黑色遮罩：白线展开后淡出，露出视频。
            IgnorePointer(
              child: Opacity(
                opacity: _revealed ? 1.0 - _fade.value : 1.0,
                child: const ColoredBox(color: Colors.black),
              ),
            ),

            // 白线。
            if (!_playing)
              Positioned(
                left: 0,
                right: 0,
                top: lineTop,
                child: Container(height: lineHeight, color: Colors.white),
              ),

            // 屏幕中间的目标标记。
            if (!_revealed)
              Center(
                child: Opacity(
                  opacity: 0.12,
                  child: Container(
                    width: 80,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),

            // 提示文字。
            if (!_revealed)
              Positioned(
                left: 0,
                right: 0,
                bottom: 96,
                child: Center(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: (_lineY - _targetY).abs() < 0.1 ? 0.0 : 1.0,
                    child: Text(
                      '把白线拖到中间',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.22),
                        fontSize: 14,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),

            // 视频准备中的小提示。
            if (!_videoReady && !_revealed)
              Positioned(
                top: 56,
                right: 28,
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.white.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
