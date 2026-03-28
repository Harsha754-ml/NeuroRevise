import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart';
import 'api_service.dart';
import 'models.dart';
import 'game_screen.dart';
import 'panic_mode_screen.dart';

class GameHubScreen extends StatefulWidget {
  final List<Topic> flashcards;
  const GameHubScreen({Key? key, required this.flashcards}) : super(key: key);

  @override
  State<GameHubScreen> createState() => _GameHubScreenState();
}

class _GameHubScreenState extends State<GameHubScreen> {
  GameStatsResponse? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    final s = await ApiService.getGameStats();
    if (mounted) {
      setState(() {
        _stats = s;
        _loading = false;
      });
    }
  }

  void _startGame(String type) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFC5A059))),
    );

    final session = await ApiService.startGame(type);
    Navigator.pop(context); // Close loading

    if (session != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameScreen(session: session)),
      ).then((_) => _fetchStats());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Signal Lost: Cannot start the arena.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.flashcards.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  ApiService.isConnected ? Icons.inventory_2_outlined : Icons.wifi_off_rounded,
                  size: 80,
                  color: const Color(0xFFC5A059).withOpacity(0.5),
                ),
                const SizedBox(height: 30),
                Text(
                  ApiService.isConnected ? "ARCHIVES EMPTY" : "BRIDGE OFFLINE",
                  style: GoogleFonts.libreCaslonText(
                    color: const Color(0xFFC5A059),
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  ApiService.isConnected 
                    ? "Your neural database is currently empty. Ingest STEM knowledge to begin training."
                    : "Cannot reach the MemoryForge server.\nTarget: ${ApiService.backendUrl}",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                if (!ApiService.isConnected) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      ApiService.discoverServer((_) {
                        if (mounted) setState(() {});
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("🔍 Searching for bridge...")),
                      );
                    },
                    icon: const Icon(Icons.search_rounded),
                    label: const Text("RETRY DISCOVERY"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () {
                      final state = context.findAncestorStateOfType<MainScreenState>();
                      if (state != null) {
                        state.setState(() => state.currentIndex = 2);
                      }
                    },
                    child: const Text("CONFIGURE MANUALLY", style: TextStyle(color: Color(0xFFC5A059))),
                  ),
                ] else
                  ElevatedButton(
                    onPressed: () {
                      final state = context.findAncestorStateOfType<MainScreenState>();
                      if (state != null) {
                        state.setState(() => state.currentIndex = 0);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFC5A059).withOpacity(0.1),
                      foregroundColor: const Color(0xFFC5A059),
                      side: const BorderSide(color: Color(0xFFC5A059)),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("ADD KNOWLEDGE", style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF0F0F11),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'GAME MODE',
                style: GoogleFonts.libreCaslonText(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  fontSize: 16,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFC5A059).withOpacity(0.2),
                          const Color(0xFF0F0F11),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: const Color(0xFFC5A059).withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildPointsCard(),
                   const SizedBox(height: 32),
                   Text(
                     "SIMULATIONS",
                     style: Theme.of(context).textTheme.labelSmall,
                   ),
                   const SizedBox(height: 16),
                   InkWell(
                     onTap: () {
                       Navigator.push(context, MaterialPageRoute(builder: (_) => PanicModeScreen(flashcards: widget.flashcards)));
                     },
                     borderRadius: BorderRadius.circular(32),
                     child: Container(
                       padding: const EdgeInsets.all(24),
                       decoration: BoxDecoration(
                         gradient: const LinearGradient(colors: [Colors.deepOrangeAccent, Colors.purpleAccent]),
                         borderRadius: BorderRadius.circular(32),
                       ),
                       child: Row(
                         children: [
                           const Icon(Icons.bolt, color: Colors.white, size: 32),
                           const SizedBox(width: 20),
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text("PANIC MODE", style: GoogleFonts.libreCaslonText(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                 const SizedBox(height: 4),
                                 Text("10-Min Rapid Subject Review", style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                               ],
                             ),
                           ),
                           const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                         ],
                       ),
                     ),
                   ),
                   const SizedBox(height: 24),
                   _buildGameItem(
                     id: 'rapid_fire',
                     name: 'Rapid Fire',
                     desc: 'Quick Q&A under extreme pressure',
                     difficulty: 'Medium',
                     color: Colors.pinkAccent,
                   ),
                   _buildGameItem(
                     id: 'match_cards',
                     name: 'Match Cards',
                     desc: 'Link terms to their definitions',
                     difficulty: 'Easy',
                     color: Colors.lightBlueAccent,
                   ),
                   _buildGameItem(
                     id: 'weak_spot',
                     name: 'Weak Spot Drill',
                     desc: 'Focus on decaying memory nodes',
                     difficulty: 'Hard',
                     color: Colors.orangeAccent,
                   ),
                   _buildGameItem(
                     id: 'battle_mode',
                     name: 'Battle Mode',
                     desc: 'Challenge the machine-mind',
                     difficulty: 'Medium',
                     color: Colors.indigoAccent,
                   ),
                   _buildGameItem(
                     id: 'panic_game',
                     name: 'Panic Game',
                     desc: 'Sub-second retrieval training',
                     difficulty: 'Extreme',
                     color: Colors.greenAccent,
                   ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF161618),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("NEURO-POINTS", style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(
                "${_stats?.points ?? 0} NP",
                style: GoogleFonts.libreCaslonText(
                  fontSize: 40,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFFC5A059),
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFC5A059).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.bolt_rounded, color: Color(0xFFC5A059), size: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildGameItem({
    required String id,
    required String name,
    required String desc,
    required String difficulty,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () => _startGame(id),
        borderRadius: BorderRadius.circular(32),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF161618).withOpacity(0.5),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(Icons.psychology_outlined, color: color, size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.libreCaslonText(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF4F1EA),
                      ),
                    ),
                    Text(
                      desc,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Colors.white38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Text(
                  difficulty,
                  style: GoogleFonts.inter(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
