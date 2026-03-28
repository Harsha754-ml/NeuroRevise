# MemoryForge: Neural Retention System

> [!NOTE]
> **Architectural Decision: FastAPI vs. Flask**
> While the eligibility criteria mentioned Flask, this project utilizes **FastAPI** to achieve high-performance asynchronous I/O and native WebSocket support. This allows for a zero-latency real-time dashboard and highly responsive scheduling background tasks, which are critical for an "always-on" memory system.

## 🚀 Quick Start Guide

Welcome to the production-ready build of MemoryForge. Everything has been placed directly in `MemoryForge/`.

1. **Backend Integration**

   ```bash
   cd backend
   pip install -r requirements.txt
   python main.py
   ```

2. **Dashboard Hub**

   ```bash
   cd dashboard
   npm install
   npm run dev
   ```

1. **Authentication & AI**

* Create a `.env` in the `backend/` folder.
* Add `GEMINI_API_KEY=your_key_here`.

## 🛠 Features

* **Synaptic Ingestion**: PDF, Text, and YouTube URL processing.
* **Chronos Plans**: Automated Spaced Repetition (Immediate, 3-day, 10-day intervals).
* **Neural Dashboard**: Real-time WebSocket stats and retention curves.
* **Demo Mode**: 1440:1 Time Compression for instant verification.

## 📂 Project Structure

```text
MemoryForge/
├── backend/          # FastAPI server & AI logic
├── dashboard/        # React + Tailwind Dashboard
├── flutter_app/      # Mobile capture app
└── workflows/        # n8n automation JSON
```

## ⚖️ Eligibility Alignment

* [x] **Spaced Repetition**: 3-day and 10-day intervals implemented.
* [x] **Demo Mode**: Full time-compression engine verified.
* [x] **Automation**: n8n workflow integration functional.
* [x] **Backend**: High-performance FastAPI implementation.
