# Valora unified demo — approximately 2:40

Use a synthetic account, no personal medical details. Record actual results; trim waiting with visible edits. Do not portray illustrative screens as runtime footage.

- 0:00–0:20 · Cover and app. “A recent health diagnosis made me rethink what I eat. But every search meant repeating my preferences and restrictions. I built Valora to make everyday food decisions easier.”
- 0:20–0:40 · Saved profile. “Valora remembers eating preferences, reported allergies, foods to avoid, preferred cuisines and time to cook. These rules shape meal choices. It supports everyday healthy eating, not clinical diets.”
- 0:40–1:05 · You → food preferences: type a cuisine and select a lookup suggestion, then save. “Cuisine suggestions help me save what I enjoy. My saved food preferences drive both the conversation and my meal plan—there is no separate setup.” Show the saved cuisine chips.
- 1:05–1:25 · Plan and its evidence. “Qloo's returned cuisine affinities reach NVIDIA Nemotron through Nebius. Valora first checks recipe restrictions, then validates the model's selection and saves the plan.” Read actual returned cuisines; never claim an input tag was returned unless shown.
- 1:25–1:50 · Chat: “I want Italian for dinner tonight.” Show replacement, confirm, open Plan. “I can adapt dinner without rebuilding my day. Changes remain proposals until I confirm them. The other meals stay in place.”
- 1:50–2:10 · Pantry voice: “I have a kilogram of potatoes and two cartons of milk, one litre each.” Preview and confirm. “Natural speech becomes a batch of proposed pantry updates. I review quantities before saving.”
- 2:10–2:30 · Architecture: Flutter → Cloudflare Worker/D1 → Qloo taste intelligence + Nebius/NVIDIA Nemotron. “One app and one backend combine taste intelligence, conversational understanding, explicit validation and user control. Private health and restriction fields are not sent to Qloo.”
- 2:30–2:40 · Saved plan and cover. “Valora is our Android MVP. Next: richer regional food coverage and more rigorous personalization. Eat right, every day.”

Before recording: install 0.2.0 over the existing app; check Google sign-in and microphone on the phone. Use remaining meal slots appropriate to recording time. Leave enough time for live cuisine lookup (observed about two seconds), then visibly cut loading. Avoid repeated requests within the per-account minute budget. Venue leads are unverified for restrictions and prices; Swiggy ordering is unavailable.
