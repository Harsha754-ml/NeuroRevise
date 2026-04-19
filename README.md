<div align="center">
  <img src="https://img.shields.io/badge/Status-Active-success.svg" alt="Status">
  <img src="https://img.shields.io/badge/Backend-FastAPI-009688.svg?logo=fastapi" alt="FastAPI">
  <img src="https://img.shields.io/badge/Frontend-React-61DAFB.svg?logo=react" alt="React">
  <img src="https://img.shields.io/badge/Mobile-Flutter-02569B.svg?logo=flutter" alt="Flutter">
  <br>
  <h1>🧠 NeuroRevise</h1>
  <h3>Adaptive Memory Retention & Reminder System.</h3>
</div>

<br/>

**MemoryForge** is an advanced autonomous learning companion designed to combat the "forgetting curve." By intelligently ingesting study materials (PDFs, text, YouTube videos) and generating spaced-repetition schedules, MemoryForge ensures you retain information when it matters most.

---

## 🌟 Key Features

- **⚡ Synaptic Ingestion:** Instantly process PDFs, plain text, and YouTube video URLs into actionable knowledge.
- **📅 Chronos Plans:** AI-powered spaced repetition schedules (Immediate, 3-day, 10-day intervals).
- **📊 Neural Dashboard:** A zero-latency React real-time dashboard powered by WebSockets to monitor your retention curves.
- **🚨 Panic Mode:** Intense 10-minute rapid-fire revision sessions for urgent review.
- **📱 Mobile Capture:** Flutter-based mobile app for capturing knowledge on the go and receiving push reminders.
- **⏱️ Demo Mode:** Experience a 1440:1 Time Compression engine to verify system functionality instantly.
- **⚙️ N8N Automation:** Seamless workflow automation for external reminders and multi-channel escalation.

---

## 📂 Project Structure

The project is modularized into dedicated microservices:

```text
MemoryForge/
├── 🐍 backend/         # High-performance FastAPI server & AI processing logic
├── ⚛️ dashboard/       # React + TailwindCSS real-time web dashboard
├── 📱 flutter_app/     # Flutter mobile application
└── 🤖 root/            # Includes n8n automation JSON and database records
```

---

## 🚀 Quick Start Guide

### 1️⃣ Setup the Backend (FastAPI)

The backend handles AI processing, database management, and WebSockets.

```bash
cd backend

# Create and activate a virtual environment
python -m venv venv
# On Windows:
venv\Scripts\activate
# On Mac/Linux:
# source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

**Environment Variables:**
Create a `.env` file in the `backend/` directory:
```env
GEMINI_API_KEY=your_gemini_api_key_here
```

**Run the Server:**
```bash
python main.py
```
*The server will start at `http://localhost:8000`.*

---

### 2️⃣ Setup the Web Dashboard (React)

The interactive analytics dashboard for monitoring your memory tasks.

```bash
cd dashboard

# Install dependencies
npm install

# Start development server
npm run dev
```
*The dashboard will be available at `http://localhost:5173` (or the port specified by Vite).*

---

### 3️⃣ Setup the Mobile App (Flutter)

The mobile companion for on-the-go capture.

```bash
cd flutter_app

# Fetch packages
flutter pub get

# Run on emulator/device
flutter run
```

---

## 🛠 Architectural Decisions

> **FastAPI over Flask**  
> While some legacy requirements favor Flask, MemoryForge leverages **FastAPI** to achieve high-performance asynchronous I/O and native WebSocket support. This fundamental design choice empowers our zero-latency real-time dashboard and highly robust background task scheduling without the overhead of heavy message brokers.

---

## ⚖️ Hackathon Feature Verification

- [x] **Spaced Repetition:** Scientifically backed intervals implemented.
- [x] **Demo Mode:** Full time-compression engine verified.
- [x] **Automation:** Configured and functional n8n workflow integration.
- [x] **Backend Infrastructure:** High-performance asynchronous APIs.

---

<div align="center">
  <p>Built with 💡 & ☕</p>
</div>
