import React, { useState, useEffect, useRef, useMemo } from 'react';
import { AreaChart, Area, LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid, PieChart, Pie, Cell } from 'recharts';
import { Activity, Brain, Server, RefreshCw, Layers, ShieldCheck, Zap, AlertTriangle, Terminal, Upload, Link, Type, Send, CheckCircle2, X as CloseIcon, Clock, Sparkles, User, Database, Globe, Cpu, Play, Square, Trash2 } from 'lucide-react';

const API_BASE = `http://${window.location.hostname}:8000`;
const WS_URL = `ws://${window.location.hostname}:8000/ws`;

// HUMANLY HELPER COMPONENTS
const StatusCard = ({ label, value, icon, sub, urgency }) => (
  <div className={`bg-[#0f0f11] rounded-[2.5rem] p-8 border border-white/5 relative group hover:border-[#c5a059]/20 transition-all shadow-xl overflow-hidden`}>
     {urgency === 'critical' && <div className="absolute top-0 right-0 w-24 h-24 bg-rose-500/5 rounded-full blur-[40px] -mr-12 -mt-12" />}
     <div className="flex justify-between items-start mb-6">
        <div className="p-4 bg-white/[0.03] rounded-2xl group-hover:scale-110 transition-transform">
           {icon}
        </div>
        <span className="text-[9px] font-black text-slate-600 uppercase tracking-widest leading-none mt-2">{label}</span>
     </div>
     <div className="space-y-1">
        <p className={`text-4xl font-black tracking-tighter ${urgency === 'critical' ? 'text-rose-400' : 'text-[#f4f1ea]'}`}>{value}</p>
        <p className="text-[10px] font-serif italic text-slate-500">{sub}</p>
     </div>
  </div>
);

// HUMANLY MOCK DATA - THE "NEURAL SIMULATION" LAYER
const MOCK_FLASHCARDS = [
  { 
    id: "m1", topic_name: "Philosophy: Stocism", urgency_level: "safe", retention_score: 94, stability: 120, next_reminder_minutes: 480,
    question: "What is the 'Dichotomy of Control' as defined by Epictetus?",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 90 + Math.random() * 10 }))
  },
  { 
    id: "m2", topic_name: "Quantum Mechanics", urgency_level: "critical", retention_score: 38, stability: 12, next_reminder_minutes: 15,
    question: "Define the Heisenberg Uncertainty Principle in terms of position and momentum.",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 80 - (i * 12) }))
  },
  { 
    id: "m3", topic_name: "React: Performance", urgency_level: "warning", retention_score: 72, stability: 45, next_reminder_minutes: 120,
    question: "When should useMemo be favored over simple memoization?",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 95 - (i * 5) }))
  },
  { 
    id: "m4", topic_name: "Growth Strategy", urgency_level: "danger", retention_score: 55, stability: 24, next_reminder_minutes: 30,
    question: "Explain the AARRR (Pirate Metrics) framework for SaaS.",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 70 - (i * 8) }))
  },
  { 
    id: "m5", topic_name: "Neuroscience", urgency_level: "safe", retention_score: 88, stability: 96, next_reminder_minutes: 720,
    question: "What role does the hippocampus play in memory consolidation?",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 85 + Math.random() * 5 }))
  },
  { 
    id: "m6", topic_name: "Microservices", urgency_level: "warning", retention_score: 65, stability: 36, next_reminder_minutes: 90,
    question: "What is the Saga Pattern used for in distributed systems?",
    curve_points: Array.from({length: 10}, (_, i) => ({ day: i, score: 88 - (i * 6) }))
  }
];

const MOCK_TREND = [
  { day: 'Mon', load: 45, retention: 82 },
  { day: 'Tue', load: 52, retention: 85 },
  { day: 'Wed', load: 68, retention: 79 },
  { day: 'Thu', load: 75, retention: 74 },
  { day: 'Fri', load: 88, retention: 81 },
  { day: 'Sat', load: 92, retention: 88 },
  { day: 'Sun', load: 95, retention: 91 },
];

const COLORS = ['#6366f1', '#10b981', '#f59e0b', '#f43f5e', '#8b5cf6'];





function App() {
  const [data, setData] = useState({
    flashcards: [],
    events: [],
    dashboard: { total_cards: 0, critical_cards: 0, warning_cards: 0, active_plans: 0, demo_mode: false, presentation_mode: false }
  });
  const [isConnected, setIsConnected] = useState(false);
  const [ingestType, setIngestType] = useState('text');
  const [ingestLoading, setIngestLoading] = useState(false);
  const [ingestSuccess, setIngestSuccess] = useState(false);
  const [simulationMode, setSimulationMode] = useState(false);
  
  // UI Form States
  const [topicName, setTopicName] = useState('');
  const [textContent, setTextContent] = useState('');
  const [youtubeUrl, setYoutubeUrl] = useState('');
  const [targetCompletionAt, setTargetCompletionAt] = useState('');
  const [reportEmail, setReportEmail] = useState('');
  const [savingEmail, setSavingEmail] = useState(false);
  const [activeTab, setActiveTab] = useState('dashboard');
  const [activeGame, setActiveGame] = useState(null);
  const [gameSession, setGameSession] = useState(null);
  const [gameLoading, setGameLoading] = useState(false);
  const [gameStats, setGameStats] = useState({ stats: {}, points: 0 });
  const [speakingId, setSpeakingId] = useState(null);
  const fileInputRef = useRef(null);

  useEffect(() => {
    let ws;
    const connect = () => {
      ws = new WebSocket(WS_URL);
      ws.onopen = () => setIsConnected(true);
      ws.onmessage = (event) => {
        try {
          const parsed = JSON.parse(event.data);
          // Defensive check to prevent crash if backend sends incomplete data
          if (parsed && Array.isArray(parsed.flashcards)) {
            setData(parsed);
            if (parsed.game_stats && parsed.neuro_points !== undefined) {
               setGameStats({ stats: parsed.game_stats, points: parsed.neuro_points });
            }
            setSimulationMode(parsed.flashcards.length === 0);
          } else {
            console.warn("⚠️ Received Malformed Data from Relay:", parsed);
          }
        } catch(e) {
          console.error("❌ Signal Extraction Failed:", e);
        }
      };
      ws.onclose = () => {
        setIsConnected(false);
        setSimulationMode(true); // Default to simulation if server is down
        setTimeout(connect, 3000);
      };
    };
    connect();
    
    // Fetch game stats
    const fetchStats = async () => {
      try {
        const resp = await fetch(`${API_BASE}/game/stats`);
        const d = await resp.json();
        setGameStats(d);
      } catch(e) {}
    };
    fetchStats();

    const fetchReportEmail = async () => {
      try {
        const resp = await fetch(`${API_BASE}/settings/report-email`);
        if (!resp.ok) return;
        const d = await resp.json();
        setReportEmail(d?.email || '');
      } catch (e) {}
    };
    fetchReportEmail();

    return () => { if (ws) ws.close(); };
  }, []);

  // Determine which data to show
  const getPlanForTopic = (topicId) => {
     return (data.learning_plans || []).find(p => p.topic_id === topicId);
  };

  const playAudioSummary = (id, text) => {
     if (speakingId === id) {
        window.speechSynthesis.cancel();
        setSpeakingId(null);
        return;
     }

     window.speechSynthesis.cancel();
     if (!text) return;

     const utter = new SpeechSynthesisUtterance(text);
     
     // Attempt to grab a male voice if available (sometimes browser specific)
     const voices = window.speechSynthesis.getVoices();
     const maleVoice = voices.find(v => v.name.toLowerCase().includes('male') || v.name.toLowerCase().includes('guy'));
     if (maleVoice) utter.voice = maleVoice;
     
     utter.rate = 0.9;
     utter.pitch = 0.6; // Deepen the tone to sound more masculine
     
     utter.onend = () => setSpeakingId(null);
     utter.onerror = () => setSpeakingId(null);
     
     setSpeakingId(id);
     window.speechSynthesis.speak(utter);
  };

  const activeCards = useMemo(() => {
    return simulationMode || data.flashcards.length === 0 ? MOCK_FLASHCARDS : data.flashcards;
  }, [simulationMode, data.flashcards]);

  const activeEvents = useMemo(() => {
    if (data.events.length > 0) return data.events;
    return [
      { text: "Neural Link Initialized", timestamp: Date.now()/1000 - 3600 },
      { text: "Cognitive Load Balancing...", timestamp: Date.now()/1000 - 1800 },
      { text: "Heuristic Search Optimized", timestamp: Date.now()/1000 - 600 }
    ];
  }, [data.events]);

  const stats = useMemo(() => {
    if (simulationMode) {
      return { total: 124, safe: 88, critical: 12 };
    }
    return { total: data.dashboard.total_cards, safe: data.dashboard.total_cards - data.dashboard.critical_cards - data.dashboard.warning_cards, critical: data.dashboard.critical_cards };
  }, [simulationMode, data.dashboard]);

  const startGame = async (type) => {
    setGameLoading(true);
    try {
      const resp = await fetch(`${API_BASE}/game/start/${type}`);
      const session = await resp.json();
      if (session.error) {
        alert(session.error);
        return;
      }
      setGameSession(session);
      setActiveGame(type);
    } catch(e) {
      alert("Signal Lost: Cannot start the arena.");
    } finally {
      setGameLoading(false);
    }
  };

  const submitScore = async (type, score, result = null) => {
    try {
      const payload = { score };
      if (result !== null && result !== undefined) payload.result = result;

      const resp = await fetch(`${API_BASE}/game/score/${type}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (!resp.ok) return;

      const d = await resp.json();
      setGameStats(prev => ({ ...prev, points: d.points, stats: { ...prev.stats, [type]: d.stats } }));
      // hard-refresh stats from server so NP never gets visually stale
      try {
        const latestResp = await fetch(`${API_BASE}/game/stats`);
        if (latestResp.ok) {
          const latest = await latestResp.json();
          setGameStats(latest);
        }
      } catch (_) {}
      setActiveGame(null);
      setGameSession(null);
    } catch(e) {}
  };

  const handleIngest = async (e) => {
    e.preventDefault();
    
    // Validation with User Feedback
    if (!topicName.trim()) {
      return alert("⚠️ Identification Required: Please enter a name for this Knowledge Cluster (Topic Name).");
    }
    
    if (ingestType === 'text' && !textContent.trim()) {
      return alert("⚠️ Content Empty: Please paste the text you wish to analyze.");
    }
    
    if (ingestType === 'youtube' && !youtubeUrl.trim()) {
      return alert("⚠️ URL Missing: Please provide a valid YouTube link.");
    }
    
    if (ingestType === 'file' && (!fileInputRef.current?.files || fileInputRef.current.files.length === 0)) {
      return alert('File missing: select a .pdf or .txt file.');
    }

    if (ingestType === 'file') {
      const file = fileInputRef.current.files[0];
      const lowerName = (file?.name || '').toLowerCase();
      if (!(lowerName.endsWith('.pdf') || lowerName.endsWith('.txt'))) {
        return alert('Unsupported format: only .pdf and .txt are allowed.');
      }
    }

    setIngestLoading(true);
    setIngestSuccess(false);

    try {
      let endpoint = ingestType === 'text' ? '/ingest/text' : ingestType === 'youtube' ? '/ingest/youtube' : '/ingest/file';
      let body;
      let headers = {};

      if (ingestType === 'file') {
        body = new FormData();
        body.append('topic_name', topicName);
        if (targetCompletionAt) body.append('target_completion_at', String(Date.parse(targetCompletionAt) / 1000));
        body.append('file', fileInputRef.current.files[0]);
        // Note: fetch automatically sets multipart/form-data boundary
      } else {
        headers = { 'Content-Type': 'application/json' };
        body = JSON.stringify({ 
          topic_name: topicName, 
          [ingestType === 'text' ? 'text' : 'url']: ingestType === 'text' ? textContent : youtubeUrl,
          target_completion_at: targetCompletionAt ? (Date.parse(targetCompletionAt) / 1000) : null
        });
      }

      console.log(`Transmitting to ${API_BASE}${endpoint}...`);
      const response = await fetch(`${API_BASE}${endpoint}`, {
        method: 'POST',
        headers: headers,
        body: body
      });

      let responseData = {};
      const contentType = response.headers.get('content-type') || '';
      if (contentType.includes('application/json')) {
        responseData = await response.json();
      } else {
        const raw = await response.text();
        try {
          responseData = raw ? JSON.parse(raw) : {};
        } catch (_) {
          responseData = { detail: raw || 'Unexpected server response' };
        }
      }

      if (response.ok) {
        console.log("Ingestion successful:", responseData);
        setIngestSuccess(true);
        // Clear inputs on success
        setTopicName('');
        setTextContent('');
        setYoutubeUrl('');
        setTargetCompletionAt('');
        if (fileInputRef.current) fileInputRef.current.value = '';
        
        // Disable simulation once real data is present
        setSimulationMode(false);
        
        setTimeout(() => setIngestSuccess(false), 5000);
      } else {
        console.error("Server Error:", responseData);
        alert(`❌ Neural Link Failure: ${responseData.detail || "The backend rejected the transmission."}`);
      }
    } catch (err) {
      console.error("Network Exception:", err);
      alert(`Upload failed: ${err?.message || 'Unable to process upload request.'}`);
    } finally {
      setIngestLoading(false);
    }
  };

  const handleTogglePresentation = async (enabled) => {
     setData(prev => ({
       ...prev,
       dashboard: { ...(prev.dashboard || {}), presentation_mode: enabled }
     }));

     try {
        const resp = await fetch(`${API_BASE}/settings/presentation-mode`, {
           method: 'POST',
           headers: { 'Content-Type': 'application/json' },
           body: JSON.stringify({ enabled })
        });
        if (!resp.ok) {
          throw new Error('Failed to save presentation mode');
        }
     } catch (e) {
        console.error("Toggle Failed:", e);
        setData(prev => ({
          ...prev,
          dashboard: { ...(prev.dashboard || {}), presentation_mode: !enabled }
        }));
     }
  };

  const handleSaveReportEmail = async () => {
     const email = reportEmail.trim();
     if (email && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
       alert('Please enter a valid email address.');
       return;
     }

     setSavingEmail(true);
     try {
       const resp = await fetch(`${API_BASE}/settings/report-email`, {
         method: 'POST',
         headers: { 'Content-Type': 'application/json' },
         body: JSON.stringify({ email })
       });
       const d = await resp.json();
       if (!resp.ok) {
         alert(`Failed to save email: ${d?.detail || 'Unknown error'}`);
         return;
       }
       alert(email ? 'Report email saved. Daily reports will use this email.' : 'Report email cleared.');
       setData(prev => ({
         ...prev,
         dashboard: { ...(prev.dashboard || {}), report_email: email }
       }));
     } catch (e) {
       alert('Failed to save report email. Check backend connection.');
     } finally {
       setSavingEmail(false);
     }
  };

  const scrollToSection = (id) => {
    const el = document.getElementById(id);
    if (el) el.scrollIntoView({ behavior: 'smooth', block: 'start' });
  };

  const handlePanicMode = async () => {
    const realCards = (data.flashcards || []).filter((c) => c?.id && !String(c.id).startsWith('m'));
    if (!realCards.length) {
      alert('No real cards found yet. Upload content first.');
      return;
    }

    const sorted = [...realCards].sort((a, b) => (a.retention_score ?? 100) - (b.retention_score ?? 100));
    const target = sorted[0];
    try {
      const res = await fetch(`${API_BASE}/notifications/trigger-manual/${target.id}`, { method: 'POST' });
      if (!res.ok) throw new Error('panic trigger failed');
      alert(`Panic mode triggered for: ${target.topic_name}`);
    } catch (e) {
      alert('Panic mode failed. Check backend connection.');
    }
  };

  const handleAIChatQuick = async () => {
    const question = window.prompt('Ask AI Chat (from your uploaded notes/PDF):');
    if (!question || !question.trim()) return;

    try {
      const resp = await fetch(`${API_BASE}/ai/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ question: question.trim(), top_k: 5 })
      });

      const d = await resp.json();
      if (!resp.ok) {
        alert(`AI chat failed: ${d?.detail || 'Unknown error'}`);
        return;
      }

      let sources = '';
      if (Array.isArray(d.sources) && d.sources.length) {
        sources = `\n\nSources: ${d.sources.join(', ')}`;
      }
      alert(`AI Chat\n\n${d.answer || 'No answer generated.'}${sources}`);
    } catch (e) {
      alert('AI chat unavailable. Check backend connection.');
    }
  };


  // -----------------
  // GAME COMPONENTS
  // -----------------
  const GameHub = () => (
    <div className="space-y-12 animate-in fade-in slide-in-from-bottom-4 duration-700">
      <div className="flex justify-between items-end">
        <div>
          <h2 className="text-5xl font-black tracking-tighter text-[#f4f1ea] mb-2 uppercase">Game Mode</h2>
          <p className="text-slate-500 font-serif italic text-lg">Hone your retrieval capabilities across 5 distinct simulations.</p>
        </div>
        <div className="bg-[#1a1a1c] border border-white/5 rounded-2xl px-6 py-4 flex items-center gap-4 shadow-2xl">
           <Cpu className="text-[#c5a059]" />
           <div>
              <p className="text-[10px] font-black uppercase tracking-widest text-slate-500 leading-none mb-1">Total Reward</p>
              <p className="text-2xl font-black text-[#c5a059] leading-none">{gameStats.points} NP</p>
           </div>
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4">
        {[
          { id: 'rapid_fire', name: 'Rapid Fire', desc: 'Quick Q&A under extreme time pressure', diff: 'Medium', color: 'bg-rose-500' },
          { id: 'match_cards', name: 'Match Cards', desc: 'Spatially link concepts to their definitions', diff: 'Easy', color: 'bg-sky-500' },
          { id: 'weak_spot', name: 'Weak Spot Drill', desc: 'Surgical focus on your most decayed nodes', diff: 'Hard', color: 'bg-amber-500' },
          { id: 'battle_mode', name: 'Battle Mode', desc: 'Compete against the machine-mind (NeuroBot)', diff: 'Medium', color: 'bg-indigo-500' },
          { id: 'panic_game', name: 'Panic Game', desc: 'Sub-second retrieval simulation', diff: 'Extreme', color: 'bg-emerald-500' }
        ].map(g => (
          <div key={g.id} 
               onClick={() => startGame(g.id)}
               className="group bg-[#0f0f11] border border-white/5 rounded-[2rem] p-8 flex items-center justify-between hover:border-white/10 hover:bg-[#151518] transition-all cursor-pointer">
            <div className="flex items-center gap-8">
              <div className={`p-6 rounded-3xl ${g.color}/10 text-white group-hover:scale-110 transition-transform`}>
                <Zap size={32} className={`${g.color.replace('bg-', 'text-')}`} />
              </div>
              <div>
                <h3 className="text-2xl font-black text-[#f4f1ea] tracking-tight mb-1">{g.name}</h3>
                <p className="text-slate-500 italic text-sm font-serif">{g.desc}</p>
              </div>
            </div>
            <div className="flex items-center gap-6">
              <span className={`px-4 py-1.5 rounded-full text-[10px] font-black uppercase tracking-widest ${g.color}/20 ${g.color.replace('bg-', 'text-')} border border-white/5`}>
                {g.diff}
              </span>
              <div className="p-3 bg-white/5 rounded-full text-white opacity-0 group-hover:opacity-100 transition-opacity">
                <Play size={16} />
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );

  const GameOverlay = () => {
    const [currentStep, setCurrentStep] = useState(0);
    const [score, setScore] = useState(0);
    const [matches, setMatches] = useState([]);
    const [selection, setSelection] = useState(null);
    const [streak, setStreak] = useState(0);
    const [ansStatus, setAnsStatus] = useState(null); // 'correct' | 'wrong' | null
    const [botProgress, setBotProgress] = useState(0);
    const [startTime] = useState(Date.now());

    useEffect(() => {
      if (activeGame === 'battle_mode' && gameSession) {
        const interval = setInterval(() => {
          setBotProgress(p => Math.min(p + (gameSession.bot_params.speed / 2), 100));
        }, 1000);
        return () => clearInterval(interval);
      }
    }, [activeGame, gameSession]);

    if (!gameSession) return null;

    const handleOptionSelect = (option) => {
      if (ansStatus) return;
      
      const isCorrect = option === (gameSession.mode === 'match' ? '' : gameSession.cards[currentStep].answer);
      setAnsStatus(isCorrect ? 'correct' : 'wrong');

      let pointsEarned = 0;
      if (isCorrect) {
        const timeElapsed = (Date.now() - startTime) / 1000;
        const speedBonus = Math.max(0, Math.floor(50 - timeElapsed));
        const streakBonus = streak * 10;
        pointsEarned = 50 + speedBonus + streakBonus;
        setScore(s => s + pointsEarned);
        setStreak(s => s + 1);
      } else {
        setStreak(0);
      }

      setTimeout(() => {
        setAnsStatus(null);
        if (currentStep < gameSession.cards.length - 1) {
          setCurrentStep(s => s + 1);
        } else {
          submitScore(activeGame, score + pointsEarned);
        }
      }, 600);
    };

    if (activeGame === 'match_cards') {
      const handleMatch = (item) => {
        if (!selection) {
          setSelection(item);
        } else {
          if (selection.id !== item.id && selection.match_id === item.match_id) {
            setMatches([...matches, selection.match_id]);
            const isFinalPair = matches.length + 1 === gameSession.pairs.length / 2;
            setScore(prev => {
              const nextScore = prev + 25;
              if (isFinalPair) {
                setTimeout(() => submitScore('match_cards', nextScore), 1000);
              }
              return nextScore;
            });
          }
          setSelection(null);
        }
      };

      return (
        <div className="fixed inset-0 z-[100] bg-black/95 backdrop-blur-xl flex flex-col items-center justify-center p-12 overflow-y-auto">
           <button onClick={() => { setActiveGame(null); setGameSession(null); }} className="absolute top-12 right-12 text-slate-500 hover:text-white transition-colors">
              <CloseIcon size={48} />
           </button>
           
           <div className="mb-12 text-center">
             <h2 className="text-6xl font-black text-white tracking-tighter uppercase mb-4">Neural Mapping</h2>
             <p className="text-sky-400 font-mono tracking-widest text-xl">Score: {score} NP</p>
           </div>

           <div className="grid grid-cols-2 lg:grid-cols-4 gap-6 max-w-6xl w-full pb-12">
              {gameSession.pairs.map(p => {
                const isMatched = matches.includes(p.match_id);
                const isSelected = selection?.id === p.id;
                return (
                  <div 
                    key={p.id}
                    onClick={() => !isMatched && handleMatch(p)}
                    className={`h-40 rounded-[2rem] p-6 flex items-center justify-center text-center cursor-pointer transition-all border-2
                      ${isMatched ? 'bg-emerald-500/10 border-emerald-500/40 text-emerald-300 opacity-40 scale-95' : 
                        isSelected ? 'bg-[#c5a059] border-white text-white rotate-2 scale-105' : 
                        'bg-[#1a1a1c] border-white/5 text-slate-300 hover:border-white/20'}
                    `}
                  >
                    <p className="font-serif italic text-base leading-tight">{p.text}</p>
                  </div>
                );
              })}
           </div>
        </div>
      );
    }

    const currentCard = gameSession.cards[currentStep];
    const isBattle = activeGame === 'battle_mode';
    const isPanic = activeGame === 'panic_game';

    return (
      <div className={`fixed inset-0 z-[100] transition-colors duration-500 flex flex-col items-center justify-center p-12
        ${ansStatus === 'correct' ? 'bg-emerald-950/90' : ansStatus === 'wrong' ? 'bg-rose-950/90' : 'bg-black/95'} backdrop-blur-xl`}>
         <button onClick={() => { setActiveGame(null); setGameSession(null); }} className="absolute top-12 right-12 text-slate-500 hover:text-white transition-colors">
            <CloseIcon size={48} />
         </button>

         <div className="max-w-4xl w-full">
            <div className="flex justify-between items-end mb-12">
               <div>
                  <div className="flex items-center gap-3 mb-2">
                    <p className={`${isPanic ? 'text-rose-500 animate-pulse' : 'text-[#c5a059]'} font-black uppercase tracking-[0.2em] text-sm`}>
                      {activeGame.replace('_', ' ')} Simulation
                    </p>
                    {streak > 1 && (
                      <span className="bg-[#c5a059] text-black text-[10px] font-black px-2 py-0.5 rounded-full animate-bounce">
                        STREAK {streak}x
                      </span>
                    )}
                  </div>
                  <h2 className="text-4xl font-black text-white tracking-tighter uppercase">Neural Link {currentStep + 1} / {gameSession.cards.length}</h2>
               </div>
               <div className="text-right">
                  <p className="text-slate-500 text-xs font-black uppercase mb-1">Total Harvest</p>
                  <p className="text-3xl font-black text-[#c5a059]">{score} NP</p>
               </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-8 items-start">
              <div className={`${isBattle ? 'lg:col-span-8' : 'lg:col-span-12'} bg-[#0f0f11] border border-white/5 rounded-[3rem] p-12 shadow-2xl relative overflow-hidden`}>
                 <div className={`absolute top-0 left-0 h-1.5 ${isPanic ? 'bg-rose-500' : 'bg-[#c5a059]'} transition-all duration-300`} 
                      style={{ width: `${((currentStep + 1) / gameSession.cards.length) * 100}%` }} />
                 
                 <div className="flex justify-between items-start mb-8">
                    <p className="text-sm text-slate-500 font-serif italic">Origin: {currentCard.subject || currentCard.topic_name}</p>
                    {isPanic && (
                        <div className="flex items-center gap-2 text-rose-500 font-black animate-pulse">
                           <Zap size={16} />
                           <span className="text-[10px] tracking-widest uppercase">Panic Signal</span>
                        </div>
                    )}
                 </div>

                 <h3 className="text-3xl font-black text-[#f4f1ea] leading-tight mb-12 min-h-[120px] flex items-center">
                    {currentCard.question}
                 </h3>
                 
                 <div className="grid grid-cols-2 gap-4">
                    {(currentCard.options || [currentCard.answer, "Error A", "Error B", "Error C"]).map((opt, idx) => (
                      <button 
                        key={idx}
                        onClick={() => handleOptionSelect(opt)}
                        disabled={!!ansStatus}
                        className={`p-6 rounded-2xl text-left transition-all border-2 group
                          ${ansStatus && opt === currentCard.answer ? 'bg-emerald-500 border-white text-white' : 
                            ansStatus && opt !== currentCard.answer ? 'bg-rose-950/50 border-rose-500/20 text-rose-500 opacity-50' :
                            'bg-white/5 border-white/5 text-slate-300 hover:border-white/20 hover:bg-white/10'}
                        `}
                      >
                        <div className="flex justify-between items-center">
                          <span className="font-bold text-lg">{opt}</span>
                          <div className={`w-6 h-6 rounded-full border border-white/20 flex items-center justify-center transition-all
                            ${ansStatus && opt === currentCard.answer ? 'bg-white text-emerald-500 border-white' : 'group-hover:border-white'}`}>
                            {ansStatus && opt === currentCard.answer ? '✓' : idx + 1}
                          </div>
                        </div>
                      </button>
                    ))}
                 </div>
              </div>

              {isBattle && (
                <div className="lg:col-span-4 space-y-4">
                  <div className="bg-[#1a1a1c] border border-white/5 rounded-[2.5rem] p-8 text-center shadow-xl">
                    <div className={`w-20 h-20 rounded-full mx-auto mb-6 flex items-center justify-center border-4 transition-all
                      ${botProgress > ((currentStep / gameSession.cards.length) * 100) ? 'bg-rose-500/20 border-rose-500 animate-pulse' : 'bg-indigo-500/20 border-indigo-500'}`}>
                      <Cpu size={32} className={botProgress > ((currentStep / gameSession.cards.length) * 100) ? 'text-rose-500' : 'text-indigo-400'} />
                    </div>
                    <h4 className="text-xl font-black text-white uppercase tracking-tighter mb-2">Protocol: NeuroBot</h4>
                    <p className="text-slate-500 font-mono text-[10px] uppercase tracking-[0.2em] mb-6">Threat Level: Calculated</p>
                    
                    <div className="space-y-4">
                      <div className="space-y-1.5">
                        <div className="flex justify-between text-[10px] font-black uppercase tracking-widest text-slate-500">
                          <span>Machine Progress</span>
                          <span className="text-indigo-400">{Math.round(botProgress)}%</span>
                        </div>
                        <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden">
                          <div className="h-full bg-indigo-500 transition-all duration-1000" style={{ width: `${botProgress}%` }} />
                        </div>
                      </div>

                      <div className="space-y-1.5">
                        <div className="flex justify-between text-[10px] font-black uppercase tracking-widest text-slate-500">
                          <span>Human Progress</span>
                          <span className="text-[#c5a059]">{Math.round((currentStep / gameSession.cards.length) * 100)}%</span>
                        </div>
                        <div className="h-2 w-full bg-white/5 rounded-full overflow-hidden">
                          <div className="h-full bg-[#c5a059] transition-all duration-300" style={{ width: `${(currentStep / gameSession.cards.length) * 100}%` }} />
                        </div>
                      </div>
                    </div>
                  </div>
                  <div className="bg-[#0f0f11] border border-white/5 rounded-2xl p-6 italic font-serif text-slate-500 text-sm leading-relaxed border-l-4 border-l-indigo-500">
                    "Cognitive baseline detected. Initiating competitive neural restructuring."
                  </div>
                </div>
              )}
            </div>
         </div>
      </div>
    );
  };


  const handleDeleteLesson = async (topicName) => {
    if (!topicName) return;
    const ok = window.confirm(`Delete lesson "${topicName}"? This will remove all uploaded cards for this topic.`);
    if (!ok) return;

    try {
      const resp = await fetch(`${API_BASE}/lesson?topic_name=${encodeURIComponent(topicName)}`, { method: 'DELETE' });
      const d = await resp.json();
      if (!resp.ok) {
        alert(`Delete failed: ${d?.detail || 'Unknown error'}`);
        return;
      }

      setData((prev) => ({
        ...prev,
        flashcards: (prev.flashcards || []).filter((f) => f.topic_name !== topicName),
      }));
      alert(`Deleted lesson: ${topicName}`);
    } catch (e) {
      alert('Delete failed. Check backend connection.');
    }
  };
  const handleManualTrigger = async (cardId) => {
     // Handle Simulation Mode / Mock IDs
     if (cardId && cardId.toString().startsWith('m')) {
        return alert("⚡ Synaptic Pulse Simulated: Signal sent to virtual neural link (Simulation Mode). Upload real data to trigger actual devices.");
     }

     try {
        const res = await fetch(`${API_BASE}/notifications/trigger-manual/${cardId}`, { method: 'POST' });
        const resData = await res.json();
        if (res.ok) {
           alert("⚡ Synaptic Pulse Transmitted: Signal sent to mobile device.");
        } else {
           alert("❌ Transmission Failed: " + (resData.detail || "Unknown error"));
        }
     } catch (e) {
        console.error("Manual Trigger Failed:", e);
        alert("❌ Transmission Error: Could not reach the NeuroRevise server.");
     }
  };

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-[#0a0a0b] text-[#f4f1ea] font-sans selection:bg-[#c5a059]/30">
      
      {/* SIDEBAR - NEURAL ARCHITECTURE */}
      <aside className="w-80 h-full flex flex-col bg-[#0f0f11] border-r border-white/5 z-20 shadow-[10px_0_30px_rgba(0,0,0,0.8)] glass-morphism">
        <div className="p-8 pb-4">
           <div className="flex items-center gap-4 mb-8 group cursor-pointer" onClick={() => setSimulationMode(!simulationMode)}>
              <div className="w-11 h-11 bg-[#c5a059] rounded-xl shadow-[0_0_25px_rgba(197,160,89,0.3)] flex items-center justify-center border border-white/5 group-hover:rotate-6 transition-transform">
                 <Brain className="w-6 h-6 text-black" />
              </div>
              <div>
                 <h1 className="text-2xl font-bold font-serif text-[#c5a059] tracking-tight">NeuroRevise</h1>
                 <p className="text-[11px] text-[#8da290] tracking-[0.08em] leading-relaxed max-w-[220px]">AI-powered study companion. Learn smarter, stress less.</p>
              </div>
           </div>

           <div className={`p-5 rounded-[2rem] border transition-all duration-700 mb-8 ${isConnected ? 'bg-[#8da290]/5 border-[#8da290]/20' : 'bg-rose-500/5 border-rose-500/20'}`}>
              <div className="flex items-center justify-between mb-2">
                 <span className="text-[9px] font-black uppercase tracking-widest text-slate-500">Synaptic Relay</span>
                 <div className={`w-2 h-2 rounded-full ${isConnected ? 'bg-[#8da290] shadow-[0_0_10px_#8da290]' : 'bg-rose-500 animate-pulse'}`} />
              </div>
              <p className={`text-xs font-serif italic tracking-wide ${isConnected ? 'text-[#8da290]' : 'text-rose-400'}`}>
                 {isConnected ? 'Relay Established' : 'Link Connection Pending'}
              </p>
           </div>

           {/* PRESENTATION MODE TOGGLE */}
           <div className="p-6 rounded-[2rem] border border-[#c5a059]/10 bg-black/40 mb-8">
              <div className="flex items-center justify-between mb-4">
                 <div className="flex items-center gap-3">
                    <Cpu className="w-3.5 h-3.5 text-[#c5a059]" />
                    <span className="text-[9px] font-black uppercase tracking-widest text-slate-400">Presentation Mode</span>
                 </div>
                 <button 
                    onClick={() => handleTogglePresentation(!data.dashboard?.presentation_mode)}
                    className={`w-10 h-5 rounded-full transition-all relative ${data.dashboard?.presentation_mode ? 'bg-[#c5a059]' : 'bg-slate-800'}`}
                 >
                    <div className={`absolute top-1 w-3 h-3 rounded-full bg-black transition-all ${data.dashboard?.presentation_mode ? 'left-6' : 'left-1'}`} />
                 </button>
              </div>
              <p className="text-[11px] text-slate-500 font-serif italic leading-relaxed">
                 Triggers reminder checks every 3 and 7 minutes during presentation mode.
              </p>
           </div>

           {/* MAIL SECTION */}
           <div className="p-6 rounded-[2rem] border border-[#8da290]/20 bg-black/40 mb-8">
              <div className="flex items-center gap-3 mb-4">
                 <Send className="w-3.5 h-3.5 text-[#8da290]" />
                 <span className="text-[9px] font-black uppercase tracking-widest text-slate-400">Daily Report Mail</span>
              </div>
              <div className="space-y-3">
                 <input
                    type="email"
                    value={reportEmail}
                    onChange={(e) => setReportEmail(e.target.value)}
                    placeholder="student@example.com"
                    className="w-full bg-[#0f0f11] border border-white/5 rounded-2xl px-4 py-3 text-[11px] text-[#f4f1ea] placeholder-slate-600 focus:border-[#8da290]/40 outline-none transition-all"
                 />
                 <button
                    type="button"
                    onClick={handleSaveReportEmail}
                    disabled={savingEmail}
                    className={`w-full rounded-2xl px-4 py-3 text-[10px] font-black tracking-[0.2em] transition-all ${savingEmail ? 'bg-slate-900 text-slate-600 cursor-not-allowed' : 'bg-[#8da290]/20 text-[#8da290] border border-[#8da290]/30 hover:bg-[#8da290]/30'}`}
                 >
                    {savingEmail ? 'SAVING...' : 'SAVE MAIL'}
                 </button>
              </div>
           </div>

           {/* NAVIGATION */}
           <nav className="space-y-4 mb-12">
              <button 
                 onClick={() => setActiveTab('dashboard')}
                 className={`w-full flex items-center gap-6 px-10 py-6 rounded-[2rem] transition-all duration-500 font-black uppercase tracking-widest text-xs border ${activeTab === 'dashboard' ? 'bg-[#c5a059] text-black border-[#c5a059] shadow-gold' : 'text-slate-500 hover:text-white border-white/5'}`}
              >
                 <Activity size={18} />
                 Dashboard
              </button>
              <button 
                  onClick={() => setActiveTab('games')}
                  className={`w-full flex items-center gap-6 px-10 py-6 rounded-[2rem] transition-all duration-500 font-black uppercase tracking-widest text-xs border ${activeTab === 'games' ? 'bg-[#c5a059] text-black border-[#c5a059] shadow-gold' : 'text-slate-500 hover:text-white border-white/5'}`}
               >
                  <Zap size={18} />
                  Game Mode
               </button>
           </nav>
        </div>

        <div className="px-8 flex items-center gap-2 mb-4 group cursor-default">
           <Activity className="w-3 h-3 text-[#c5a059] group-hover:scale-110 transition-transform" />
           <h3 className="text-[10px] font-black uppercase tracking-widest text-slate-500">Synaptic Activity</h3>
        </div>
        
        <div className="flex-1 overflow-y-auto px-8 py-2 space-y-8 custom-scrollbar mb-8">
           {activeEvents.map((evt, i) => (
             <div key={i} className="relative pl-6">
                <div className="absolute left-0 top-1.5 w-1 h-1 bg-[#c5a059]/50 rounded-full shadow-[0_0_5px_#c5a059]" />
                <div className="absolute left-[1.5px] top-4 bottom-[-2.5rem] w-[1px] bg-white/5" />
                <p className="text-xs font-medium text-slate-400 leading-relaxed">{evt.text}</p>
                <time className="text-[9px] font-mono text-slate-600 uppercase mt-1 block">T-{Math.floor((Date.now()/1000 - evt.timestamp)/60)}M AGO</time>
             </div>
           ))}
        </div>

        <div className="p-8 bg-[#0a0c10] border-t border-white/5">
           <div className="flex items-center gap-3 text-slate-600 mb-4 opacity-50">
              <User className="w-4 h-4" />
              <span className="text-[10px] font-black tracking-widest uppercase">Operator: Harsha</span>
           </div>
           <p className="text-[10px] font-mono text-slate-700">NODE_UUID: MF-8000-WIN</p>
        </div>
      </aside>

      {/* MAIN VIEWPORT - HUMANLY & CLASSIC */}
      <main className="flex-1 h-full overflow-y-auto bg-[#0a0a0b] relative custom-scrollbar scroll-smooth">
        {/* ATMOSPHERIC LAYER */}
        <div className="absolute top-0 right-0 w-[1000px] h-[1000px] bg-[#c5a059]/[0.02] rounded-full blur-[180px] pointer-events-none" />
        <div className="absolute bottom-0 left-0 w-[800px] h-[800px] bg-[#8da290]/[0.02] rounded-full blur-[140px] pointer-events-none" />

        <div className="p-10 lg:p-20 relative z-10">
           
           {/* HEADER SECTION */}
           <header className="flex flex-col md:flex-row md:items-end justify-between border-b border-white/5 pb-10 mb-12 gap-10">
              <div className="space-y-4">
                 <div className="flex items-center gap-3 text-[#c5a059]">
                    <Sparkles className="w-5 h-5 animate-pulse" />
                    <span className="text-[11px] font-black uppercase tracking-[0.3em]">Cognitive Pulse</span>
                 </div>
                 <h2 className="text-7xl font-black text-[#f4f1ea] font-serif tracking-tighter leading-none">NeuroRevise</h2>
              </div>
              
              <div className="flex items-center gap-10">
                 <div className="flex flex-col items-end">
                    <span className="text-[10px] font-black text-slate-600 uppercase tracking-[0.2em] mb-2">Memory Stability</span>
                    <span className="text-6xl font-black text-[#f4f1ea] tracking-tighter">84.2 <span className="text-xl text-[#8da290] ml-1">%</span></span>
                 </div>
                 <div className="w-48 h-20 bg-[#0f0f11] rounded-3xl border border-white/5 overflow-hidden shadow-inner">
                    <ResponsiveContainer width="100%" height="100%">
                       <AreaChart data={MOCK_TREND}>
                          <Area type="monotone" dataKey="load" stroke="#c5a059" strokeWidth={2} fill="#c5a059" fillOpacity={0.05} animationDuration={2500} />
                       </AreaChart>
                    </ResponsiveContainer>
                 </div>
              </div>
           </header>

           {activeTab === 'dashboard' ? (
             <div className="animate-in fade-in slide-in-from-bottom-6 duration-1000">
               {/* STATUS CARDS */}
               <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-8 mb-20">
              <StatusCard 
                 label="Active Nodes" 
                 value={data.dashboard?.total_cards || 0} 
                 icon={<Layers className="text-[#c5a059]" />} 
                 sub="Total clusters in sync"
              />
              <StatusCard 
                 label="Critical Decay" 
                 value={data.dashboard?.critical_cards || 0} 
                 icon={<AlertTriangle className="text-rose-400" />} 
                 sub="Nodes requiring recall"
                 urgency="critical"
              />
              <StatusCard 
                 label="System Flow" 
                 value="Optimal" 
                 icon={<Zap className="text-[#8da290]" />} 
                 sub="Synaptic throughput"
              />
              <StatusCard 
                 label="Neural Link" 
                 value="Verified" 
                 icon={<ShieldCheck className="text-[#c5a059]" />} 
                 sub="Connection integrity"
              />
           </div>

            {/* QUICK ACTIONS */}
            <section className="mb-20">
              <h3 className="text-2xl font-black text-[#f4f1ea] mb-8 tracking-tight">Quick Actions</h3>
              <div className="grid grid-cols-2 md:grid-cols-3 gap-6">
                {[
                  { key: 'panic', label: 'Panic Mode', icon: AlertTriangle, cls: 'bg-rose-500/15 text-rose-300 border-rose-400/20', action: handlePanicMode },
                  { key: 'game', label: 'Game Mode', icon: Zap, cls: 'bg-sky-500/15 text-sky-300 border-sky-400/20', action: () => setActiveTab('games') },
                  { key: 'upload', label: 'Upload', icon: Upload, cls: 'bg-cyan-500/15 text-cyan-300 border-cyan-400/20', action: () => scrollToSection('ingest') },
                  { key: 'learn', label: 'Learn', icon: Brain, cls: 'bg-emerald-500/15 text-emerald-300 border-emerald-400/20', action: () => scrollToSection('learning-cards') },
                  { key: 'chat', label: 'AI Chat', icon: Terminal, cls: 'bg-fuchsia-500/15 text-fuchsia-300 border-fuchsia-400/20', action: handleAIChatQuick },
                  { key: 'progress', label: 'Progress', icon: Activity, cls: 'bg-cyan-500/20 text-cyan-300 border-cyan-400/25', action: () => scrollToSection('progress') },
                ].map((item) => (
                  <button
                    key={item.key}
                    onClick={item.action}
                    className={`group rounded-3xl p-6 border ${item.cls} bg-[#0f0f11] hover:scale-[1.02] transition-all text-left`}
                  >
                    <div className="w-12 h-12 rounded-2xl bg-black/30 border border-white/10 flex items-center justify-center mb-4">
                      <item.icon className="w-6 h-6" />
                    </div>
                    <p className="text-lg font-black">{item.label}</p>
                  </button>
                ))}
              </div>
            </section>
           {/* PRIMARY ANALYTICS GRID */}
            <div id="progress" className="grid grid-cols-1 xl:grid-cols-3 gap-10 mb-20 animate-in fade-in slide-in-from-bottom-5 duration-700">
              
              {/* LARGE TREND CHART */}
              <div className="col-span-1 xl:col-span-2 bg-[#0a0a0b] rounded-[3.5rem] p-12 border border-white/5 relative group hover:shadow-[0_40px_100px_rgba(0,0,0,0.8)] transition-all overflow-hidden">
                 <div className="absolute top-0 right-0 w-80 h-80 bg-[#c5a059]/5 rounded-full blur-[100px] -mr-40 -mt-40" />
                 <div className="relative z-10">
                    <div className="flex items-center justify-between mb-12">
                       <h3 className="text-2xl font-black text-[#f4f1ea] font-serif flex items-center gap-5">
                          <Activity className="w-7 h-7 text-[#c5a059]" /> Synaptic Stability Trend
                       </h3>
                       <div className="flex gap-6">
                          <div className="flex items-center gap-2">
                             <div className="w-2.5 h-2.5 rounded-full bg-[#c5a059]" />
                             <span className="text-[10px] uppercase font-black tracking-widest text-slate-500">Load</span>
                          </div>
                          <div className="flex items-center gap-2">
                             <div className="w-2.5 h-2.5 rounded-full bg-[#8da290]" />
                             <span className="text-[10px] uppercase font-black tracking-widest text-slate-500">Score</span>
                          </div>
                       </div>
                    </div>
                    <div className="h-72 w-full">
                       <ResponsiveContainer width="100%" height="100%">
                          <LineChart data={MOCK_TREND}>
                             <CartesianGrid strokeDasharray="3 3" stroke="rgba(255,255,255,0.03)" vertical={false} />
                             <XAxis dataKey="day" axisLine={false} tickLine={false} tick={{fill: '#475569', fontSize: 10, fontWeight: 700}} dy={15} />
                             <YAxis hide />
                             <Tooltip 
                                contentStyle={{ backgroundColor: '#0f0f11', border: '1px solid rgba(255,255,255,0.05)', borderRadius: '20px', padding: '15px' }}
                                itemStyle={{ fontSize: '11px', textTransform: 'uppercase', fontWeight: 900, color: '#f4f1ea' }}
                             />
                             <Line type="monotone" dataKey="load" stroke="#c5a059" strokeWidth={5} dot={{r: 6, fill: '#c5a059', strokeWidth: 3, stroke: '#0a0a0b'}} animationDuration={2500} />
                             <Line type="monotone" dataKey="retention" stroke="#8da290" strokeWidth={5} dot={{r: 6, fill: '#8da290', strokeWidth: 3, stroke: '#0a0a0b'}} animationDuration={3000} />
                          </LineChart>
                       </ResponsiveContainer>
                    </div>
                 </div>
              </div>

              {/* RETENTION METRICS PANEL */}
              <div className="bg-gradient-to-br from-[#1a1a1c] to-[#0f0f11] rounded-[3.5rem] p-12 border border-white/5 shadow-2xl flex flex-col justify-between group overflow-hidden relative">
                 <div className="absolute top-[-50px] left-[-50px] w-80 h-80 bg-[#c5a059]/5 rounded-full blur-[80px]" />
                 <div className="relative z-10 space-y-12">
                    <div>
                       <h3 className="text-[#c5a059]/60 font-black uppercase tracking-[0.3em] text-[10px] mb-3">System Integrity</h3>
                       <p className="text-8xl font-black text-[#f4f1ea] font-serif tracking-tighter leading-none">{data.dashboard?.total_cards || 0}</p>
                       <p className="text-[#8da290]/50 text-sm font-medium mt-4 tracking-wide font-serif italic">Verified synaptic clusters active</p>
                    </div>
                    
                    <div className="space-y-6">
                       <div className="p-6 bg-white/[0.02] rounded-3xl border border-white/5 flex justify-between items-center group-hover:bg-white/[0.04] transition-all">
                          <div className="flex items-center gap-4">
                             <div className="w-10 h-10 rounded-2xl bg-[#8da290]/10 flex items-center justify-center border border-[#8da290]/20">
                                <ShieldCheck className="w-5 h-5 text-[#8da290]" />
                             </div>
                             <span className="text-xs font-black text-[#f4f1ea] uppercase tracking-widest">Stable</span>
                          </div>
                          <span className="text-2xl font-black text-[#8da290] tracking-tighter">82</span>
                       </div>
                       
                       <div className="p-6 bg-white/[0.02] rounded-3xl border border-white/5 flex justify-between items-center group-hover:bg-white/[0.04] transition-all">
                          <div className="flex items-center gap-4">
                             <div className="w-10 h-10 rounded-2xl bg-rose-500/10 flex items-center justify-center border border-rose-500/20">
                                <Zap className="w-5 h-5 text-rose-400" />
                             </div>
                             <span className="text-xs font-black text-[#f4f1ea] uppercase tracking-widest">Decaying</span>
                          </div>
                          <span className="text-2xl font-black text-rose-400 tracking-tighter">04</span>
                       </div>
                    </div>
                 </div>
              </div>
           </div>
           {/* NEURAL INGEST - THE ARCHIVE LINK */}
           <section className="mb-24 scroll-mt-20" id="ingest">
              <div className="bg-[#0f0f11] rounded-[3.5rem] p-1.5 border border-white/5 shadow-[0_50px_100px_rgba(0,0,0,0.6)] relative overflow-hidden group">
                 <div className="absolute top-0 right-0 w-96 h-96 bg-[#c5a059]/5 rounded-full blur-[100px] -mr-48 -mt-48" />
                 
                 <div className="bg-[#0a0a0b] rounded-[3.3rem] p-12 lg:p-16 relative z-10">
                    <div className="flex flex-col md:flex-row md:items-center justify-between gap-8 mb-16">
                       <div className="flex items-center gap-8">
                          <div className="w-20 h-20 bg-[#c5a059] rounded-[2.5rem] flex items-center justify-center shadow-[0_20px_40px_rgba(197,160,89,0.2)]">
                             <Database className="w-10 h-10 text-black" />
                          </div>
                          <div>
                             <h3 className="text-4xl font-black text-[#f4f1ea] font-serif tracking-tight">Synaptic Ingestion</h3>
                             <p className="text-[#8da290] font-serif italic text-lg mt-1">Transcribe your world into the architecture of memory.</p>
                          </div>
                       </div>
                    </div>

                    <form onSubmit={handleIngest} className="grid grid-cols-1 lg:grid-cols-2 gap-16">
                       <div className="space-y-12">
                          <div className="space-y-4">
                             <label className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] ml-2">Context Cluster</label>
                             <input 
                                type="text" 
                                value={topicName}
                                onChange={(e) => setTopicName(e.target.value)}
                                placeholder="Identify your knowledge area..."
                                className="w-full bg-[#0f0f11] border border-white/5 rounded-[2.5rem] px-10 py-6 text-xl text-[#f4f1ea] placeholder-slate-700 focus:border-[#c5a059]/30 outline-none transition-all shadow-inner font-serif"
                             />
                          </div>
                          <div className="space-y-4">
                             <label className="text-[10px] font-black text-slate-500 uppercase tracking-[0.3em] ml-2">Target Completion</label>
                             <input
                                type="datetime-local"
                                value={targetCompletionAt}
                                onChange={(e) => setTargetCompletionAt(e.target.value)}
                                className="w-full bg-[#0f0f11] border border-white/5 rounded-[2.5rem] px-10 py-5 text-sm text-[#f4f1ea] focus:border-[#8da290]/40 outline-none transition-all shadow-inner"
                             />
                          </div>


                          <div className="flex flex-wrap gap-5 p-3 bg-[#0f0f11] rounded-[3rem] border border-white/5 w-fit shadow-inner">
                             {[
                                { id: 'text', icon: Type, label: 'Journal' },
                                { id: 'file', icon: Upload, label: 'Manuscript' },
                                { id: 'youtube', icon: Globe, label: 'Visual Stream' }
                             ].map((type) => (
                                <button 
                                   key={type.id}
                                   type="button"
                                   onClick={() => setIngestType(type.id)}
                                   className={`flex items-center gap-5 px-10 py-5 rounded-[2.5rem] text-[10px] font-black tracking-[0.2em] transition-all duration-500 ${ingestType === type.id ? 'bg-[#c5a059] text-black shadow-gold scale-105' : 'text-slate-500 hover:text-slate-300'}`}
                                >
                                   <type.icon className="w-4 h-4" />
                                   {type.label.toUpperCase()}
                                </button>
                             ))}
                          </div>
                       </div>

                       <div className="space-y-8">
                           <div className="h-[300px] bg-[#0f0f11] border border-white/5 rounded-[3rem] p-10 relative overflow-hidden group focus-within:border-[#c5a059]/20 transition-all shadow-inner">
                              {ingestType === 'text' && (
                                 <textarea 
                                    value={textContent}
                                    onChange={(e) => setTextContent(e.target.value)}
                                    placeholder="Pour your insights here..."
                                    className="w-full h-full bg-transparent border-none outline-none text-[#f4f1ea] resize-none placeholder-slate-700 font-serif text-lg leading-relaxed custom-scrollbar italic"
                                 />
                              )}
                              {ingestType === 'youtube' && (
                                 <div className="h-full flex flex-col justify-center gap-8">
                                    <div className="relative">
                                       <Globe className="absolute left-6 top-1/2 -translate-y-1/2 text-slate-700 w-5 h-5" />
                                       <input 
                                          type="text" 
                                          value={youtubeUrl}
                                          onChange={(e) => setYoutubeUrl(e.target.value)}
                                          placeholder="https://youtube.com/watch?v=..."
                                          className="w-full bg-[#0a0a0b] border border-white/5 rounded-3xl pl-16 pr-8 py-5 text-[#f4f1ea] font-mono text-sm focus:border-red-500/20 outline-none transition-all"
                                       />
                                    </div>
                                    <p className="text-xs text-slate-600 leading-relaxed font-serif italic px-2">The system will distill visual stream data into structured neural nodes.</p>
                                 </div>
                              )}
                              {ingestType === 'file' && (
                                 <div 
                                    onClick={() => fileInputRef.current?.click()}
                                    className="h-full flex flex-col items-center justify-center border-2 border-dashed border-white/5 rounded-[2.5rem] hover:border-[#c5a059]/30 hover:bg-white/[0.01] cursor-pointer transition-all gap-6"
                                 >
                                    <input type="file" hidden ref={fileInputRef} accept=".pdf,.txt" />
                                    <div className="p-8 bg-[#c5a059]/10 rounded-full border border-[#c5a059]/20 group-hover:scale-110 transition-transform shadow-2xl">
                                       <Upload className="w-10 h-10 text-[#c5a059]" />
                                    </div>
                                    <div className="text-center">
                                       <p className="text-[#f4f1ea] font-black text-sm tracking-widest uppercase">Select Source Document</p>
                                       <p className="text-[10px] text-slate-600 uppercase tracking-[0.3em] mt-3 font-mono">Payload Limit: 10MB</p>
                                    </div>
                                 </div>
                              )}
                           </div>
                           
                           <button 
                             disabled={ingestLoading || !topicName}
                             className={`w-full flex items-center justify-center gap-6 px-12 py-7 rounded-[3rem] font-black text-xl tracking-[0.2em] transition-all ${ingestLoading ? 'bg-slate-900 text-slate-600 cursor-not-allowed' : 'bg-[#c5a059] text-black hover:bg-[#d8b577] hover:shadow-[0_25px_50px_rgba(197,160,89,0.3)] hover:-translate-y-1 active:scale-95'}`}
                           >
                             {ingestLoading ? (
                                <RefreshCw className="w-7 h-7 animate-spin" />
                             ) : (
                                <>
                                   INITIATE LINK
                                   <Send className="w-7 h-7" />
                                </>
                             )}
                           </button>
                       </div>
                    </form>
                 </div>
              </div>
           </section>

           {/* KNOWLEDGE CLUSTERS */}
           <div id="learning-cards" className="grid grid-cols-1 md:grid-cols-2 2xl:grid-cols-3 gap-16">
              {activeCards.map((fc) => {
                 const plan = getPlanForTopic(fc.id);
                 const currentStage = plan?.current_stage || 0;
                 const isPlanCompleted = plan?.status === 'completed';

                 return (
                 <div key={fc.id} className="relative group">
                    <div className="absolute inset-0 bg-[#c5a059]/[0.015] rounded-[4.5rem] transition-all duration-1000 -m-8 z-0" />
                    
                    <div className="relative bg-[#0f0f11] rounded-[4.5rem] p-12 lg:p-14 border border-white/5 shadow-3xl hover:border-[#c5a059]/10 transition-all duration-700 flex flex-col min-h-[720px] group-hover:-translate-y-2 z-10 overflow-hidden">
                       {/* CARD BACKGROUND ART */}
                       <div className="absolute top-0 right-0 w-80 h-80 bg-[#c5a059]/[0.04] rounded-full blur-[120px] -mr-40 -mt-40 opacity-0 group-hover:opacity-100 transition-opacity duration-1000" />
                       
                       <div className="flex justify-between items-start mb-12 relative z-10">
                          <div className="flex-1 min-w-0">
                             <h3 className="text-4xl font-black text-[#f4f1ea] font-serif hover:text-[#c5a059] transition-colors duration-500 leading-tight pr-10">{fc.topic_name}</h3>
                             <div className="flex items-center gap-5 mt-6">
                                 <Clock className="w-4 h-4 text-[#8da290]" />
                                 <span className="text-[11px] font-black text-[#8da290] uppercase tracking-[0.25em] font-serif italic opacity-70">
                                    Next Recall: {fc.next_reminder_minutes}m
                                 </span>
                             </div>
                          </div>
                          <div className={`px-6 py-3 rounded-2xl text-[10px] font-black uppercase tracking-[0.4em] border shadow-glow backdrop-blur-3xl transition-all duration-500 ${
                             fc.urgency_level === 'critical' ? 'bg-rose-500/10 text-rose-500 border-rose-500/20 shadow-rose-500/5' :
                             fc.urgency_level === 'danger' ? 'bg-orange-500/10 text-orange-400 border-orange-500/20' :
                             'bg-[#8da290]/10 text-[#8da290] border-[#8da290]/20'
                          }`}>
                             {fc.urgency_level}
                          </div>
                       </div>
                       
                       <div className="relative mb-14 flex-1">
                          <p className="text-slate-400 text-2xl leading-[1.8] font-serif italic opacity-85 group-hover:opacity-100 transition-opacity duration-700 line-clamp-6 pr-6">
                             "{fc.question}"
                          </p>
                          
                          {/* QUICK PLAY & ZAP BUTTONS */}
                          <div className="absolute bottom-[-10px] right-0 translate-y-full opacity-0 group-hover:opacity-100 group-hover:translate-y-0 transition-all duration-700 flex flex-col gap-4">
                             <button 
                                onClick={() => handleManualTrigger(fc.id)}
                                className="w-20 h-20 rounded-[2.5rem] bg-rose-500/10 border border-rose-500/20 flex items-center justify-center group/zap hover:bg-rose-500 hover:scale-110 active:scale-95 transition-all duration-500 shadow-2xl"
                                title="Trigger Manual Zap (Instant Phone Notification)"
                             >
                                <Zap className="w-7 h-7 text-rose-500 group-hover/zap:text-white fill-current animate-pulse transition-colors" />
                             </button>

                             <button 
                                onClick={() => playAudioSummary(fc.id, fc.summary || fc.question)}
                                className="w-20 h-20 rounded-[2.5rem] bg-[#c5a059]/10 border border-[#c5a059]/20 flex items-center justify-center group/play hover:bg-[#c5a059] hover:scale-110 active:scale-95 transition-all duration-500 shadow-2xl"
                                title="Synthesize Brief"
                             >
                                {speakingId === fc.id ? (
                                   <Square className="w-7 h-7 text-[#c5a059] group-hover/play:text-[#0f0f11] fill-current transition-colors" />
                                ) : (
                                   <Play className="w-7 h-7 text-[#c5a059] group-hover/play:text-[#0f0f11] fill-current transition-colors" />
                                )}
                             </button>

                             <button 
                                onClick={() => handleDeleteLesson(fc.topic_name)}
                                className="w-20 h-20 rounded-[2.5rem] bg-slate-500/10 border border-slate-500/20 flex items-center justify-center group/del hover:bg-rose-500 hover:scale-110 active:scale-95 transition-all duration-500 shadow-2xl"
                                title="Delete this lesson"
                             >
                                <Trash2 className="w-7 h-7 text-slate-400 group-hover/del:text-white transition-colors" />
                             </button>
                          </div>
                       </div>

                       {/* CHRONOS PLAN: REAL DATA TRACKER */}
                       <div className="mb-14 bg-white/[0.015] rounded-[3rem] p-9 border border-white/5 backdrop-blur-3xl overflow-hidden relative group/plan">
                          <div className="flex justify-between items-center mb-6">
                             <div className="flex items-center gap-4">
                                <Activity className="w-4 h-4 text-[#c5a059] animate-pulse" />
                                <span className="text-[11px] font-black text-slate-500 uppercase tracking-[0.2em]">Chronos Deployment</span>
                             </div>
                             <span className="text-[10px] font-bold text-[#c5a059] uppercase tracking-[0.2em] opacity-60">
                                {isPlanCompleted ? 'Optimized' : `Level ${currentStage + 1}/3`}
                             </span>
                          </div>
                          
                          <div className="flex gap-5">
                             {[0, 1, 2].map((stage) => (
                                <div key={stage} className="flex-1 h-2 relative">
                                   <div className={`absolute inset-0 rounded-full transition-all duration-1000 ${
                                      stage < currentStage || isPlanCompleted ? 'bg-[#8da290] shadow-[0_0_20px_#8da290]' :
                                      stage === currentStage ? 'bg-white/10 overflow-hidden' : 'bg-white/5'
                                   }`}>
                                      {stage === currentStage && !isPlanCompleted && (
                                         <div className="h-full bg-[#c5a059] w-1/2 animate-pulse rounded-full shadow-[0_0_15px_#c5a059]" />
                                      )}
                                   </div>
                                </div>
                             ))}
                          </div>
                          
                          <div className="flex justify-between mt-6 px-1 opacity-50 font-serif italic text-xs">
                             <span className={currentStage >= 0 || isPlanCompleted ? 'text-[#8da290]' : 'text-slate-600'}>Audio Brief</span>
                             <span className={currentStage >= 1 || isPlanCompleted ? 'text-[#8da290]' : 'text-slate-600'}>Deep Recap</span>
                             <span className={currentStage >= 2 || isPlanCompleted ? 'text-[#8da290]' : 'text-slate-600'}>Proficiency Quiz</span>
                          </div>
                       </div>
                       
                       <div className="pt-10 border-t border-white/5 flex flex-col gap-10 relative z-10">
                           <div className="flex justify-between items-end">
                              <div className="flex flex-col">
                                 <span className="text-[12px] font-black text-slate-600 uppercase tracking-[0.3em] mb-4">Neural Retention</span>
                                 <div className="flex items-baseline gap-2">
                                    <span className={`text-8xl font-black font-serif tracking-tighter transition-colors duration-700 ${fc.retention_score < 50 ? 'text-rose-500' : 'text-[#8da290]'}`}>
                                       {fc.retention_score}
                                    </span>
                                    <span className="text-2xl font-bold opacity-20 text-slate-400 select-none">%</span>
                                 </div>
                              </div>
                              <div className={`w-28 h-28 rounded-[2.8rem] bg-[#0f0f11] border-2 flex items-center justify-center transition-all duration-1000 shadow-glass ${
                                 fc.retention_score < 50 ? 'border-rose-500/20 shadow-rose-500/5' : 'border-[#8da290]/20 shadow-[#8da290]/5'
                              }`}>
                                 <ShieldCheck className={`w-12 h-12 transition-all duration-700 ${fc.retention_score < 50 ? 'text-rose-500 opacity-20' : 'text-[#8da290] opacity-40 group-hover:opacity-80'}`} />
                              </div>
                           </div>
                       </div>
                    </div>
                 </div>
                 );
               })}
           </div>
           
           {/* EMPTY STATE */}
           {activeCards.length === 0 && (
               <div className="mt-20 py-48 border-2 border-dashed border-white/5 rounded-[4.5rem] flex flex-col items-center justify-center gap-10 bg-white/[0.01] backdrop-blur-sm">
                   <div className="w-28 h-28 bg-[#0f0f11] rounded-[2.5rem] border border-white/5 flex items-center justify-center shadow-2xl relative">
                      <div className="absolute inset-0 bg-[#c5a059]/5 rounded-full blur-[40px] animate-pulse" />
                      <Brain className="w-12 h-12 text-slate-800 relative z-10" />
                   </div>
                   <div className="text-center space-y-3">
                      <h3 className="text-4xl font-black text-[#f4f1ea] font-serif">Awaiting Synaptic Data</h3>
                      <p className="text-[#8da290] font-serif italic text-lg opacity-50">Upload a resource to begin the architecture of your memory.</p>
                   </div>
                   <button 
                      onClick={() => setSimulationMode(true)} 
                      className="px-12 py-5 bg-[#c5a059] text-black font-black uppercase text-xs tracking-[0.3em] rounded-full hover:bg-white transition-all scale-110"
                   >
                      Ignite Simulation
                   </button>
               </div>
           )}
             </div>
           ) : (
             <GameHub />
           )}
        </div>
      </main>
      <GameOverlay />
    </div>
  );
}

export default App;





















