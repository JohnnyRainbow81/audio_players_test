import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeOSDependentAudio();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AudioApp(),
    );
  }
}

class AudioApp extends StatefulWidget {
  const AudioApp({super.key});

  @override
  State<AudioApp> createState() => _AudioAppState();
}

class _AudioAppState extends State<AudioApp> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
            child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        PlayButton("613be3bf-bbc1-4ab9-911a-c1758a50c6d8"),
        PlayButton("cce9519c-5b68-46d2-a9de-12d21dac274c")
      ],
    )));
  }
}

class PlayButton extends StatefulWidget {
  final String id;

  const PlayButton(this.id, {super.key});

  @override
  State<PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<PlayButton> {
  PlayerState? state;
  StreamSubscription<PlayerState>? subscription;
  late AudioData audioData;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    audioData = await AudioService.instance.prepareAudio(widget.id);
    subscription = audioData.state?.listen((event) {
      state = event;
      setState(() {});
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void togglePlay() {
    switch (state) {
      case PlayerState.stopped:
      case PlayerState.completed:
      case PlayerState.paused:
        AudioService.instance.play(widget.id);
        break;
      case PlayerState.playing:
        AudioService.instance.pause(widget.id);
        break;
      default:
        AudioService.instance.play(widget.id);
    }

  //  setState(() {});
  }

  IconData _getIcon() {
    switch (state) {
      case PlayerState.stopped:
      case PlayerState.completed:
      case PlayerState.paused:
        return Icons.play_arrow;
      case PlayerState.playing:
        return Icons.pause;
      default:
        return Icons.play_arrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(onPressed: togglePlay, icon: Icon(_getIcon()));
  }
}

// Just some OS setup
void initializeOSDependentAudio() {
  final AudioContext audioContext = AudioContext(
    iOS: AudioContextIOS(
      defaultToSpeaker: true,
      category: AVAudioSessionCategory.ambient,
      options: [AVAudioSessionOptions.defaultToSpeaker, AVAudioSessionOptions.duckOthers],
    ),
    android: AudioContextAndroid(
      isSpeakerphoneOn: true,
      stayAwake: true,
      contentType: AndroidContentType.speech,
      usageType: AndroidUsageType.media,
      audioFocus: AndroidAudioFocus.gainTransientExclusive,
    ),
  );

  AudioPlayer.global.setGlobalAudioContext(audioContext);

  AudioPlayer.global.changeLogLevel(LogLevel.info);
}

class AudioService {
  AudioService._();
  static final AudioService _instance = AudioService._();

  static AudioService get instance => _instance;
  final String baseUrl = "https://speakyfox-api-qa.herokuapp.com/api/v1/files";

  final Map<String, AudioData> _audioDatas = {};
  final Map<String, AudioPlayer> _audioPlayers = {};

  Future<AudioData> prepareAudio(String id) async {
    late AudioPlayer audioPlayer;

    if (!_audioPlayers.containsKey(id)) {
      audioPlayer = AudioPlayer(playerId: id);
      audioPlayer.setReleaseMode(ReleaseMode.release);
      audioPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      audioPlayer.setVolume(1);
    }

    String path = (await DefaultCacheManager().getSingleFile(_url(id))).path;
    await audioPlayer.setSourceDeviceFile(path);

    AudioData audioData = AudioData.empty();
    audioData.audioId = id;
    audioData.state = audioPlayer.onPlayerStateChanged;

    _audioPlayers.putIfAbsent(id, () => audioPlayer);
    _audioDatas.putIfAbsent(id, () => audioData);

    return audioData;
  }

  Future<void> play(String id) async {
    String path = (await DefaultCacheManager().getSingleFile(_url(id))).path;
    await _audioPlayers[id]?.play(DeviceFileSource(path), volume: 1);
  }

  Future<void> pause(String id) async {
    await _audioPlayers[id]?.pause();
  }

  Future<void> resume(String id) async {
    await _audioPlayers[id]?.resume();
  }

  String _url(String id) {
    return "$baseUrl/$id";
  }
}

class AudioData {
  String audioId = "";
  Stream<PlayerState>? state;

  AudioData({
    this.state,
  });

  AudioData.empty();
}
