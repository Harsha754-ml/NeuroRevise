import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'api_service.dart';
import 'constants.dart';
import 'models.dart';
import 'notification_service.dart';
import 'game_hub.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const MemoryForgeApp());
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class MemoryForgeApp extends StatelessWidget {
  const MemoryForgeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NeuroRevise',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F0F11),
        primaryColor: const Color(0xFFC5A059),
        cardColor: const Color(0xFF161618),
        textTheme: GoogleFonts.libreCaslonTextTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.libreCaslonText(fontWeight: FontWeight.w900, color: const Color(0xFFF4F1EA)),
          titleLarge: GoogleFonts.libreCaslonText(fontWeight: FontWeight.bold, color: const Color(0xFFF4F1EA)),
          bodyMedium: GoogleFonts.inter(color: Colors.white70),
          labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 10, color: const Color(0xFFC5A059)),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0F0F11),
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends State<MainScreen> {
  int currentIndex = 0;
  List<Topic> _flashcards = [];
  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    _initConnection();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (ApiService.isConnected) {
        _pollNotifications();
        _fetchData();
      } else {
        ApiService.discoverServer();
      }
    });
  }

    Future<void> _initConnection() async {
    // Request permission first for professional feel
    await Permission.notification.request();
    await _initFirebaseMessaging();
    await NotificationService.instance.initialize(onTap: _handleNotificationTap);
    await ApiService.discoverServer();
    _fetchData();
  }

  Future<void> _initFirebaseMessaging() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        debugPrint('FCM TOKEN: $token');
      }
      FirebaseMessaging.onMessage.listen((message) {
        final title = message.notification?.title;
        final body = message.notification?.body;
        if (title != null || body != null) {
          debugPrint('FCM FOREGROUND: ${title ?? ''} | ${body ?? ''}');
        }
      });
    } catch (e) {
      debugPrint('Firebase Messaging init failed: $e');
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    NotificationService.instance.setOnTapHandler(null);
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final cards = await ApiService.getFlashcards();
      if (mounted) {
        setState(() {
          _flashcards = cards;
        });
      }
    } catch (e) {
      debugPrint("Failed to fetch flashcards: $e");
    }
  }

  Future<void> _pollNotifications() async {
    try {
      final notifications = await ApiService.getPendingNotifications();
      if (notifications.isEmpty) {
        return;
      }

      for (var n in notifications) {
        try {
          await NotificationService.instance.showMemoryAlert(n);
          await ApiService.clearNotification(n.notificationId);
          if (n.action == 'force_quiz') {
            _handleNotificationTap(n);
          }
        } catch (_) {
          if (mounted) {
            _showBanner(n);
          }
        }
      }
    } catch (e) {
      debugPrint("Notification poll failed: $e");
    }
  }

  void _handleNotificationTap(NotificationDetail notification) {
    if (!mounted) {
      return;
    }

    if (notification.action == 'force_quiz' || notification.action == 'open_quiz') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizScreen(
            flashcardId: notification.flashcardId,
            question: notification.question,
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SummaryScreen(notification: notification)),
      );
    }
  }

  void _showBanner(NotificationDetail notification) {
    ApiService.clearNotification(notification.notificationId);

    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "MEMORY RECALL REQUIRED",
              style: Theme.of(context).textTheme.labelSmall,
            ),
            const SizedBox(height: 8),
            Text(
              "Stage: ${notification.topicName}",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        leading: const Icon(Icons.auto_awesome, color: Color(0xFFC5A059)),
        backgroundColor: const Color(0xFF1A1A1C),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentMaterialBanner();
              _handleNotificationTap(notification);
            },
            child: const Text('ENGAGE', style: TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.w900)),
          ),
          TextButton(
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentMaterialBanner(),
            child: const Text('DEFER', style: TextStyle(color: Colors.white24)),
          ),
        ],
      ),
    );
  }

  void _showAddDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F0F11),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(40))),
      builder: (context) => const AddBottomSheet(),
    ).then((_) => _fetchData());
  }

  @override
  Widget build(BuildContext context) {
    final _pages = [
        HomeScreen(flashcards: _flashcards, onRefresh: _fetchData),
        GameHubScreen(flashcards: _flashcards),
        const NexusScreen(),
      ];

    return Scaffold(
      body: _pages[currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: const Color(0xFFC5A059),
        elevation: 20,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: const Icon(Icons.add_rounded, color: Colors.black, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Colors.white10, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => setState(() => currentIndex = i),
          backgroundColor: const Color(0xFF0F0F11),
          selectedItemColor: const Color(0xFFC5A059),
          unselectedItemColor: Colors.white24,
          showSelectedLabels: false,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Clusters'),
            BottomNavigationBarItem(icon: Icon(Icons.sports_esports_rounded), label: 'Games'),
            BottomNavigationBarItem(icon: Icon(Icons.blur_on_rounded), label: 'Nexus'),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final List<Topic> flashcards;
  final VoidCallback onRefresh;

  const HomeScreen({Key? key, required this.flashcards, required this.onRefresh}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FlutterTts _tts = FlutterTts();
  String? _speakingId;

  @override
  void initState() {
    super.initState();
    _tts.setLanguage("en-US");
    _tts.setSpeechRate(0.45);
    _tts.setPitch(0.6);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speakingId = null);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleSpeak(Topic fc) async {
    if (_speakingId == fc.id) {
      await _tts.stop();
      if (mounted) setState(() => _speakingId = null);
    } else {
      await _tts.stop();
      final text = fc.summary.isNotEmpty ? fc.summary : "${fc.topicName}. ${fc.question}";
      setState(() => _speakingId = fc.id);
      await _tts.speak(text);
    }
  }

  Future<void> _deleteLesson(Topic fc) async {
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Delete Lesson"),
            content: Text("Delete all cards for ${fc.topicName}?"),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete")),
            ],
          ),
        ) ??
        false;
    if (!ok) return;

    final deleted = await ApiService.deleteLesson(fc.topicName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? "Lesson deleted." : "Failed to delete lesson.")),
    );
    if (deleted) widget.onRefresh();
  }

  Widget _buildGamesCard(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: InkWell(
        onTap: () {
          final state = context.findAncestorStateOfType<MainScreenState>();
          if (state != null) {
            state.setState(() => state.currentIndex = 1);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFC5A059), Color(0xFFD4AD68)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: const Color(0xFFC5A059).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports_esports_rounded, color: Colors.black, size: 32),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("GAME MODE", style: GoogleFonts.libreCaslonText(fontWeight: FontWeight.w900, color: Colors.black, fontSize: 18, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text("Master your memory through 5 unique game modes.", style: GoogleFonts.inter(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(),
      backgroundColor: const Color(0xFFC5A059),
      color: Colors.black,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            floating: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ApiService.isConnected ? Colors.greenAccent : Colors.redAccent,
                      boxShadow: [
                        if (ApiService.isConnected)
                          BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 4)
                      ]
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text("NEUROREVISE", style: GoogleFonts.libreCaslonText(fontWeight: FontWeight.w900, letterSpacing: 4, fontSize: 14, color: const Color(0xFFF4F1EA))),
                ],
              ),
              centerTitle: true,
            ),
          ),
          SliverToBoxAdapter(
            child: _buildGamesCard(context),
          ),
          if (widget.flashcards.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Opacity(
                  opacity: 0.5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 64, color: Color(0xFFC5A059)),
                      SizedBox(height: 20),
                      Text("The archives are empty.\nBegin your journal.", textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final fc = widget.flashcards[index];
                    final plan = fc.learningPlan;
                    final currentStage = plan?.currentStage ?? 0;
                    final isCompleted = plan?.status == 'completed';
                    final isSpeaking = _speakingId == fc.id;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFF161618),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                        boxShadow: [
                           BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 10))
                        ]
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    fc.topicName,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFFF4F1EA)),
                                  ),
                                ),
                                // TTS Speak Button
                                GestureDetector(
                                  onTap: () => _toggleSpeak(fc),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isSpeaking
                                          ? const Color(0xFFC5A059).withOpacity(0.2)
                                          : Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isSpeaking
                                            ? const Color(0xFFC5A059).withOpacity(0.5)
                                            : Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                    child: Icon(
                                      isSpeaking ? Icons.stop_rounded : Icons.volume_up_rounded,
                                      color: isSpeaking ? const Color(0xFFC5A059) : Colors.white38,
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _deleteLesson(fc),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: Colors.redAccent.withOpacity(0.25)),
                                    ),
                                    child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFC5A059).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.2)),
                                  ),
                                  child: Text(
                                    "${fc.retentionScore}%",
                                    style: const TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.w900, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            if (isSpeaking) ...[  
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.graphic_eq_rounded, color: Color(0xFFC5A059), size: 14),
                                  const SizedBox(width: 6),
                                  Text("Speaking...", style: GoogleFonts.inter(color: const Color(0xFFC5A059), fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              fc.question,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white54, fontSize: 16, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 24),
                            
                            // CHRONOS STEP INDICATOR
                            Row(
                              children: List.generate(3, (i) {
                                bool active = i < currentStage || isCompleted;
                                bool current = i == currentStage && !isCompleted;
                                return Expanded(
                                  child: Container(
                                    height: 3,
                                    margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                                    decoration: BoxDecoration(
                                      color: active ? const Color(0xFF8DA290) : (current ? const Color(0xFFC5A059).withOpacity(0.3) : Colors.white10),
                                      borderRadius: BorderRadius.circular(2),
                                      boxShadow: active ? [BoxShadow(color: const Color(0xFF8DA290).withOpacity(0.5), blurRadius: 5)] : null,
                                    ),
                                    child: current ? const LinearProgressIndicator(backgroundColor: Colors.transparent, color: Color(0xFFC5A059)) : null,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("JOURNEY STAGE", style: Theme.of(context).textTheme.labelSmall!.copyWith(color: Colors.white24)),
                                Text(
                                  isCompleted ? "OPTIMIZED" : (currentStage == 0 ? "AUDIO BRIEF" : (currentStage == 1 ? "DEEP RECAP" : "FINAL QUIZ")),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: widget.flashcards.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class AddBottomSheet extends StatefulWidget {
  const AddBottomSheet({Key? key}) : super(key: key);

  @override
  State<AddBottomSheet> createState() => _AddBottomSheetState();
}

class _AddBottomSheetState extends State<AddBottomSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _topicCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();
  final TextEditingController _ytCtrl = TextEditingController();
  bool _isLoading = false;
  DateTime? _targetCompletionAt;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  int? _targetCompletionEpoch() {
    if (_targetCompletionAt == null) return null;
    return _targetCompletionAt!.millisecondsSinceEpoch ~/ 1000;
  }

  Future<void> _pickTargetCompletion() async {
    final now = DateTime.now();
    final initial = _targetCompletionAt ?? now.add(const Duration(days: 1));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return;

    setState(() {
      _targetCompletionAt = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  void _submit(Future Function() call) async {
    setState(() => _isLoading = true);
    try {
      await call();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 30, right: 30, top: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("INGEST KNOWLEDGE", style: GoogleFonts.libreCaslonText(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const SizedBox(height: 30),
          TextField(
            controller: _topicCtrl,
            style: const TextStyle(fontSize: 20),
            decoration: InputDecoration(
              hintText: "Topic Title",
              hintStyle: const TextStyle(color: Colors.white10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              filled: true,
              fillColor: Colors.white.withOpacity(0.03),
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: _pickTargetCompletion,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Color(0xFFC5A059)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _targetCompletionAt == null
                          ? 'Set target completion time (optional)'
                          : 'Target: ${_targetCompletionAt!.toLocal().toString().substring(0, 16)}',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  if (_targetCompletionAt != null)
                    IconButton(
                      onPressed: () => setState(() => _targetCompletionAt = null),
                      icon: const Icon(Icons.close, color: Colors.white38),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFFC5A059),
            labelColor: const Color(0xFFC5A059),
            unselectedLabelColor: Colors.white24,
            dividerColor: Colors.transparent,
            tabs: const [Tab(text: "JOURNAL"), Tab(text: "STREAM"), Tab(text: "SCROLL")],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 250,
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))) 
                : TabBarView(
              controller: _tabController,
              children: [
                TextField(controller: _textCtrl, maxLines: 8, decoration: const InputDecoration(hintText: "Scribe your thoughts...", border: InputBorder.none)),
                TextField(controller: _ytCtrl, decoration: const InputDecoration(hintText: "Visual Stream URL (YouTube)", border: InputBorder.none)),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _submit(() async {
                      FilePickerResult? r = await FilePicker.platform.pickFiles();
                      if (r != null) await ApiService.ingestFile(_topicCtrl.text, File(r.files.single.path!), targetCompletionAt: _targetCompletionEpoch());
                    }), 
                    icon: const Icon(Icons.history_edu_rounded),
                    label: const Text("Select Manuscript"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.05), foregroundColor: Colors.white, shape: const StadiumBorder()),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (!_isLoading)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submit(() => _tabController.index == 0 ? ApiService.ingestText(_topicCtrl.text, _textCtrl.text, targetCompletionAt: _targetCompletionEpoch()) : ApiService.ingestYoutube(_topicCtrl.text, _ytCtrl.text, targetCompletionAt: _targetCompletionEpoch())),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.all(20), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                child: const Text("INITIATE CHRONOS PLAN", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class SummaryScreen extends StatefulWidget {
  final NotificationDetail notification;
  const SummaryScreen({Key? key, required this.notification}) : super(key: key);

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;

  void _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.notification.audioUrl));
    }
    if (mounted) setState(() => _isPlaying = !_isPlaying);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Neural Briefing")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFC5A059).withOpacity(0.2), width: 2),
                  boxShadow: [BoxShadow(color: const Color(0xFFC5A059).withOpacity(0.05), blurRadius: 40, spreadRadius: 10)],
                ),
                child: IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 100, color: const Color(0xFFC5A059)),
                  onPressed: _togglePlay,
                ),
              ),
              const SizedBox(height: 60),
              Text(widget.notification.topicName, style: GoogleFonts.libreCaslonText(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text(
                widget.notification.summaryText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, color: Colors.white54, fontStyle: FontStyle.italic),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context), 
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(20), side: const BorderSide(color: Colors.white10), shape: const StadiumBorder()),
                      child: const Text("RETAIN LATER", style: TextStyle(color: Colors.white24)),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ApiService.reviewFlashcard(widget.notification.flashcardId, 'remembered');
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC5A059), foregroundColor: Colors.black, padding: const EdgeInsets.all(20), shape: const StadiumBorder()),
                      child: const Text("ASCENDED", style: TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 60),
            ],
          ),
        ),
      ),
    );
  }
}

class QuizScreen extends StatelessWidget {
  final String flashcardId;
  final String question;

  const QuizScreen({Key? key, required this.flashcardId, required this.question}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF160808),
      body: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: Colors.redAccent, size: 80),
            const SizedBox(height: 30),
            Text("MEMORY DECAY DETECTED", style: Theme.of(context).textTheme.labelSmall!.copyWith(color: Colors.redAccent)),
            const SizedBox(height: 30),
            Text(
              question,
              textAlign: TextAlign.center,
              style: GoogleFonts.libreCaslonText(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ApiService.reviewFlashcard(flashcardId, 'remembered');
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 70), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25))),
              child: const Text("I HAVE RETAINED THIS", style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                ApiService.reviewFlashcard(flashcardId, 'forgot');
                Navigator.pop(context);
              },
              child: const Text("LOST TO TIME", style: TextStyle(color: Colors.white24)),
            ),
          ],
        ),
      ),
    );
  }
}

class NexusScreen extends StatefulWidget {
  const NexusScreen({Key? key}) : super(key: key);

  @override
  State<NexusScreen> createState() => _NexusScreenState();
}

class _NexusScreenState extends State<NexusScreen> {
  bool _demoMode = false;
  final TextEditingController _ipCtrl = TextEditingController(text: AppConstants.laptopIp);
  bool _savingReportEmail = false;
  final TextEditingController _reportEmailCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReportEmail();
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    _reportEmailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadReportEmail() async {
    final email = await ApiService.getReportEmail();
    if (!mounted) return;
    setState(() => _reportEmailCtrl.text = email);
  }

  Future<void> _saveReportEmail() async {
    final email = _reportEmailCtrl.text.trim();
    if (email.isNotEmpty && !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }

    setState(() => _savingReportEmail = true);
    final ok = await ApiService.saveReportEmail(email);
    if (!mounted) return;
    setState(() => _savingReportEmail = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Report email saved.' : 'Failed to save report email.')),
    );
  }

  Future<void> _openAIChatDialog() async {
    final questionCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) {
        bool isLoading = false;
        String? answer;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> ask() async {
              final question = questionCtrl.text.trim();
              if (question.isEmpty) return;

              setStateDialog(() {
                isLoading = true;
                answer = null;
              });

              final response = await ApiService.askAIChat(question);
              setStateDialog(() {
                isLoading = false;
                answer = response?['answer']?.toString() ?? 'No answer from AI chat.';
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF161618),
              title: const Text('AI Chat (Your Notes/PDF)'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: questionCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText: 'Ask from your uploaded topics...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (isLoading) const CircularProgressIndicator(),
                    if (!isLoading && answer != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(answer!, style: const TextStyle(color: Colors.white70)),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : ask,
                  child: const Text('Ask'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("SYSTEM NEXUS")),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text("BRIDGE CONFIGURATION", style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(30)),
            child: Column(
              children: [
                TextField(
                  controller: _ipCtrl,
                  decoration: const InputDecoration(
                    labelText: "Laptop IP Address",
                    hintText: "e.g. 192.168.1.5",
                    border: InputBorder.none,
                    icon: Icon(Icons.lan_rounded, color: Color(0xFFC5A059)),
                  ),
                ),
                const Divider(color: Colors.white10),
                TextButton.icon(
                  onPressed: () {
                    ApiService.updateBaseUrl(_ipCtrl.text);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Bridge targeted: ${ApiService.backendUrl}")),
                    );
                  },
                  icon: const Icon(Icons.sync_rounded, color: Color(0xFFC5A059)),
                  label: const Text("RECALIBRATE BRIDGE", style: TextStyle(color: Color(0xFFC5A059), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text("SYSTEM PARAMETERS", style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(30)),
            child: SwitchListTile(
              title: const Text("CHRONOS ACCELERATION"),
              subtitle: const Text("Compress 24 hours into 60 seconds."),
              value: _demoMode,
              activeThumbColor: const Color(0xFFC5A059),
              onChanged: (val) {
                setState(() => _demoMode = val);
                ApiService.setDemoMode(val);
              },
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.02), borderRadius: BorderRadius.circular(30)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("DAILY REPORT MAIL", style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 12),
                TextField(
                  controller: _reportEmailCtrl,
                  decoration: const InputDecoration(
                    labelText: "Recipient Email",
                    hintText: "student@example.com",
                    border: InputBorder.none,
                    icon: Icon(Icons.mail_outline_rounded, color: Color(0xFFC5A059)),
                  ),
                ),
                const Divider(color: Colors.white10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _savingReportEmail ? null : _saveReportEmail,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_savingReportEmail ? "SAVING..." : "SAVE REPORT EMAIL"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            title: const Text("AI CHAT ASSIST"),
            subtitle: const Text("Ask from uploaded PDF/text topics"),
            onTap: _openAIChatDialog,
            trailing: const Icon(Icons.auto_awesome_rounded, color: Colors.white24),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text("FLUSH NEURAL QUEUE"),
            onTap: () {
              ApiService.clearAllNotifications();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Queue sanitized.")));
            },
            trailing: const Icon(Icons.cleaning_services_rounded, color: Colors.white24),
          ),
        ],
      ),
    );
  }
}








