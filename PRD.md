# Personal Food Agent — Product Requirements

Status: Product design baseline  
Date: 21 October 2026  
Scope: Agent layer, user memory, meal planning, grocery and prepared-food discovery, and user-approved ordering

## 1. Product intent

A mobile, chat-first agent helps one user plan meals, obtain ingredients or prepared food, and learn from what the user actually eats. The agent gradually builds a user-controlled profile from answers, facts extracted from uploads, orders, and feedback. It aims to make balanced eating more practical over the medium and long term while respecting cost, preferences, cooking effort, and personal inventory. Uploaded files are processed temporarily and are not retained.

The product offers food and routine support. It does not diagnose, prescribe treatment, recommend supplements, or claim to optimize a person's clinical health. Questions about supplements or medical treatment are directed to a clinician.

## 2. Facts established in the product discussion

These are requirements or preferences stated by the founder, rather than assumptions made in this document.

| Area | Established direction |
| --- | --- |
| Onboarding | One page, at most five mostly choice-based questions. Ask about goals and current health issues, including common chronic and acute conditions. |
| Progressive learning | Ask additional small questions over time to complete the profile. |
| Inputs | Survey, chat, voice where feasible, photos, report PDFs, and other user-provided information such as a new injury or health issue. Files are discarded after fact extraction and review. |
| Main interface | Mobile chat with proactive notifications; app screens for payment information, profile updates through fact extraction from reports, and a dashboard. |
| Planning | Suggest groceries and recipes early morning or late night; permit removing options with or without a reason. |
| Commerce | After user approval, compare grocery/quick-commerce offers; also suggest a close prepared-food equivalent from known healthy-food brands or food-delivery providers. |
| Memory | Track orders, reported meals, portions, leftovers, ingredients, likes/dislikes, and changes in health context. |
| Planning edits | At plan review, accept voice or typed requests such as “something Italian,” “something simple and quick,” or “something different” and regenerate options. |
| User scope | One personal user initially. Linking an existing user as a family member is a later capability. |
| Objective | Improve the practical balance of meals and routines over the medium to long term, accounting for nutrition, energy, cost, and convenience. |
| Supplements | Do not recommend supplements. Refer questions to a doctor. |
| AI architecture | Consider local small models for efficient cost and privacy; retain persistent memory. |
| Knowledge | Nutrition-related guidance must come from an approved, curated knowledge base rather than unverified web pages. |
| Authority | User approval is required before purchases. |

## 3. Product decisions made for this specification

These choices complete the design and can be changed by a deliberate product decision.

1. **Initial account model is one person per account, with no family linking.** The launch audience is all ages as requested. Personalized planning for minors, pregnancy, eating disorders, complex medical diets, and situations requiring clinical nutrition therapy is not clinically validated; the product must not imply such validation or offer condition-specific treatment. Define age-appropriate safeguards and legal requirements before public launch.
2. **The planning unit is a rolling 3–7 day personal plan**, with a one-day option. This allows package-size and leftover optimization.
3. **The agent is one orchestrator with specialized, permissioned services**, rather than multiple autonomous agents. This keeps actions observable and limits duplicated or conflicting decisions.
4. **The default purchase flow is explicit approval of a specific basket and total.** Any material substitution, merchant change, or price increase requires fresh approval.
4a. **Target Swiggy experience: in-app checkout in Valora**, if Swiggy grants production access and the delegated OAuth/MCP terms permit it. Valora renders Swiggy's returned cart, bill, address, and payment choices, then calls the supported MCP checkout tool only after the user approves the exact order. A UPI app or QR payment step may leave Valora briefly; no Swiggy-app basket handoff is assumed.
5. **Learning prompts are event driven and rate limited**, rather than truly random. A question is asked when the answer could change a plan or resolve a meaningful uncertainty.
6. **User health information is a planning constraint, not an automatically computed diagnosis.** The system may calculate food intake estimates but does not label deficiencies from incomplete meal records.
7. **Mobile framework: Flutter.** The production client targets iOS and Android from a shared Flutter application. Evaluate on-device inference from the first implementation phase behind a client interface; core product behavior must remain available if a device cannot run the model. Cloud inference is required for complex tasks.

## 3.1 Backend implementation decisions

1. **Launch market:** India; English; INR.
2. **Cloud:** Cloudflare is the selected hosting platform. Use a modular TypeScript API on Workers with D1 (SQLite) behind repository interfaces.
3. **Sign-in:** Google OAuth 2.0 is the active sign-in option. ChatGPT/OpenAI identity sign-in is hidden and disabled while access is invite-only. Valora owns its user account, authorization, and application session.
4. **Admin knowledge management:** an admin role can add and manage nutrition sources. Source rights, validation, versioning, and publication audit remain required controls.
5. **Phase one:** implement the core PRD experience except external AI, document extraction, and Swiggy/provider integrations. Include read/write APIs for profile, preferences, and memory; a database repository layer and Flutter backend connection; planning, pantry/meal records, insights, and notification preferences/flows as feasible against approved structured/local knowledge. Defer uploads, Swiggy integration, and AI model calls to phase two.
6. **Swiggy:** production integration remains phase two and requires provider onboarding. The target is MCP checkout rendered inside Valora after user-authorized delegated access; Swiggy app handoff is not assumed. UPI payment may invoke an external UPI app or QR flow. Validate approved redirect URIs, staging/production access, app surface requirements, data terms, and checkout capabilities with Swiggy.
7. **Data policy:** retention and jurisdiction-specific privacy policy remain provisional during implementation planning and must be approved before public launch.

## 4. Target users and jobs

Primary user: an adult who wants help deciding what to eat, buying food efficiently, and keeping a sustainable routine without manually logging every ingredient.

Jobs to be done:

- “Plan meals I can realistically cook or order this week.”
- “Use what I already have before buying more.”
- “Show me choices that fit my taste, schedule, and budget.”
- “Handle the comparison work, but let me approve spending.”
- “Remember relevant facts and ask when you are uncertain.”
- “Help me see whether my habits are becoming more consistent over time.”

## 5. Core experience

### 5.1 Onboarding

One page with at most five questions. A proposed set:

1. Main goal: easier meals, more variety, enough food/protein from food, steadier routine, cost control, or other.
2. Eating pattern: vegetarian/vegan/omnivore and meals to plan for the user.
3. Safety and health context: allergies, clinician-advised food restrictions, and optional current conditions or injury; include “prefer not to say.” The optional multi-select can list common chronic and acute categories with “other” and “none,” but selection is recorded as user reported, never as a diagnosis.
4. Practical constraints: budget range, cooking time, kitchen access, and delivery preference.
5. Cuisine likes/dislikes and preferred planning/notification time.

Before using an answer, show the resulting profile summary. Safety-relevant ambiguities are clarified before meal suggestions.

### 5.2 Daily and weekly chat

The chat home is a card-led workspace. It previews the next plan, pantry, and saved food rules, with a text or voice entry point for other requests. Tapping a card or asking for an existing item opens the corresponding live app widget in place. Requests such as “What’s in my pantry?”, “Show my next plan,” and “What allergies do you have saved?” read the relevant saved state directly without an LLM call. If no valid plan is ready, show its actual status instead of inventing a response. A request that needs reasoning, computation, a new plan, or a data change switches to a focused conversation view and clears the workspace cards. The agent may ask a follow-up or present a proposed change there; saved data changes only through the appropriate confirmation flow. The interface distinguishes stored facts and plan status from generated guidance.

The agent sends a concise plan card at the chosen time. It shows meals, approximate portions, pantry items used, items to buy, estimated cost, and why the plan fits. The user can accept, edit, remove without explanation, give a reason, request a prepared-food alternative, or snooze. During review, typed or voice requests such as “something Italian,” “something simple and quick,” and “something different” rotate the proposed meals while preserving allergies, explicit restrictions, and firm budget limits. The current request applies to the current plan; the agent asks before turning it into a lasting preference.

The agent may ask one short follow-up when needed: “Do you still have the rice from Monday?” Prompts have quiet hours, frequency controls, and a skip option. The agent does not infer a dislike merely because a user ignored a notification.

### 5.3 Shopping and prepared food

After plan approval, the app checks current product availability and pricing through authorized integrations. It compares **total landed cost**: products, delivery, fees, taxes, minimum-order effects, and estimated waste. Before purchase, the user sees the exact merchant, items, quantities, substitutions, delivery window, and final price. In the first version, purchase approval is a deliberate action on this review card; a casual chat reply cannot authorize payment.

Prepared-food discovery searches for a suitable dish when cooking is inconvenient. Restaurant menu claims are not treated as verified nutrient data. If allergens, ingredients, portions, or preparation cannot be confirmed, the app communicates that uncertainty and withholds an unsafe claim of suitability.

### 5.4 Feedback and dashboard

Orders update purchase history and expected incoming items; confirmed delivery or user confirmation updates physical inventory. When ingredients are cooked, their inventory lots are reduced and the prepared meal becomes a leftover lot; eating that meal reduces the leftover lot and creates a consumption record. Directly eaten ingredients reduce their inventory lots when linked. This prevents double subtraction. Meals enter the consumed-food record only from user confirmation or an explicitly connected trusted source. Portions are ranges or estimates when uncertain. The dashboard shows plan use, food variety, grocery spend, estimated waste, and optional user-reported energy. It labels each measure by source and coverage. It does not show a single “health score.”

## 6. Functional requirements

| ID | Requirement | Acceptance condition |
| --- | --- | --- |
| FR-01 | Progressive profile | User can inspect, edit, delete, and pause every remembered fact and inference. |
| FR-02 | Document intake | PDFs/images are processed ephemerally. Only extracted fact records and minimal fact provenance may persist; original files, page images, full OCR text, and file embeddings are deleted after extraction/review. Safety-relevant facts require confirmation before becoming active constraints. |
| FR-03 | Provenance | Every recommendation can identify relevant user facts, recipe/nutrient records, and guidance versions used. |
| FR-04 | Allergy and restriction handling | Hard constraints filter candidates before ranking; unknown ingredients cannot be presented as confirmed safe. |
| FR-05 | Rolling planning | Plans account for one person's portions, package sizes, inventory, leftovers, cooking time, and budget. |
| FR-06 | User editing and rotation | Each meal or product can be replaced or removed without a reason. A typed or voice request during review regenerates the affected options. Optional reasons inform future preference suggestions. |
| FR-07 | Multi-provider comparison | Show available offers with a timestamp and full total; unavailable prices are never invented. |
| FR-08 | Purchase control | No order or charge without approval tied to exact basket, merchant, maximum total, and expiry. |
| FR-09 | Order and meal reconciliation | Orders create expected incoming items; confirmed receipt creates physical inventory. Cooking moves ingredients into prepared portions; reported eating reduces linked inventory or leftovers and records consumption exactly once. Purchase is never automatically counted as consumption. |
| FR-10 | Feedback learning | Inferred preferences remain tentative until confirmed or supported by repeated, clear signals. |
| FR-11 | Proactive notifications | User controls timing, quiet hours, categories, and frequency; high-priority safety messages follow an explicit separate policy. |
| FR-12 | Voice | In-app voice capture is supported where the device permits; notification voice reply is optional and capability gated. |
| FR-13 | Knowledge control | Nutrition guidance is retrieved only from approved, licensed, versioned sources. No open-web content is used as guidance in a production recommendation. |
| FR-14 | Health boundaries | No diagnosis, supplement recommendation, medication change, or disease-specific treatment plan. Concerning/new health issues receive a clinician referral where appropriate. |
| FR-15 | Auditability | For a plan or order, authorized staff can reconstruct input versions, model version, rules, candidate set, approval, and resulting action without storing unnecessary prompt content. |

## 7. Quality and trust requirements

- **Correctness:** Nutrition values and arithmetic come from mapped structured records and deterministic calculations. The app states when nutrient data or portion estimates are missing.
- **Privacy:** Only extracted facts from uploads may be retained. File bytes and temporary OCR/transcripts remain in protected processing memory and are purged afterward; they are never written to durable storage or logs. Health facts are encrypted and access controlled. Payment credentials remain with a payment provider; the agent receives tokens/status, not raw card data.
- **Resilience:** If AI, price, or provider APIs fail, the user can still view saved plans and edit a manual list. No order is inferred to have succeeded from a timeout.
- **Cost:** Routine extraction, retrieval, and calculations avoid large model calls. Model calls have task budgets, caching, and measurement of cost per active user.
- **Accessibility:** Chat cards and approval screens work with screen readers, localization, and low-bandwidth conditions.

## 8. Success measures and guardrails

Product measures: weekly plans viewed, plans edited/accepted, meals explicitly confirmed, pantry estimate accuracy, grocery cost per usable meal, repeat use after four weeks, and user-reported helpfulness.

Guardrails: allergy/restriction filter escapes, unsupported health claims, purchase without valid approval, price mismatch at checkout, incorrect food-to-nutrient mapping, privacy incidents, notification opt-out, and unresolved user corrections. These are monitored separately from engagement metrics.

The product must not claim improved clinical outcomes from these measures. WHO describes healthy eating in terms of adequacy, balance, moderation, and diversity, with individual needs and cultural context varying substantially; the product's dashboard therefore reports observed food behavior and uncertainty rather than a medical outcome. [WHO healthy diet](https://www.who.int/en/news-room/fact-sheets/detail/healthy-diet)

## 9. Out of scope

- Diagnosis, treatment, medical triage beyond directing the user to appropriate care, or personalized clinical nutrition therapy.
- Supplement or medication recommendations.
- Autonomous purchasing, automatic approval by a model, or agent access to raw payment credentials.
- Family accounts or shared inventory in the initial release; later, an existing user may be invited as a family member with explicit sharing choices.
- Claiming a meal was eaten from purchase or delivery evidence alone.
- Scraping unauthorized commerce sources or relying on unsupported partner APIs.

## 10. Decisions requiring business or clinical ownership

The architecture can be finalized while these operational inputs remain open:

1. Launch country, age range, language, and available commerce partners.
2. Named clinical/nutrition review owner and approved scope for condition-specific guidance.
3. Licensed regional nutrient and recipe data; rights for storing and distributing guidance.
4. Data retention/deletion schedule and jurisdiction-specific privacy/legal review.
5. Which providers support basket creation, checkout handoff, ordering, and post-order receipts.

These decisions gate market launch or particular features; they do not authorize the agent to guess missing clinical guidance, prices, or provider capabilities.
