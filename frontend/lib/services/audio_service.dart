import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:lexilearn/constants.dart'; // If base URL needed for audio path

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Assuming ukspeech/usspeech are relative paths or query params
  // Example: "cancel&type=1" -> needs base URL + path + params
  // Example: "audio/uk/cancel.mp3" -> needs base URL + path
  Future<void> playPronunciation(String speechParam, {bool isUK = true}) async {
    // TODO: Construct the full audio URL based on speechParam and backend structure
    // This is highly dependent on how your backend serves audio or if it's from a CDN
    String url = '';

    // Example Logic (adjust based on your actual URL structure):
    // Option 1: Param like "word&type=1"
    if (speechParam.contains('&type=')) {
      // Assume base URL + fixed path + params
      // url = '$API_BASE_URL/audio/play?$speechParam'; // Example
    }
    // Option 2: Relative path like "audio/uk/word.mp3"
    else if (speechParam.startsWith('audio/')) {
      url = '$API_BASE_URL/$speechParam'; // Example
    }
    // Option 3: Full URL already in JSON
    else if (speechParam.startsWith('http')) {
      url = speechParam;
    } else {
      if (kDebugMode) print("Unknown audio path format: $speechParam");
      return; // Cannot play
    }

    if (url.isNotEmpty) {
      try {
        await _audioPlayer.play(UrlSource(url));
        if (kDebugMode) print("Playing audio: $url");
      } catch (e) {
        if (kDebugMode) print("Error playing audio $url: $e");
        // Handle error (e.g., show a snackbar)
      }
    }
  }

  void dispose() {
    _audioPlayer.dispose();
  }
}
