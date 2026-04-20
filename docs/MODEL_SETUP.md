# Model Setup

The Gemma 4 model file is not committed to this repo (too large and subject to Google's model license). Follow these steps to obtain it and wire it into the Flutter app.

## 1. Download Gemma 4

Go to the Gemma model card on Kaggle or Hugging Face and accept the license. For Mandi Mate we recommend:

- **E2B int4 quantized** — fastest, good enough for demo on 4 GB RAM devices.
- **E4B int4 quantized** — higher quality reasoning at the cost of slightly slower inference. Recommended for the target demo hardware (Redmi Note 13 or similar).

Download the `.task` file for MediaPipe LLM Inference. Place it at:

```
flutter_app/assets/models/gemma4_e2b_q4.task
```

## 2. Update asset registration

Edit `flutter_app/pubspec.yaml` and uncomment the `assets/models/` entry if you're bundling the model with the APK. Alternatively, leave it out and use the one-time install flow in `GemmaService.warmup`, which downloads the model on first launch and caches it locally.

Bundling makes the APK ~1 GB. The on-first-launch install needs connectivity once, then never again. For the hackathon demo we recommend the bundled approach so the demo environment is truly offline.

## 3. Verify the model loads

Run:

```bash
cd flutter_app
flutter run --release
```

On first launch the log should show:

```
I/MandiMate: Gemma 4 warmup started
I/MandiMate: Model installed from asset (47.2s)
I/MandiMate: Model created, preferred backend: GPU
I/MandiMate: Warmup complete
```

If you see a `PreferredBackend.cpu` fallback, the device GPU couldn't accelerate the model and inference will be 2–3x slower. This is fine for the demo but worth flagging.

## 4. Flutter plugin version pinning

As of submission, `flutter_gemma` is evolving rapidly to keep pace with Gemma 4 features. The code in this repo is written against version **0.9.x**. If pub.dev shows a different version at your build time, check the changelog for breaking changes to:

- `Message.image(...)` — multimodal input shape
- `session.getResponse()` — whether tool calls are returned as a separate field or embedded in the text
- `PreferredBackend.gpu` — backend selection API

The places in our code that touch these are clearly commented with `// NOTE: flutter_gemma API shape` — search for that string.

## 5. Hardware requirements

Tested on:

- Redmi Note 13 (Snapdragon 6 Gen 1, 6 GB RAM) — E4B runs comfortably, ~1 s inference
- Pixel 6a (Tensor G1, 6 GB RAM) — E4B runs comfortably, ~1 s inference
- Samsung A14 (Helio G85, 4 GB RAM) — E2B only, ~2 s inference, usable
- Redmi 9A (Helio G25, 2 GB RAM) — does not run, below Gemma 4 minimum

The ₹8,000 price point in our pitch is realistic for Redmi Note 13–tier hardware.
