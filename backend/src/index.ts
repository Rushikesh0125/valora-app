import {handleQloo,QlooError,consumeRate} from './qloo.js';
import { PantryInterpreter } from './pantry-interpreter.js';
import { PersonalFoodChat } from './personal-food-chat.js';
import { MealPlanChanges } from './meal-plan-changes.js';
import { FirstDayPlanService } from "./first-day-plan.js";
import { z } from "zod";
import { authenticate } from "./auth.js";
import { database } from "./db.js";
import { D1UserRepository } from "./repository.js";
import { D1FoodRepository, FoodStateConflict, FoodStateTooLarge, foodWriteSchema, readFoodWrite } from "./food-state.js";
import { NebiusError } from "./nebius.js";
import { AiConsentRequired, AiProviderUnavailable, AiService } from "./ai.js";
import type { Env } from "./types.js";
import {
  cancelIdentitySignIn, completeIdentityCallback, exchangeAppCode, IdentityConfigurationError,
  IdentityExchangeError, publicJwks, revokeRefreshToken, rotateRefreshToken, startIdentitySignIn,
} from "./identity.js";

const profileSchema = z.object({
  goals:z.array(z.string().trim().min(1).max(80)).max(20), eatingPattern:z.string().trim().min(1).max(80),
  exclusions:z.string().max(2000), allergies:z.array(z.string().trim().min(1).max(120)).max(100),
  healthContext:z.array(z.string().trim().min(1).max(200)).max(100), cuisines:z.array(z.string().trim().min(1).max(120)).max(100),
  otherGoal:z.string().max(300), otherAllergy:z.string().max(500), otherHealth:z.string().max(500), otherCuisine:z.string().max(300),
  coverage:z.string().max(120), weeklyBudgetInr:z.number().int().min(0).max(10_000_000), cookingMinutes:z.number().int().min(0).max(1440),
  planningTime:z.string().max(80), acknowledged:z.boolean(),
}).strict();
const preferencesSchema = z.object({ locale:z.string().min(2).max(20), currency:z.literal("INR"), notificationsEnabled:z.boolean(),
  notificationFrequency:z.string().min(1).max(40), notificationCategories:z.array(z.string().min(1).max(80)).max(30),
  quietStart:z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/), quietEnd:z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/), timeZone:z.string().min(1).max(80),
}).strict();
const memorySchema = z.object({ key:z.string().trim().min(1).max(120), label:z.string().trim().min(1).max(120), value:z.string().trim().min(1).max(4000),
  source:z.string().trim().min(1).max(300), safetyRelevant:z.boolean(), status:z.enum(["active","paused"]).default("active") }).strict();
const aiInputSchema = z.object({ task:z.enum(["conversation","summarize","extract_draft"]), complexity:z.enum(["routine","complex"]),
  prompt:z.string().trim().min(1).max(12000), context:z.string().max(20000).optional() }).strict();

function response(data: unknown, status = 200, headers?: HeadersInit): Response {
  const responseHeaders = new Headers(headers);
  responseHeaders.set("cache-control", "no-store");
  return Response.json(data, { status, headers: responseHeaders });
}
function parseBody<T>(schema: z.ZodType<T>, body: unknown): T | Response {
  const parsed = schema.safeParse(body);
  return parsed.success ? parsed.data : response({ error:"invalid_request", details:parsed.error.issues.map(i=>({path:i.path,message:i.message})) }, 400);
}
function corsHeaders(request: Request, env: Env): Headers {
  const headers = new Headers({ "vary":"Origin", "access-control-allow-methods":"GET, PUT, POST, PATCH, DELETE, OPTIONS", "access-control-allow-headers":"authorization, content-type", "access-control-max-age":"600" });
  const origin = request.headers.get("origin");
  const allowed = (env.ALLOWED_ORIGINS ?? "").split(",").map(s=>s.trim()).filter(Boolean);
  if (origin && allowed.includes(origin)) headers.set("access-control-allow-origin", origin);
  return headers;
}

const signInStartSchema = z.object({ clientState:z.string().regex(/^[A-Za-z0-9_-]{32,128}$/) }).strict();
const codeExchangeSchema = z.object({ code:z.string().min(32).max(256), state:z.string().regex(/^[A-Za-z0-9_-]{32,128}$/) }).strict();
const refreshSchema = z.object({ refreshToken:z.string().min(32).max(256) }).strict();
const logoutSchema = z.object({ refreshToken:z.string().min(32).max(256) }).strict();

function authErrorResponse(error: unknown, headers: Headers): Response {
  if (error instanceof IdentityConfigurationError) return response({error:"authentication_unavailable"},503,headers);
  if (error instanceof IdentityExchangeError) return response({error:"sign_in_failed"},401,headers);
  console.error("identity_request_failed", error instanceof Error ? error.message : "unknown");
  return response({error:"internal_error"},500,headers);
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const headers = corsHeaders(request, env);
    if (request.method === "OPTIONS") return new Response(null, { status:204, headers });
    const url = new URL(request.url);
    if (url.pathname === "/health" && request.method === "GET") return response({ status:"ok", service:"valora-nebius-api" }, 200, headers);
    if (url.pathname === "/.well-known/jwks.json" && request.method === "GET") {
      try {
        const body = await publicJwks(env);
        return Response.json(body,{headers:{"cache-control":"public, max-age=300","content-type":"application/jwk-set+json"}});
      } catch (e) { return authErrorResponse(e,headers); }
    }
    const providerStart = url.pathname.match(/^\/v1\/auth\/google\/start$/);
    if (providerStart && request.method === "POST") {
      const body = parseBody(signInStartSchema,await request.json().catch(()=>null));
      if (body instanceof Response) return body;
      try {
        const authUrl = await startIdentitySignIn("google",body.clientState,database(env),env,url);
        return response({data:{authorizationUrl:authUrl}},200,headers);
      } catch (e) { return authErrorResponse(e,headers); }
    }
    const providerCallback = url.pathname.match(/^\/v1\/auth\/google\/callback$/);
    if (providerCallback && request.method === "GET") {
      const provider = "google" as const;
      const state = url.searchParams.get("state") ?? "";
      if (!/^[A-Za-z0-9_-]{32,128}$/.test(state)) return response({error:"sign_in_failed"},400,headers);
      try {
        const pool = database(env);
        if (url.searchParams.has("error")) {
          const clientState = await cancelIdentitySignIn(provider,state,pool);
          return new Response(null,{status:302,headers:{location:mobileSignInErrorRedirect(env,clientState),"cache-control":"no-store"}});
        }
        const code = url.searchParams.get("code") ?? "";
        if (!code || code.length > 4096) throw new IdentityExchangeError("authorization_code_invalid");
        const redirect = await completeIdentityCallback(provider,code,state,pool,env,url);
        return new Response(null,{status:302,headers:{location:redirect,"cache-control":"no-store","referrer-policy":"no-referrer"}});
      } catch (e) { return authErrorResponse(e,headers); }
    }
    if (url.pathname === "/v1/auth/exchange" && request.method === "POST") {
      const body=parseBody(codeExchangeSchema,await request.json().catch(()=>null)); if(body instanceof Response)return body;
      try { return response({data:await exchangeAppCode(body.code,body.state,database(env),env)},200,headers); }
      catch(e) { return authErrorResponse(e,headers); }
    }
    if (url.pathname === "/v1/auth/refresh" && request.method === "POST") {
      const body=parseBody(refreshSchema,await request.json().catch(()=>null)); if(body instanceof Response)return body;
      try { return response({data:await rotateRefreshToken(body.refreshToken,database(env),env)},200,headers); }
      catch(e) { return authErrorResponse(e,headers); }
    }
    if (url.pathname === "/v1/auth/logout" && request.method === "POST") {
      const body=parseBody(logoutSchema,await request.json().catch(()=>null)); if(body instanceof Response)return body;
      try { await revokeRefreshToken(body.refreshToken,database(env)); return response({data:{revoked:true}},200,headers); }
      catch(e) { return authErrorResponse(e,headers); }
    }
    if (!url.pathname.startsWith("/v1/")) return response({ error:"not_found" }, 404, headers);
    let principal;
    try { principal = await authenticate(request, env); }
    catch (e) { console.error("authentication_configuration_error", e instanceof Error ? e.message : "unknown"); return response({ error:"authentication_unavailable" }, 503, headers); }
    if (!principal) return response({ error:"unauthorized" }, 401, headers);
    try {
      const repository = new D1UserRepository(database(env));
      principal = await repository.resolvePrincipal(principal);
      const userId = principal.userId;
      if(url.pathname.startsWith('/v1/qloo/')) {
        const result=await handleQloo(request,env,principal);
        result.headers.forEach((value,key)=>headers.set(key,value));
        return new Response(result.body,{status:result.status,headers});
      }
      if(request.method==='POST'&&['/v1/ai/respond','/v1/pantry/interpret','/v1/meal-plan/proposals','/v1/first-day-plan'].includes(url.pathname)&&env.QLOO_ENABLED==='true')await consumeRate(database(env),userId,6,'ai');
      if (url.pathname === '/v1/meal-plan/proposals' && request.method === 'POST') {
        const body=parseBody(z.object({request:z.string().trim().min(1).max(12000)}).strict(),await request.json().catch(()=>null));
        if(body instanceof Response) return body;
        return response({data:await new MealPlanChanges(database(env),env).propose(principal,body.request)},200,headers);
      }
      const proposalMatch=url.pathname.match(/^\/v1\/meal-plan\/proposals\/([a-f0-9-]{36})\/confirm$/);
      if(proposalMatch && request.method==='POST') return response({data:await new MealPlanChanges(database(env),env).confirm(principal,proposalMatch[1])},200,headers);
      if (url.pathname === "/v1/first-day-plan" && request.method === "GET") return response({data:await new FirstDayPlanService(database(env),env).get(userId)},200,headers);
      if (url.pathname === "/v1/first-day-plan" && request.method === "POST") {
        const body=parseBody(z.object({retry:z.boolean().default(false),confirmedPreferences:z.boolean().default(false)}).strict(),await request.json().catch(()=>null));
        if(body instanceof Response) return body;
        return response({data:await new FirstDayPlanService(database(env),env).start(principal,body.retry,body.confirmedPreferences)},200,headers);
      }
      if (url.pathname === '/v1/pantry/interpret' && request.method === 'POST') {
        const body=parseBody(z.object({transcript:z.string().trim().min(1).max(4000)}).strict(),await request.json().catch(()=>null));
        if(body instanceof Response)return body;
        return response({data:await new PantryInterpreter(database(env),env).interpret(principal,body.transcript)},200,headers);
      }
      if (url.pathname === "/v1/food-state" && request.method === "GET") {
        return response({data:await new D1FoodRepository(database(env)).get(userId)},200,headers);
      }
      if (url.pathname === "/v1/food-state" && request.method === "PUT") {
        const body = parseBody(foodWriteSchema, await readFoodWrite(request));
        if (body instanceof Response) return body;
        return response({data:await new D1FoodRepository(database(env)).save(userId,body)},200,headers);
      }
      const ai = new AiService(database(env), env);
      if (url.pathname === "/v1/ai/consent" && request.method === "GET") return response({data:{enabled:await ai.consent(userId)}},200,headers);
      if (url.pathname === "/v1/ai/consent" && request.method === "PUT") {
        const body=parseBody(z.object({enabled:z.boolean()}).strict(),await request.json().catch(()=>null)); if(body instanceof Response)return body;
        await ai.setConsent(userId,body.enabled);
        return response({data:{enabled:body.enabled}},200,headers);
      }
      if (url.pathname === "/v1/ai/respond" && request.method === "POST") {
        const body=parseBody(aiInputSchema,await request.json().catch(()=>null)); if(body instanceof Response)return body;
        const result=body.task==='conversation' ? await new PersonalFoodChat(database(env),env).respond(principal,body) : await ai.respond(principal,body);
        return response({data:result},200,headers);
      }
      if (url.pathname === "/v1/profile" && request.method === "GET") return response({ data:await repository.getProfile(userId) },200,headers);
      if (url.pathname === "/v1/profile" && request.method === "PUT") {
        const body = parseBody(profileSchema, await request.json().catch(()=>null)); if (body instanceof Response) return body;
        return response({ data:await repository.saveProfile(userId,body) },200,headers);
      }
      if (url.pathname === "/v1/preferences" && request.method === "GET") return response({ data:await repository.getPreferences(userId) },200,headers);
      if (url.pathname === "/v1/preferences" && request.method === "PUT") {
        const body = parseBody(preferencesSchema, await request.json().catch(()=>null)); if (body instanceof Response) return body;
        return response({ data:await repository.savePreferences(userId,body) },200,headers);
      }
      if (url.pathname === "/v1/memory" && request.method === "GET") return response({ data:await repository.listMemory(userId) },200,headers);
      if (url.pathname === "/v1/memory" && request.method === "POST") {
        const body = parseBody(memorySchema, await request.json().catch(()=>null)); if (body instanceof Response) return body;
        return response({ data:await repository.upsertMemory(userId,body) },201,headers);
      }
      const memoryMatch = url.pathname.match(/^\/v1\/memory\/([0-9a-f-]+)$/i);
      if (memoryMatch && request.method === "PATCH") {
        const body = parseBody(z.object({status:z.enum(["active","paused"])}).strict(),await request.json().catch(()=>null)); if(body instanceof Response)return body;
        const fact = await repository.updateMemoryStatus(userId,memoryMatch[1],body.status);
        return fact ? response({data:fact},200,headers) : response({error:"not_found"},404,headers);
      }
      if (memoryMatch && request.method === "DELETE") return await repository.deleteMemory(userId,memoryMatch[1]) ? response({data:{deleted:true}},200,headers) : response({error:"not_found"},404,headers);
      return response({error:"not_found"},404,headers);
    } catch (e) {
      if (e instanceof QlooError) return response({error:e.message},e.status,headers);
      if (e instanceof FoodStateConflict) return response({error:"food_state_conflict"},409,headers);
      if (e instanceof FoodStateTooLarge) return response({error:"food_state_too_large"},413,headers);
      if (e instanceof NebiusError) return response({error:e.code}, e.code === "ai_provider_timeout" ? 504 : e.code === "ai_provider_rate_limited" ? 429 : e.code === "ai_provider_unavailable" ? 503 : 502,headers);
      if (e instanceof AiConsentRequired) return response({error:"cloud_ai_consent_required"},403,headers);
      if (e instanceof AiProviderUnavailable) return response({error:"ai_provider_unavailable"},503,headers);
      if (e instanceof Error && (e.message.startsWith("openai_http_") || e.message.startsWith("gemini_http_"))) return response({error:"ai_provider_request_failed"},502,headers);
      console.error("api_request_failed", { path:url.pathname, error:e instanceof Error ? e.message : "unknown" });
      return response({error:"internal_error"},500,headers);
    }
  },
};

function mobileSignInErrorRedirect(env: Env, clientState: string | null): string {
  if (!env.MOBILE_AUTH_REDIRECT_URI) throw new IdentityConfigurationError("mobile_auth_redirect_uri_not_configured");
  const redirect = new URL(env.MOBILE_AUTH_REDIRECT_URI);
  if (redirect.protocol !== "valoranebius:" || redirect.hostname !== "auth" || redirect.pathname !== "/callback") throw new IdentityConfigurationError("mobile_auth_redirect_uri_invalid");
  redirect.search = new URLSearchParams({error:"sign_in_failed", ...(clientState ? {state:clientState} : {})}).toString();
  return redirect.toString();
}
