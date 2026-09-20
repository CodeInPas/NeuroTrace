# 🧠 NEURO-TRACE 2088
**Holographic Medical Hacking Simulator**

Step into the role of a digital neuro-surgeon in **NEURO-TRACE 2088**. This cyberpunk-themed medical hacking simulator challenges you to diagnose, isolate, and purge polymorphic viruses from a patient's neural pathways before their vitality flatlines. 

Built entirely from scratch using native **Lazarus Free Pascal (FPC)**, the game ditches traditional point-and-click mechanics in favor of a tactical Command Line Interface (CLI) working in tandem with a custom-rendered holographic map.

![Gameplay Screenshot](assets/gameplay_action.png) <!-- Ganti dengan path screenshot Anda -->

## ✨ Technical Features
This project serves as a showcase of what native FPC desktop applications can achieve without relying on heavy game engines:
* **Custom UI & BGRABitmap Rendering:** Features a borderless multi-window architecture with custom components (`TCyberButton`), CRT scanlines, parallax cellular dust, and 3D glowing nodes rendered entirely on a `TPaintBox`.
* **Real-Time Audio DSP:** Integrates the **BASS Audio Library** to process live FFT spectrum data, driving the dynamic waveform visualizer at the bottom of the screen.
* **Persistent Economy (SQLite):** Uses `TSQLite3Connection` to manage a local database that saves player profiles, operational logs, and Black Market inventory.
* **Procedural Topologies:** Brain node generation utilizes a Constant Density Vogel Spiral algorithm, ensuring optimal neural network density scaling across different difficulty levels.

## 🎮 The Core Loop (How to Play)
Your objective is to neutralize all viral threats hiding inside the patient's brain without destroying healthy tissue.

1. **Initiate Scan:** Type `DIAG` in the Terminal to load a patient. The system will give you a rough frequency of the camouflaged virus (e.g., `~800 HZ`).
2. **Break Camouflage:** Type `ISOLATE [FREQ]` (e.g., `ISOLATE 800`). If your guess is within a 50Hz margin, the virus's camouflage is stripped for 15 seconds, turning the infected nodes **red**.
3. **Execute Threat:** Quickly locate the yellow ID numbers floating above the red nodes on the hologram. Type `PURGE [ID]` (e.g., `PURGE 12`) to destroy the virus.
4. **Avoid Malpractice:** Guessing blindly and purging a healthy (green) node destroys real brain tissue, resulting in a fatal -25% Vitality penalty.
5. **Stabilize:** Clear all active threats to stabilize the patient, win the session, and earn **+150 Credits**.

## 💻 Terminal Command Reference

| Command | Description | Example / Syntax |
| :--- | :--- | :--- |
| `DIAG` | Initiates a diagnostic session and loads a new patient. | - |
| `ISOLATE` | Strips virus camouflage based on targeted frequency. | `ISOLATE 400` |
| `PURGE` | Destroys a specific node by its ID. | `PURGE 42` |
| `MARKET` | Opens the Black Market catalog. | - |
| `BUY` | Purchases system patches or scripts using Credits. | `BUY SHIELD` |
| `AUTOPURGE`| Executes a smart script to instantly destroy 1 virus. | - |
| `PROFILE` | Displays player stats, Credits, and active inventory. | - |
| `HELP` | Lists all available commands. | - |
| `DISCONNECT`| Severs the neuro-link and returns to the Idle state. | - |

## 🛒 The Black Market
Spend your hard-earned Credits in the Terminal (while Idle) to upgrade your hacking capabilities:
* **OVERCLOCK (500C):** Permanently extends the `ISOLATE` reveal duration from 15 seconds to 30 seconds.
* **SHIELD (800C):** Absorbs one accidental misfire, preventing the fatal -25% penalty if you purge a healthy node.
* **AUTOPURGE (100C / Charge):** A single-use smart script. Type `AUTOPURGE` mid-session to instantly locate and destroy 1 viral node without needing its ID.

## 🛠️ Compilation & Requirements
To build this project from source, ensure your development environment meets the following requirements:
1. **Lazarus IDE & Free Pascal Compiler (FPC)** (Latest version recommended).
2. **BGRABitmap** package (Installable via the Lazarus Online Package Manager).
3. **BASS Audio Library** (`bass.dll` for Windows, or `.so` for Linux). Place the library file in the same directory as the compiled executable.

Open the `.lpi` project file and press `F9` to build. The SQLite database (`neurotrace.db`) will be automatically generated upon the first launch.

---
*Developed with Lazarus / Free Pascal.*
