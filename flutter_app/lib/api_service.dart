import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'constants.dart';
import 'models.dart';
import 'dart:io';

class ApiService {
  static String? _manualBaseUrl;
  static bool isConnected = false;

  static String get backendUrl => _manualBaseUrl ?? AppConstants.backendUrl;

  static void updateBaseUrl(String newIp) {
    _manualBaseUrl = "http://$newIp:8000";
    isConnected = false; // Reset connection to test new URL
  }

  static Future<void> discoverServer([Function(String)? onFound]) async {
    try {
      debugPrint("🔍 [DISCOVERY] Searching for MemoryForge on subnet...");
      RawDatagramSocket.bind(InternetAddress.anyIPv4, 5555).then((socket) {
        socket.listen((RawSocketEvent event) {
          if (event == RawSocketEvent.read) {
            Datagram? dg = socket.receive();
            if (dg != null) {
              String message = utf8.decode(dg.data);
              if (message.startsWith("MEMORYFORGE_SERVER:")) {
                String url = message.split("MEMORYFORGE_SERVER:")[1];
                _manualBaseUrl = url;
                isConnected = true;
                debugPrint("✅ [DISCOVERY] Linked to Forge: $_manualBaseUrl");
                if (onFound != null) onFound(url);
              }
            }
          }
        });
        // Auto-close after 10 seconds if not found
        Future.delayed(const Duration(seconds: 10), () => socket.close());
      });
    } catch (e) {
      debugPrint("❌ [DISCOVERY] Fatal: $e");
    }
  }

  static Future<List<Topic>> getFlashcards() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/flashcards'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        isConnected = true;
        return data.map((json) => Topic.fromJson(json)).toList();
      }
    } catch (_) { isConnected = false; }
    return [];
  }

  static Future<List<NotificationDetail>> getPendingNotifications() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/notifications/pending'));
      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        return data.map((json) => NotificationDetail.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> clearNotification(String id) async {
    await http.post(
      Uri.parse('$backendUrl/notifications/clear'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'notification_id': id}),
    );
  }

  static Future<void> clearAllNotifications() async {
    await http.post(Uri.parse('$backendUrl/notifications/clear-all'));
  }

  static Future<void> reviewFlashcard(String flashcardId, String result) async {
    await http.post(
      Uri.parse('$backendUrl/flashcard/review'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'flashcard_id': flashcardId,
        'result': result,
      }),
    );
  }

  static Future<Topic> ingestText(String topicName, String text, {int? targetCompletionAt}) async {
    await http.post(
      Uri.parse('$backendUrl/ingest/text'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'topic_name': topicName, 'text': text, 'target_completion_at': targetCompletionAt}),
    );
    final cards = await getFlashcards();
    if (cards.isEmpty) {
      throw Exception('Ingest succeeded but no flashcards returned');
    }
    return cards.last;
  }

  static Future<Topic> ingestYoutube(String topicName, String url, {int? targetCompletionAt}) async {
    await http.post(
      Uri.parse('$backendUrl/ingest/youtube'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'topic_name': topicName, 'url': url, 'target_completion_at': targetCompletionAt}),
    );
    final cards = await getFlashcards();
    if (cards.isEmpty) {
      throw Exception('Ingest succeeded but no flashcards returned');
    }
    return cards.last;
  }

  static Future<void> ingestFile(String topicName, File file, {int? targetCompletionAt}) async {
    var request = http.MultipartRequest('POST', Uri.parse('$backendUrl/ingest/file'));
    request.fields['topic_name'] = topicName;
    if (targetCompletionAt != null) request.fields['target_completion_at'] = targetCompletionAt.toString();
    request.files.add(await http.MultipartFile.fromPath('file', file.path));
    await request.send();
  }

  static Future<void> setDemoMode(bool enabled) async {
    await http.post(
      Uri.parse('$backendUrl/settings/demo-mode'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'enabled': enabled}),
    );
  }



  static Future<String> getReportEmail() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/settings/report-email'));
      if (response.statusCode == 200) {
        final data = Map<String, dynamic>.from(json.decode(response.body));
        return (data['email'] ?? '').toString();
      }
    } catch (e) {
      debugPrint("Failed to get report email: $e");
    }
    return '';
  }

  static Future<bool> saveReportEmail(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/settings/report-email'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Failed to save report email: $e");
      return false;
    }
  }
  static Future<Map<String, dynamic>?> askAIChat(String question) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/ai/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'question': question, 'top_k': 5}),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(json.decode(response.body));
      }
    } catch (e) {
      debugPrint("AI chat failed: $e");
    }
    return null;
  }

  static Future<bool> deleteLesson(String topicName) async {
    try {
      final response = await http.delete(
        Uri.parse('$backendUrl/lesson?topic_name=${Uri.encodeComponent(topicName)}'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Failed to delete lesson: $e");
      return false;
    }
  }
  static Future<GameSession?> startGame(String type) async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/game/start/$type'));
      if (response.statusCode == 200) {
        return GameSession.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Failed to start game: $e");
    }
    return null;
  }

  static Future<GameStatsResponse?> submitScore(String type, int score, {String? result}) async {
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/game/score/$type'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'score': score,
          'result': result,
        }),
      );
      if (response.statusCode == 200) {
        return GameStatsResponse.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Failed to submit score: $e");
    }
    return null;
  }

  static Future<GameStatsResponse?> getGameStats() async {
    try {
      final response = await http.get(Uri.parse('$backendUrl/game/stats'));
      if (response.statusCode == 200) {
        return GameStatsResponse.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint("Failed to get game stats: $e");
    }
    return null;
  }
}






