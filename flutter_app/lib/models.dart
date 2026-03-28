class LearningPlanStage {
  final int stageIndex;
  final String name;
  final String status;
  final String scheduledTime;

  LearningPlanStage({
    required this.stageIndex,
    required this.name,
    required this.status,
    required this.scheduledTime,
  });

  factory LearningPlanStage.fromJson(Map<String, dynamic> json) {
    return LearningPlanStage(
      stageIndex: json['stage_index'] ?? 0,
      name: json['name'] ?? '',
      status: json['status'] ?? 'pending',
      scheduledTime: json['scheduled_time'] ?? '',
    );
  }
}

class LearningPlan {
  final String id;
  final String topicId;
  final int currentStage;
  final String status;
  final List<LearningPlanStage> stages;

  LearningPlan({
    required this.id,
    required this.topicId,
    required this.currentStage,
    required this.status,
    required this.stages,
  });

  factory LearningPlan.fromJson(Map<String, dynamic> json) {
    return LearningPlan(
      id: json['id'] ?? '',
      topicId: json['topic_id'] ?? '',
      currentStage: json['current_stage'] ?? 0,
      status: json['status'] ?? 'active',
      stages: (json['stages'] as List? ?? [])
          .map((s) => LearningPlanStage.fromJson(s))
          .toList(),
    );
  }
}

class Topic {
  final String id;
  final String topicName;
  final String question;
  final String answer;
  final String summary;
  final String sourceType;
  final int retentionScore;
  final String urgencyLevel;
  final bool audioReady;
  final int nextReminderMinutes;
  final int? targetCompletionAt;
  final LearningPlan? learningPlan;

  Topic({
    required this.id,
    required this.topicName,
    required this.question,
    required this.answer,
    this.summary = '',
    required this.sourceType,
    this.retentionScore = 100,
    this.urgencyLevel = 'safe',
    this.audioReady = false,
    this.nextReminderMinutes = 0,
    this.targetCompletionAt,
    this.learningPlan,
  });

  factory Topic.fromJson(Map<String, dynamic> json) {
    return Topic(
      id: json['id'] ?? '',
      topicName: json['topic_name'] ?? '',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      summary: json['summary'] ?? '',
      sourceType: json['source_type'] ?? 'manual',
      retentionScore: json['retention_score'] ?? 100,
      urgencyLevel: json['urgency_level'] ?? 'safe',
      audioReady: json['audio_ready'] ?? false,
      nextReminderMinutes: json['next_reminder_minutes'] ?? 0,
      targetCompletionAt: json['target_completion_at'] != null ? (json['target_completion_at'] as num).toInt() : null,
      learningPlan: json['learning_plan'] != null 
          ? LearningPlan.fromJson(json['learning_plan']) 
          : null,
    );
  }
}

class NotificationDetail {
  final String notificationId;
  final String flashcardId;
  final String topicName;
  final String question;
  final int retentionScore;
  final String urgencyLevel;
  final String action;
  final String audioUrl;
  final String summaryText;

  NotificationDetail({
    required this.notificationId,
    required this.flashcardId,
    required this.topicName,
    required this.question,
    required this.retentionScore,
    required this.urgencyLevel,
    required this.action,
    required this.audioUrl,
    required this.summaryText,
  });

  factory NotificationDetail.fromJson(Map<String, dynamic> json) {
    return NotificationDetail(
      notificationId: json['notification_id'] ?? '',
      flashcardId: json['flashcard_id'] ?? '',
      topicName: json['topic_name'] ?? '',
      question: json['question'] ?? '',
      retentionScore: json['retention_score'] ?? 0,
      urgencyLevel: json['urgency_level'] ?? 'safe',
      action: json['action'] ?? 'open_summary',
      audioUrl: json['audio_url'] ?? '',
      summaryText: json['summary_text'] ?? '',
    );
  }
}

class GameCard {
  final String id;
  final String topic_name;
  final String question;
  final String answer;
  final List<String> options;
  final String subject;

  GameCard({
    required this.id, 
    required this.topic_name, 
    required this.question, 
    required this.answer,
    this.options = const [],
    this.subject = '',
  });

  factory GameCard.fromJson(Map<String, dynamic> json) {
    return GameCard(
      id: json['id'] ?? '',
      topic_name: json['topic_name'] ?? '',
      question: json['question'] ?? '',
      answer: json['answer'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      subject: json['subject'] ?? '',
    );
  }
}

class GameMatchPair {
  final String id;
  final String match_id;
  final String text;

  GameMatchPair({required this.id, required this.match_id, required this.text});

  factory GameMatchPair.fromJson(Map<String, dynamic> json) {
    return GameMatchPair(
      id: json['id'] ?? '',
      match_id: json['match_id'] ?? '',
      text: json['text'] ?? '',
    );
  }
}

class GameSession {
  final String sessionId;
  final String type;
  final int timer;
  final List<GameCard> cards;
  final List<GameMatchPair> pairs;
  final Map<String, dynamic> bot_params;

  GameSession({
    required this.sessionId,
    required this.type,
    required this.timer,
    this.cards = const [],
    this.pairs = const [],
    this.bot_params = const {},
  });

  factory GameSession.fromJson(Map<String, dynamic> json) {
    return GameSession(
      sessionId: json['session_id'] ?? '',
      type: json['type'] ?? '',
      timer: json['timer'] ?? 0,
      cards: (json['cards'] as List? ?? []).map((c) => GameCard.fromJson(c)).toList(),
      pairs: (json['pairs'] as List? ?? []).map((p) => GameMatchPair.fromJson(p)).toList(),
      bot_params: json['bot_params'] ?? {},
    );
  }
}

class GameStatsResponse {
  final Map<String, dynamic> stats;
  final int points;

  GameStatsResponse({required this.stats, required this.points});

  factory GameStatsResponse.fromJson(Map<String, dynamic> json) {
    return GameStatsResponse(
      stats: json['stats'] ?? {},
      points: json['points'] ?? 0,
    );
  }
}

