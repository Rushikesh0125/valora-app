import { z } from "zod";

export class NebiusError extends Error {
  constructor(public readonly code: "ai_provider_unavailable" | "ai_provider_timeout" | "ai_provider_rate_limited" | "ai_provider_request_failed" | "ai_provider_invalid_response") {
    super(code);
  }
}

const completionSchema = z.object({
  choices: z.array(z.object({
    finish_reason: z.literal("stop"),
    message: z.object({ content: z.string().trim().min(1) }),
  })).min(1),
  usage: z.object({
    prompt_tokens: z.number().int().nonnegative(),
    completion_tokens: z.number().int().nonnegative(),
  }).optional(),
});

export async function callNebius(key: string, model: string, system: string, input: string, maxOutputTokens: number, responseSchema?: Record<string, unknown>) {
  const signal = AbortSignal.timeout(40000);
  try {
    const response = await fetch("https://api.tokenfactory.us-central1.nebius.com/v1/chat/completions", {
      method: "POST",
      signal,
      headers: { authorization: `Bearer ${key}`, "content-type": "application/json" },
      body: JSON.stringify({
        model, stream: false, max_tokens: maxOutputTokens,
        // Reserve the bounded output budget for the user-facing answer.
        chat_template_kwargs: { enable_thinking: false },
        ...(responseSchema ? {response_format:{type:'json_schema',json_schema:{name:'first_day_meal_selection',strict:true,schema:responseSchema}}} : {}),
        messages: [{ role: "system", content: system }, { role: "user", content: input }],
      }),
    });
    if (!response.ok) {
      await response.body?.cancel();
      if (response.status === 401 || response.status === 403) throw new NebiusError("ai_provider_unavailable");
      if (response.status === 429) throw new NebiusError("ai_provider_rate_limited");
      throw new NebiusError("ai_provider_request_failed");
    }
    // Bound provider output before parsing; neither raw responses nor reasoning are logged.
    const reader = response.body?.getReader();
    if (!reader) throw new NebiusError("ai_provider_invalid_response");
    const chunks: Uint8Array[] = [];
    let size = 0;
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        size += value.byteLength;
        if (size > 256 * 1024) {
          await reader.cancel();
          throw new NebiusError("ai_provider_invalid_response");
        }
        chunks.push(value);
      }
    } finally { reader.releaseLock(); }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    let decoded: unknown;
    try { decoded = JSON.parse(new TextDecoder().decode(bytes)); }
    catch { throw new NebiusError("ai_provider_invalid_response"); }
    const parsed = completionSchema.safeParse(decoded);
    if (!parsed.success) throw new NebiusError("ai_provider_invalid_response");
    return {
      text: parsed.data.choices[0].message.content,
      inputTokens: parsed.data.usage?.prompt_tokens ?? 0,
      outputTokens: parsed.data.usage?.completion_tokens ?? 0,
    };
  } catch (error) {
    if (error instanceof NebiusError) throw error;
    if (signal.aborted || (error instanceof Error && error.name === "TimeoutError")) throw new NebiusError("ai_provider_timeout");
    throw new NebiusError("ai_provider_request_failed");
  }
}
