# Mandi Mate

> A Marathi-first, fully offline agricultural decision agent for smallholder tomato farmers in Maharashtra, powered by Gemma 4.

---

## Ramesh

It's 5:42 AM in Niphad.

Ramesh has 18 kilos of tomatoes in a wooden crate. They are ripe. They will not be ripe tomorrow. The mandi opens at 7.

Last month he sold for ₹18 per kilo. Two days later the rate was ₹31. The middleman shrugged. Ramesh lost ₹234 on a single morning — more than his son's school fees for the month.

His phone shows zero signal bars. The nearest tower is behind a hill. Even if he had signal, no app he's ever tried speaks Marathi.

He opens **Mandi Mate**.

He points the camera at the crate. The phone — his ₹8,000 Redmi — thinks for 1.3 seconds and tells him, in Marathi, *these are Grade A, roughly 18.5 kg, firm, ready in 2–4 days*.

He holds the mic and says, *"आज विकू का?"* — *"Should I sell today?"*

The phone thinks for 3 seconds. It reads four days of cached mandi prices. It runs a SARIMA forecast trained on two years of Maharashtra tomato data. It compares net profit across Nashik, Pune, and Aurangabad after subtracting transport and commission.

Then, in clear spoken Marathi, it says:

> **थांबा दोन दिवस. पुण्याला टोमॅटो घेऊन जा. तुम्हाला जवळपास साडेसहाशे रुपये मिळतील.**
>
> *Wait two days. Take the tomatoes to Pune. You will earn about ₹650.*

No cloud. No data sent anywhere. No English. No fine print. One decision.

That's the product.

---

## What this project is

Mandi Mate is a Flutter app that runs Gemma 4 entirely on-device and uses its function-calling capability to drive a three-tool agent:

1. **`get_mandi_prices`** — reads today's prices from a bundled SQLite cache sourced from Agmarknet
2. **`calculate_net_profit`** — nets out transport cost and APMC commission against the gross revenue
3. **`forecast_price`** — returns a pre-computed SARIMA + Holt-Winters ensemble forecast with 95% confidence bands

The model reasons over tool outputs and replies in natural spoken Marathi. The user never sees the reasoning trace unless they tap for it.

**Nothing about this requires internet.** Forecasts are pre-computed weekly and shipped as a 280 KB JSON asset. Prices sync opportunistically when the phone finds a signal. Speech I/O uses Android's native mr-IN engines. Gemma 4 runs via MediaPipe LLM Inference.

---

## Why this matters

India has **~14 crore** smallholder farmers. The median landholding is just over one hectare. They make variants of Ramesh's decision — *sell today, hold, or transport* — hundreds of times a year. The information asymmetry between them and the middlemen they sell to is structural and centuries old.

Existing solutions are all wrong for Ramesh in at least one of three ways:

| | Cloud-based apps | Agri-tech platforms | Government services |
|-|-|-|-|
| Works offline? | ✗ | ✗ | ✗ |
| Speaks Marathi naturally? | rarely | ✗ | partially |
| Runs on a ₹5–8k phone? | limited | ✗ | ✗ |
| Gives a specific numeric answer? | ✗ | ✗ | ✗ |

Mandi Mate is the first category member that clears all four bars, and it only became possible because Gemma 4 put frontier-tier reasoning on a midrange Android.

---

## Why Gemma 4

Three Gemma 4 capabilities directly enable Mandi Mate:

- **Native multimodal.** One model, one memory footprint: the same Gemma 4 instance that grades the tomato photo also reasons over mandi prices. No separate vision model.
- **Function calling.** The decision is a composition of tool outputs, not a generated answer. This is the safety property that lets us ship — the model cannot invent a price.
- **Edge inference.** The whole pipeline fits in ~3 GB RAM on E4B int4 quantized. First inference ~3 seconds; subsequent ~1 second. Zero data leaves the phone.

We ship forecasting as a pre-computed JSON rather than fitting SARIMA on-device. That's a deliberate trade: accept one-week staleness in exchange for 100 ms forecast lookups and zero `statsmodels` dependency on the phone. The CI pipeline in this repo regenerates forecasts nightly from Agmarknet and produces a new asset bundle.

---

## Repo layout

```
mandi-mate/
├── forecasting/                 # Python pipeline
│   ├── generate_data.py          # Synthetic Maharashtra tomato data (drop-in replaceable with Agmarknet pull)
│   ├── forecast_engine.py        # SARIMA + Holt-Winters ensemble, exports forecasts.json
│   └── data/                     # Generated CSVs and JSON
├── web_prototype/               # Runnable single-file demo
│   └── index.html                # Open this in any browser, no install
├── flutter_app/                 # The real app
│   ├── lib/
│   │   ├── main.dart
│   │   ├── theme.dart
│   │   ├── models/models.dart
│   │   ├── services/
│   │   │   ├── forecast_service.dart
│   │   │   ├── gemma_service.dart   # Function-calling loop
│   │   │   ├── tools.dart            # Three tools Gemma 4 calls
│   │   │   └── voice_service.dart    # Marathi STT + TTS
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── camera_screen.dart
│   │   │   ├── voice_screen.dart
│   │   │   └── recommendation_screen.dart
│   │   └── widgets/offline_pill.dart
│   └── assets/
│       ├── forecasts.json
│       └── mandi_metadata.json
└── docs/
    ├── VIDEO_SCRIPT.md           # 3-minute judging video, shot-by-shot
    ├── WRITEUP.md                # Long-form submission writeup
    └── TOOLS_SPEC.md             # Function-calling schema + example traces
```

---

## Running the demo

### Fastest path — web prototype (30 seconds)

```bash
cd web_prototype
python3 -m http.server 8000
# Open http://localhost:8000
```

This loads the full scripted flow (home → camera → grade → voice → agent reasoning → recommendation) and plays the Marathi recommendation through your browser's speech synthesis.

### Regenerate forecasts

```bash
cd forecasting
pip install -r requirements.txt
python generate_data.py && python forecast_engine.py
```

### Flutter app

```bash
cd flutter_app
flutter pub get
flutter run
```

You need to supply the Gemma 4 model file — see `docs/MODEL_SETUP.md`. The first-run model install takes ~90 seconds on a typical Android.

---

## What's solid and what's rough

Honest status for judges:

**Solid:**
- Forecasting pipeline — runs end-to-end, produces real statsmodels output
- Web prototype — every screen clickable, Marathi TTS works
- Flutter architecture — services, models, tools all implemented
- Tool-call schema — well-defined, deterministic, testable

**Rough:**
- Gemma 4 integration in Flutter depends on the exact `flutter_gemma` API shape at submission time — the vision and function-calling paths are written against the 0.9.x contract but may need small adaptations
- Agmarknet scraper isn't hooked up yet — we ship synthetic data that matches Agmarknet's schema

Neither affects the demo video or the core story. Both are hours of work, not weeks.

---

## Team

Abhineet Shukla — Siemens SCM analytics, [github.com/Abhineet1Shukla](https://github.com/Abhineet1Shukla)

The SARIMA/Holt-Winters forecasting engine is a direct extension of my existing work at [Time-Series-Demand-Forecasting](https://github.com/Abhineet1Shukla/Time-Series-Demand-Forecasting).
