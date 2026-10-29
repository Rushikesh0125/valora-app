export type Env = Omit<Cloudflare.Env, "APP_ENV" | "ALLOWED_ORIGINS" | "NEBIUS_API_KEY" | "AI_NEBIUS_MODEL" | "AI_DEFAULT_PROVIDER" | "AI_OPENAI_ROUTINE_MODEL" | "AI_OPENAI_COMPLEX_MODEL"> & {
  APP_ENV: string;
  ALLOWED_ORIGINS?: string;
  DEV_AUTH_ENABLED?: string;
  DEV_USER_ID?: string;
  JWT_ISSUER?: string;
  AUTH_SIGNING_PRIVATE_JWK?: string;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  GOOGLE_CALLBACK_URL?: string;
  OPENAI_CLIENT_ID?: string;
  OPENAI_CALLBACK_URL?: string;
  MOBILE_AUTH_REDIRECT_URI?: string;
  OPENAI_API_KEY?: string;
  GEMINI_API_KEY?: string;
  AI_DEFAULT_PROVIDER?: "openai" | "gemini" | "nebius";
  NEBIUS_API_KEY?: string;
  AI_NEBIUS_MODEL?: string;
  AI_OPENAI_ROUTINE_MODEL?: string;
  AI_OPENAI_COMPLEX_MODEL?: string;
  AI_GEMINI_ROUTINE_MODEL?: string;
  AI_GEMINI_COMPLEX_MODEL?: string;
}

export interface Principal {
  userId: string;
  role: "user" | "admin";
  authSubject: string;
  authProvider: string;
  email?: string;
}

export interface ApiContext {
  requestId: string;
  principal?: Principal;
}

export interface ProfileRecord {
  userId: string;
  goals: string[];
  eatingPattern: string;
  exclusions: string;
  allergies: string[];
  healthContext: string[];
  cuisines: string[];
  otherGoal: string;
  otherAllergy: string;
  otherHealth: string;
  otherCuisine: string;
  coverage: string;
  weeklyBudgetInr: number;
  cookingMinutes: number;
  planningTime: string;
  acknowledged: boolean;
  updatedAt: string;
}

export interface PreferencesRecord {
  userId: string;
  locale: string;
  currency: string;
  notificationsEnabled: boolean;
  notificationFrequency: string;
  notificationCategories: string[];
  quietStart: string;
  quietEnd: string;
  timeZone: string;
  updatedAt: string;
}

export interface MemoryFact {
  id: string;
  key: string;
  label: string;
  value: string;
  source: string;
  safetyRelevant: boolean;
  status: "active" | "paused";
  createdAt: string;
  updatedAt: string;
}
