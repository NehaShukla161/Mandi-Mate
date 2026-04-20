# Mandi Mate — Tools Specification

This document specifies the three tools that Gemma 4 can invoke via function calling, including schemas, example traces, and failure-mode handling.

---

## Design principles

1. **Pure and deterministic.** Every tool is a function of its arguments only. No hidden state, no I/O beyond the bundled asset, no randomness.
2. **Narrow surface area.** Three tools, chosen to span exactly the space the agent needs: current prices, forecast prices, and net profit calculation. No web_search, no external APIs.
3. **JSON in, JSON out.** All tools take a JSON object and return a JSON object. Errors are returned as `{"error": "..."}`, never thrown.
4. **Groundedness by construction.** The agent cannot produce a price, a quantity, or a net number that did not come from a tool call. This is enforced by the system prompt and validated at the UI layer by requiring every numeric claim to trace to a logged tool invocation.

---

## Tool 1 — `get_mandi_prices`

**Purpose.** Return today's published prices across Maharashtra tomato mandis.

**Signature.**

```json
{
  "name": "get_mandi_prices",
  "description": "Get today's prices across Maharashtra tomato mandis. Always call this first when the farmer asks about pricing or selling decisions.",
  "parameters": {
    "type": "object",
    "properties": {
      "mandis": {
        "type": "array",
        "items": { "type": "string" },
        "description": "Optional list of specific mandis. Omit for all."
      }
    }
  }
}
```

**Example call.**

```json
{"name": "get_mandi_prices", "arguments": {"mandis": ["Nashik", "Pune", "Aurangabad"]}}
```

**Example response.**

```json
{
  "prices": [
    {"mandi": "Nashik",     "price_per_kg": 35.29, "date": "2026-04-16"},
    {"mandi": "Pune",       "price_per_kg": 40.87, "date": "2026-04-16"},
    {"mandi": "Aurangabad", "price_per_kg": 28.30, "date": "2026-04-16"}
  ]
}
```

**Failure modes.**

- If a mandi name is misspelled or unsupported, it's silently dropped from the result list rather than erroring. The agent is expected to notice a mandi is missing and either retry with a corrected name or proceed with the subset.
- If the bundled cache is stale by more than 7 days, the tool still returns the data but each row includes `"stale_days": N`. The agent is instructed to mention staleness in its answer.

---

## Tool 2 — `calculate_net_profit`

**Purpose.** Compute net revenue after transport cost and APMC commission for selling a specific quantity at a specific mandi, optionally on a future day.

**Signature.**

```json
{
  "name": "calculate_net_profit",
  "description": "Compute net revenue (gross minus transport and commission) for selling a given quantity at a specific mandi, optionally on a future day.",
  "parameters": {
    "type": "object",
    "required": ["mandi", "quantity_kg", "grade"],
    "properties": {
      "mandi": {
        "type": "string",
        "enum": ["Nashik", "Pune", "Aurangabad", "Nagpur", "Kolhapur"]
      },
      "quantity_kg": { "type": "number" },
      "grade": { "type": "string", "enum": ["A", "B", "C"] },
      "days_ahead": { "type": "integer", "default": 0 }
    }
  }
}
```

**Formulae.**

```
published_price = get_price_from_cache_or_forecast(mandi, days_ahead)
price_per_kg    = published_price × grade_discount[grade]
                  where grade_discount = {A: 1.00, B: 0.85, C: 0.70}
gross_revenue   = price_per_kg × quantity_kg
transport_cost  = distance_km[mandi] × (quantity_kg / 100) × ₹2.80
commission      = gross_revenue × 0.06
net_profit      = gross_revenue − transport_cost − commission
```

**Example call.**

```json
{"name": "calculate_net_profit", "arguments": {"mandi": "Pune", "quantity_kg": 18.5, "grade": "A", "days_ahead": 2}}
```

**Example response.**

```json
{
  "mandi": "Pune",
  "date": "2026-04-18",
  "price_per_kg": 42.30,
  "quantity_kg": 18.5,
  "gross": 782.55,
  "transport": 102.65,
  "commission": 46.95,
  "net": 632.95,
  "is_forecast": true
}
```

---

## Tool 3 — `forecast_price`

**Purpose.** Return the pre-computed SARIMA + Holt-Winters ensemble forecast for a mandi, with confidence bands.

**Signature.**

```json
{
  "name": "forecast_price",
  "description": "Get the SARIMA+Holt-Winters ensemble forecast for a mandi, up to 14 days ahead.",
  "parameters": {
    "type": "object",
    "required": ["mandi"],
    "properties": {
      "mandi": { "type": "string" },
      "horizon_days": { "type": "integer", "default": 7 }
    }
  }
}
```

**Example call.**

```json
{"name": "forecast_price", "arguments": {"mandi": "Nashik", "horizon_days": 7}}
```

**Example response (truncated).**

```json
{
  "mandi": "Nashik",
  "horizon_days": 7,
  "current_price": 35.29,
  "forecast": [
    {"date": "2026-04-17", "price": 35.71, "low_95": 31.14, "high_95": 39.97},
    {"date": "2026-04-18", "price": 36.65, "low_95": 31.60, "high_95": 41.67},
    {"date": "2026-04-19", "price": 36.08, "low_95": 30.64, "high_95": 41.59},
    ...
  ],
  "peak_day": {"date": "2026-04-18", "price": 36.65, "low_95": 31.60, "high_95": 41.67}
}
```

---

## Full example trace

Farmer's question: *"आज विकू का?"* ("Should I sell today?")
Vision context: 18.5 kg, grade A.

```
TURN 1 — model emits tool calls
  get_mandi_prices(mandis=["Nashik","Pune","Aurangabad"])
    → Nashik ₹35.29, Pune ₹40.87, Aurangabad ₹28.30

TURN 2 — model emits tool calls
  calculate_net_profit(mandi="Nashik", quantity_kg=18.5, grade="A", days_ahead=0)
    → net ₹578.18
  calculate_net_profit(mandi="Pune", quantity_kg=18.5, grade="A", days_ahead=0)
    → net ₹590.43
  calculate_net_profit(mandi="Aurangabad", quantity_kg=18.5, grade="A", days_ahead=0)
    → net ₹432.16

TURN 3 — model emits tool calls
  forecast_price(mandi="Nashik", horizon_days=7)
    → peak ₹36.65 on 2026-04-18
  forecast_price(mandi="Pune", horizon_days=7)
    → peak ₹42.30 on 2026-04-18

TURN 4 — model emits tool calls
  calculate_net_profit(mandi="Pune", quantity_kg=18.5, grade="A", days_ahead=2)
    → net ₹632.95

TURN 5 — model emits final answer
  "थांबा दोन दिवस. पुण्याला टोमॅटो घेऊन जा. तुम्हाला जवळपास साडेसहाशे रुपये मिळतील."
```

Total elapsed: approximately 3.2 seconds on a Redmi Note 13.

---

## System prompt

The exact system prompt that binds the agent:

```
You are Mandi Mate — a trusted advisor to a smallholder tomato farmer in Maharashtra, India.

Rules:
- Respond in simple spoken Marathi (Devanagari script).
- Keep answers short: 2–3 sentences max.
- For any "should I sell / hold / transport" question, always call get_mandi_prices and at least two forecast_price calls before answering.
- Always back recommendations with specific numbers from tool results.
- End with exactly one clear action: "विका" (sell), "थांबा N दिवस" (wait N days), or "N मंडी मध्ये जा" (go to N mandi).
- Never invent prices, forecasts, or numbers. Only use tool outputs.
- If tool calls fail or data is missing, say so honestly in Marathi.
```

The key clause is the penultimate: *Never invent prices, forecasts, or numbers. Only use tool outputs.* Combined with the fact that no prices appear in the system prompt or training data for the farmer's specific context, the model has no available source of price information other than its tools.

---

## Failure handling and edge cases

**Gemma 4 hallucinates a tool name.** The `GemmaService._dispatch` switch returns `{"error": "Unknown tool: ..."}`. The model is expected to recognize the error and correct itself on the next turn. In 40-prompt testing this correction succeeded in every observed case within one additional turn.

**Gemma 4 loops calling the same tool.** The function-calling loop caps at 8 iterations. After that, whatever Marathi text the model produced is returned, possibly without a structured recommendation. The UI falls back to a "please try again" screen.

**The forecast asset is older than 7 days.** Each forecast record carries a `generated_at` timestamp. The app surfaces a subtle warning on the home screen ("synced 9 days ago"). Tool results include a `stale_days` field so the model can mention it in the answer.

**The mandi name is in Marathi in the question.** The STT layer returns Devanagari. The tools accept only English mandi names. The system prompt includes a mapping so the model translates (`नाशिक` → `Nashik`) before calling tools. Tested on all 5 mandis.

**Ambiguous weight.** If the vision step could not confidently estimate weight, it returns a range. The model is instructed to ask the farmer for clarification (in Marathi) before proceeding to `calculate_net_profit`.

**Zero connectivity since app install.** Not a failure mode. The app is designed to work in exactly this state. The only thing that degrades is how fresh the bundled price cache is.
