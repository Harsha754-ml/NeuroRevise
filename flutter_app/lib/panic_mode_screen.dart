import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models.dart';

class PanicModeScreen extends StatefulWidget {
  final List<Topic> flashcards;

  const PanicModeScreen({Key? key, required this.flashcards}) : super(key: key);

  @override
  State<PanicModeScreen> createState() => _PanicModeScreenState();
}

class _PanicModeScreenState extends State<PanicModeScreen> {
  final PageController _pageController = PageController();
  int _currentTopic = 0;
  int _timerSeconds = 600; // 10 minutes
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timerSeconds > 0 && mounted) {
        setState(() => _timerSeconds--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  String _formatTime(int s) {
    int mins = s ~/ 60;
    int secs = s % 60;
    return "$mins:${secs.toString().padLeft(2, '0')}";
  }

  List<String> _parsePoints(String summary) {
    if (summary.trim().isEmpty) return ["No critical information detected."];
    return summary
        .split(RegExp(r'\.\s+'))
        .map((e) => e.trim())
        .where((e) => e.length > 5)
        .map((e) => e.endsWith('.') ? e : '$e.')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.black, title: const Text('Panic Mode')),
        body: const Center(child: Text("No Database Found", style: TextStyle(color: Colors.white))),
      );
    }

    final double progress = (600 - _timerSeconds) / 600;
    final bool urgency = _timerSeconds <= 60;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      Icon(Icons.bolt, color: urgency ? Colors.deepOrangeAccent : Colors.purpleAccent, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        "⚡ Panic Mode",
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "${_currentTopic + 1}/${widget.flashcards.length}",
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Timer Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: urgency ? Colors.deepOrangeAccent.withOpacity(0.4) : Colors.transparent),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: urgency ? Colors.deepOrangeAccent : Colors.white54),
                            const SizedBox(width: 6),
                            Text("Time Left", style: GoogleFonts.inter(color: urgency ? Colors.deepOrangeAccent : Colors.white54, fontSize: 12, fontWeight: urgency ? FontWeight.bold : FontWeight.normal)),
                          ],
                        ),
                        Text(
                          _formatTime(_timerSeconds),
                          style: GoogleFonts.spaceMono(
                            color: urgency ? Colors.deepOrangeAccent : const Color(0xFFC5A059),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Stack(
                      children: [
                        Container(height: 8, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(4))),
                        FractionallySizedBox(
                          widthFactor: progress.clamp(0.0, 1.0),
                          child: AnimatedContainer(
                            duration: const Duration(seconds: 1),
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: urgency 
                                    ? [Colors.deepOrangeAccent, Colors.redAccent]
                                    : [const Color(0xFFC5A059), Colors.purpleAccent],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Topic Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.flashcards.length, (index) {
                  bool isActive = index == _currentTopic;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    height: 4,
                    width: isActive ? 24 : 8,
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFFC5A059) : Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            ),

            // Swipeable Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.flashcards.length,
                onPageChanged: (idx) {
                  setState(() => _currentTopic = idx);
                },
                itemBuilder: (context, index) {
                  final topic = widget.flashcards[index];
                  final points = _parsePoints(topic.summary);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Topic Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(topic.sourceType.toUpperCase(), style: GoogleFonts.inter(color: const Color(0xFFC5A059).withOpacity(0.8), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(topic.topicName, style: GoogleFonts.libreCaslonText(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Key Points
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.bookmark, color: Color(0xFFC5A059), size: 16),
                                  const SizedBox(width: 8),
                                  Text("📌 KEY POINTS", style: GoogleFonts.inter(color: const Color(0xFFC5A059), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ...points.map((pt) => Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(margin: const EdgeInsets.only(top: 6, right: 12), width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFC5A059), shape: BoxShape.circle)),
                                    Expanded(child: Text(pt, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.9), fontSize: 14, height: 1.5))),
                                  ],
                                ),
                              )),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Quick Tricks
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.purpleAccent.withOpacity(0.2)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lightbulb, color: Colors.purpleAccent, size: 16),
                                  const SizedBox(width: 8),
                                  Text("💡 QUICK TRICKS", style: GoogleFonts.inter(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Q: ${topic.question}", style: GoogleFonts.inter(color: Colors.white.withOpacity(0.85), fontSize: 13, height: 1.4, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text("A: ${topic.answer}", style: GoogleFonts.inter(color: Colors.purpleAccent.withOpacity(0.9), fontSize: 13, height: 1.4)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Navigation Controls
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    color: Colors.white54,
                    onPressed: _currentTopic > 0 
                        ? () => _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFC5A059),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _currentTopic < widget.flashcards.length - 1
                          ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Panic Session Complete!')));
                              Navigator.pop(context);
                            },
                      child: Text(
                        _currentTopic < widget.flashcards.length - 1 ? "Next Topic" : "Finish Review",
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    color: Colors.white54,
                    onPressed: _currentTopic < widget.flashcards.length - 1
                        ? () => _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut)
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
