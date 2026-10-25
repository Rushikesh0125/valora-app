# Cloud AI comparison for Valora

Checked against official pricing on 23 October 2026. This is a cost/fit comparison, not a measured quality benchmark. Selected: OpenAI GPT-6 Luna for both routine and complex cloud requests. Provider credentials are still required.

## Text chat costs

Assume 10,000 requests, each with 1,500 total input tokens including instructions/history and 400 total billed output tokens. Standard paid text inference, no cache/batch discounts, search tools, taxes or hosting. Thinking tokens, if used, must fit the billed-output assumption; a longer reasoning response costs more.

| Model | USD / million input | USD / million output | Example total USD | Illustrative INR at ₹90/USD |
| --- | ---: | ---: | ---: | ---: |
| OpenAI GPT-6 Luna | 0.10 | 0.50 | 3.50 | 315 |
| Gemini 3.1 Flash-Lite | 0.25 | 1.50 | 9.75 | 877.50 |
| Gemini 3.5 Flash-Lite | 0.30 | 2.50 | 14.50 | 1,305 |
| OpenAI GPT-6.1 Sol | 2.00 | 10.00 | 70.00 | 6,300 |
| Gemini 3.6 Flash | 0.75 | 3.75 | 26.25 | 2,362.50 |

GPT-6.1 Sol and Gemini 3.6 Flash are possible escalation candidates, not equivalent-quality alternatives. Gemini 3.6 Flash prices above apply through 31 December 2026; Google lists twice those rates starting 1 January 2027. INR uses an illustrative planning rate, not a live exchange quote. No exchange-rate or budget environment variables are introduced.

Sources: [OpenAI pricing](https://developers.openai.com/api/docs/pricing), [GPT-6 Luna capabilities and pricing](https://developers.openai.com/api/docs/models/gpt-6-luna), [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing).

## Fit and recommendation

- For the text MVP, start by evaluating GPT-6 Luna: it has the lowest published token cost in this comparison. Both providers can support conversational guidance, history and structured action proposals; actual quality must be compared on Valora prompts before calling one better.
- Evaluate routine vegetarian/vegan requests, contradictory preferences, missing pantry information, paused allergies, follow-up questions, and requests to falsely claim saved changes. Measure useful answers, unsafe or unsupported claims, latency and billed tokens.
- Gemini is worth evaluating for future multimodal flows: the listed Gemini tiers cover image/video/audio input, while GPT-6 Luna lists text/image input. Document extraction and voice are separate future milestones, so this does not require choosing Gemini for current text chat.
- Google sign-in and on-device Gemma do not require Gemini as the cloud provider. Cloud credentials are separate from OAuth credentials.
- Use the appropriate paid production API terms for actual user data. Google's pricing page states that free-tier content can be used to improve products, while its standard paid tiers do not use content for that purpose.
- Saved-profile reads should call neither provider. Verified nutrition arithmetic, approved source retrieval, persistence and ordering approval remain application responsibilities.

Selected starting configuration: OpenAI GPT-6 Luna for all cloud chat; keep the adapter configurable and add a more expensive escalation model only when evaluation shows a need. A real API key and account access are still required to verify live responses.
