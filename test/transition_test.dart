import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:badapple/main.dart';

/// 测试用的假播放器平台：不需要真实解码器，只记录控制器下发的指令。
class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  int createCount = 0;
  bool isLooping = false;
  bool isPlaying = false;

  final List<StreamController<VideoEvent>> _events =
      <StreamController<VideoEvent>>[];

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    createCount += 1;
    final StreamController<VideoEvent> controller =
        StreamController<VideoEvent>();
    controller.onListen = () {
      controller.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 19),
        size: const Size(1280, 720),
        rotationCorrection: 0,
      ));
    };
    _events.add(controller);
    return createCount;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) =>
      _events[playerId - 1].stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async {
    isLooping = looping;
  }

  @override
  Future<void> play(int playerId) async {
    isPlaying = true;
  }

  @override
  Future<void> pause(int playerId) async {
    isPlaying = false;
  }

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();

  @override
  Future<void> dispose(int playerId) async {}
}

void main() {
  testWidgets('白线对准中间后开始循环播放', (WidgetTester tester) async {
    final FakeVideoPlayerPlatform fake = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = fake;

    await tester.pumpWidget(const BadAppleApp());
    await tester.pump();
    await tester.pump();

    // 播放器在用户操作之前就已经创建并设置为循环播放。
    expect(fake.createCount, 1);
    expect(fake.isLooping, isTrue);
    expect(fake.isPlaying, isFalse);

    final double screenH =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    // 白线初始在 0.28，向下拖到 0.5（屏幕中间）。
    await tester.drag(find.byType(Scaffold), Offset(0, screenH * 0.22));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();

    expect(fake.isPlaying, isTrue);

    // 卸载页面，释放播放器。
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
