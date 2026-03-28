import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'api_service.dart';
import 'models.dart';

class GameScreen extends StatefulWidget {
  final GameSession session;
  const GameScreen({Key? key, required this.session}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  int _currentStep = 0;
  int _score = 0;
  List<String> _matches = [];
  GameMatchPair? _selection;
  Timer? _timer;
  int _timeLeft = 0;
  
  int _streak = 0;
  String? _ansStatus; // 'correct', 'wrong', null
  double _botProgress = 0.0;
  late DateTime _startTime;
  Timer? _botTimer;

  @override
  void initState() {
    super.initState();
    _timeLeft = widget.session.timer;
    _startTime = DateTime.now();
    
    if (_timeLeft > 0) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            if (_timeLeft > 0) {
              _timeLeft--;
            } else {
              _timer?.cancel();
              _finishGame();
            }
          });
        }
      });
    }

    if (widget.session.type == 'battle_mode') {
      final speed = widget.session.bot_params['speed'] ?? 2.0;
      _botTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
        if (mounted) {
          setState(() {
            _botProgress = (_botProgress + (speed / 1000 * 500)).clamp(0.0, 100.0);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _botTimer?.cancel();
    super.dispose();
  }

  void _handleOptionSelect(String option) {
    if (_ansStatus != null) return;

    final card = widget.session.cards[_currentStep];
    final isCorrect = option == card.answer;

    setState(() {
      _ansStatus = isCorrect ? 'correct' : 'wrong';
    });

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      final timeElapsed = DateTime.now().difference(_startTime).inSeconds;
      final speedBonus = (50 - timeElapsed).clamp(0, 50);
      final streakBonus = _streak * 10;
      
      _score += 50 + speedBonus + streakBonus;
      _streak++;
    } else {
      HapticFeedback.heavyImpact();
      _streak = 0;
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        if (_currentStep < widget.session.cards.length - 1) {
          setState(() {
            _currentStep++;
            _ansStatus = null;
            _startTime = DateTime.now();
          });
        } else {
          _finishGame();
        }
      }
    });
  }

  void _handleMatch(GameMatchPair pair) {
    if (_selection == null) {
      setState(() => _selection = pair);
    } else {
      if (_selection!.id != pair.id && _selection!.match_id == pair.match_id) {
        HapticFeedback.lightImpact();
        setState(() {
          _matches.add(pair.match_id);
          _score += 25;
        });
        if (_matches.length == widget.session.pairs.length ~/ 2) {
          Future.delayed(const Duration(milliseconds: 500), _finishGame);
        }
      } else {
        HapticFeedback.mediumImpact();
      }
      setState(() => _selection = null);
    }
  }

  void _finishGame() async {
    _timer?.cancel();
    _botTimer?.cancel();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
    );

    await ApiService.submitScore(widget.session.type, _score);
    if (mounted) {
      Navigator.pop(context); // Close loading
      Navigator.pop(context); // Return to Hub
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _ansStatus == 'correct' 
        ? const Color(0xFF064E3B) // emerald-950
        : _ansStatus == 'wrong'
            ? const Color(0xFF4C0519) // rose-950
            : const Color(0xFF0F0F11);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.session.type.toUpperCase().replaceAll('_', ' '),
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 2),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: Text(
                "$_score NP",
                style: GoogleFonts.inter(
                  color: const Color(0xFFC5A059),
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (widget.session.timer > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: _timeLeft / widget.session.timer,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    color: _timeLeft < 10 ? const Color(0xFFE91E63) : const Color(0xFFC5A059),
                  ),
                ),
              ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: widget.session.type == 'match_cards' 
                  ? _buildMatchUI() 
                  : _buildGameUI(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameUI() {
    final card = widget.session.cards[_currentStep];
    final isBattle = widget.session.type == 'battle_mode';
    final isPanic = widget.session.type == 'panic_game';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (isBattle) _buildBattleHeader(),
          const SizedBox(height: 20),
          _buildProgressHeader(isPanic),
          const SizedBox(height: 32),
          _buildCard(card, isPanic),
          const SizedBox(height: 40),
          _buildOptionsGrid(card),
        ],
      ),
    );
  }

  Widget _buildBattleHeader() {
    final userProgress = (_currentStep / widget.session.cards.length) * 100;
    final botWins = _botProgress > userProgress;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: botWins ? Colors.redAccent.withOpacity(0.1) : Colors.indigoAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.psychology_rounded, 
                  color: botWins ? Colors.redAccent : Colors.indigoAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "PROTOCOL: NEURO-BOT",
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 1,
                        color: Colors.white60,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _botProgress / 100,
                        minHeight: 4,
                        backgroundColor: Colors.white10,
                        color: Colors.indigoAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                botWins ? "THREAT LEVEL: CRITICAL" : "ADVANTAGE: HUMAN",
                style: GoogleFonts.inter(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: botWins ? Colors.redAccent : const Color(0xFFC5A059),
                ),
              ),
              Text(
                "${_botProgress.toInt()}% VS ${userProgress.toInt()}%",
                style: GoogleFonts.inter(fontSize: 8, color: Colors.white38),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressHeader(bool isPanic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "NEURAL LINK",
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: isPanic ? const Color(0xFFE91E63) : const Color(0xFFC5A059),
              ),
            ),
            Text(
              "${_currentStep + 1} / ${widget.session.cards.length}",
              style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        if (_streak > 1)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFC5A059),
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              "STREAK ${_streak}X",
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black),
            ),
          ),
      ],
    );
  }

  Widget _buildCard(GameCard card, bool isPanic) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(48),
        border: Border.all(
          color: isPanic ? const Color(0xFFE91E63).withOpacity(0.2) : Colors.white.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            card.subject.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white24,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            card.question,
            textAlign: TextAlign.center,
            style: GoogleFonts.libreCaslonText(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1.3,
              color: const Color(0xFFF4F1EA),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsGrid(GameCard card) {
    // If options is empty (legacy), fallback to binary
    if (card.options.isEmpty) {
      return Row(
        children: [
          Expanded(child: _buildOptionButton("I KNOW THIS", true)),
          const SizedBox(width: 16),
          Expanded(child: _buildOptionButton("SIGNAL LOSS", false)),
        ],
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5,
      ),
      itemCount: card.options.length,
      itemBuilder: (context, index) {
        return _buildOptionButton(card.options[index], card.options[index] == card.answer);
      },
    );
  }

  Widget _buildOptionButton(String text, bool isCorrect) {
    final bool isSelected = _ansStatus != null;
    final bool wasCorrectTarget = isSelected && isCorrect;
    final bool wasWrongTarget = isSelected && !isCorrect && _ansStatus == 'wrong';

    Color buttonColor = const Color(0xFF161618);
    Color textColor = Colors.white70;
    Color borderColor = Colors.white.withOpacity(0.05);

    if (isSelected) {
      if (isCorrect) {
        buttonColor = Colors.greenAccent.withOpacity(0.1);
        textColor = Colors.greenAccent;
        borderColor = Colors.greenAccent.withOpacity(0.5);
      } else if (!isCorrect && _ansStatus == 'wrong') {
        buttonColor = const Color(0xFFE91E63).withOpacity(0.1);
        textColor = const Color(0xFFE91E63);
        borderColor = const Color(0xFFE91E63).withOpacity(0.3);
      } else {
        buttonColor = Colors.white.withOpacity(0.02);
        textColor = Colors.white24;
      }
    }

    return InkWell(
      onTap: () => _handleOptionSelect(text),
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: buttonColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor, width: wasCorrectTarget ? 2 : 1),
        ),
        child: Center(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchUI() {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: widget.session.pairs.length,
      itemBuilder: (context, index) {
        final pair = widget.session.pairs[index];
        final isMatched = _matches.contains(pair.match_id);
        final isSelected = _selection?.id == pair.id;

        return InkWell(
          onTap: isMatched ? null : () => _handleMatch(pair),
          borderRadius: BorderRadius.circular(32),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isMatched 
                  ? Colors.greenAccent.withOpacity(0.05)
                  : isSelected ? const Color(0xFFC5A059) : const Color(0xFF161618),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isMatched 
                    ? Colors.greenAccent.withOpacity(0.2)
                    : isSelected ? Colors.white : Colors.white.withOpacity(0.05),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Text(
                pair.text,
                textAlign: TextAlign.center,
                style: GoogleFonts.libreCaslonText(
                  fontSize: 14,
                  color: isMatched ? Colors.greenAccent : isSelected ? Colors.black : Colors.white,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
