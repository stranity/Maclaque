interface Env {
  KV: KVNamespace;
  ELEVENLABS_API_KEY: string;
  APP_SECRET: string;
}

// ── Preset voices (available to everyone) ─────────────────────────────
const PRESET_VOICES = new Set([
  "IKne3meq5aSn9XLyUdCD", // Charlie
  "N2lVS1w4EtoT3dr4eOWO", // Callum
  "pFZP5JQG7iQjIQuC4Bku", // Lily
  "TX3LPaxmHKxFdv7VOQHJ", // Liam
  "XB0fDUnXU5powFXDhCwa", // Charlotte
]);

// ── Limits ─────────────────────────────────────────────────────────────
const MAX_TEXT_LENGTH = 200;
const DAILY_GENERATION_LIMIT = 30;          // Anti-abuse, per device per day
const DAILY_IP_LIMIT = 60;                  // Anti-abuse, per IP per day
const MAX_VOICE_FILE_SIZE = 10 * 1024 * 1024; // 10MB

// Tier limits for voice cloning
const TIER_LIMITS: Record<string, { clones: number; packs: number }> = {
  free:  { clones: 0, packs: 0 },
  basic: { clones: 3, packs: 3 },
  plus:  { clones: 10, packs: 10 },
};

// ── Router ─────────────────────────────────────────────────────────────
export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method !== "POST") {
      return new Response("Not Found", { status: 404 });
    }

    // Validate app secret
    const appSecret = request.headers.get("X-App-Secret");
    if (!appSecret || appSecret !== env.APP_SECRET) {
      return json({ error: "Unauthorized" }, 401);
    }

    // Device UUID
    const deviceId = request.headers.get("X-Device-Id");
    if (!deviceId || deviceId.length < 10) {
      return json({ error: "Missing device identifier" }, 400);
    }

    const url = new URL(request.url);
    switch (url.pathname) {
      case "/v1/generate":
        return handleGenerate(request, env, deviceId);
      case "/v1/voices/clone":
        return handleVoiceClone(request, env, deviceId);
      case "/v1/voices/list":
        return handleVoiceList(env, deviceId);
      case "/v1/tier/activate":
        return handleTierActivate(request, env, deviceId);
      default:
        return new Response("Not Found", { status: 404 });
    }
  },
};

// ── TTS Generation (unlimited, daily rate limit) ──────────────────────
async function handleGenerate(
  request: Request,
  env: Env,
  deviceId: string
): Promise<Response> {
  // Daily rate limit per device
  const today = new Date().toISOString().slice(0, 10);
  const dayKey = `day:${deviceId}:${today}`;
  const dayCount = parseInt((await env.KV.get(dayKey)) || "0", 10);
  if (dayCount >= DAILY_GENERATION_LIMIT) {
    return json({ error: "Limite journalière atteinte (30/jour). Réessaie demain !" }, 429);
  }

  // Daily rate limit per IP
  const clientIP = request.headers.get("CF-Connecting-IP") || "unknown";
  const ipKey = `ip:${clientIP}:${today}`;
  const ipCount = parseInt((await env.KV.get(ipKey)) || "0", 10);
  if (ipCount >= DAILY_IP_LIMIT) {
    return json({ error: "Daily limit reached" }, 429);
  }

  // Parse body
  let body: { text?: string; voice_id?: string };
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { text, voice_id } = body;

  if (!text || typeof text !== "string" || text.length === 0) {
    return json({ error: "Missing or empty text" }, 400);
  }
  if (text.length > MAX_TEXT_LENGTH) {
    return json({ error: `Text too long (max ${MAX_TEXT_LENGTH} characters)` }, 400);
  }

  // Validate voice_id: must be a preset voice OR a cloned voice owned by this device
  if (!voice_id) {
    return json({ error: "Missing voice_id" }, 400);
  }
  if (!PRESET_VOICES.has(voice_id)) {
    // Check if it's a cloned voice belonging to this device
    const clonedVoices = await getClonedVoices(env, deviceId);
    if (!clonedVoices.some((v) => v.voiceId === voice_id)) {
      return json({ error: "Invalid voice_id" }, 400);
    }
  }

  // Forward to ElevenLabs TTS
  const elevenLabsURL = `https://api.elevenlabs.io/v1/text-to-speech/${voice_id}`;
  const ttsResponse = await fetch(elevenLabsURL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "xi-api-key": env.ELEVENLABS_API_KEY,
    },
    body: JSON.stringify({
      text,
      model_id: "eleven_multilingual_v2",
      voice_settings: {
        stability: 0.35,
        similarity_boost: 0.75,
        style: 0.6,
        use_speaker_boost: true,
      },
    }),
  });

  if (!ttsResponse.ok) {
    return json({ error: `ElevenLabs error: ${ttsResponse.status}` }, 502);
  }

  // Increment daily counters
  await env.KV.put(dayKey, String(dayCount + 1), { expirationTtl: 86400 });
  await env.KV.put(ipKey, String(ipCount + 1), { expirationTtl: 86400 });

  return new Response(ttsResponse.body, {
    status: 200,
    headers: {
      "Content-Type": "audio/mpeg",
      "X-Daily-Remaining": String(DAILY_GENERATION_LIMIT - dayCount - 1),
    },
  });
}

// ── Voice Cloning ─────────────────────────────────────────────────────
async function handleVoiceClone(
  request: Request,
  env: Env,
  deviceId: string
): Promise<Response> {
  const tier = await getDeviceTier(env, deviceId);
  const limits = TIER_LIMITS[tier];
  const clonedVoices = await getClonedVoices(env, deviceId);

  if (clonedVoices.length >= limits.clones) {
    return json({
      error: `Limite de voix atteinte (${limits.clones}). ${tier === "basic" ? "Passe à Maclaque+ pour 10 voix." : ""}`,
      upgrade: tier === "basic",
    }, 429);
  }

  // Parse multipart form data
  const formData = await request.formData();
  const name = formData.get("name") as string | null;
  const audioFile = formData.get("audio") as File | null;

  if (!name || name.length === 0 || name.length > 50) {
    return json({ error: "Nom de voix invalide (1-50 caractères)" }, 400);
  }
  if (!audioFile) {
    return json({ error: "Fichier audio manquant" }, 400);
  }
  if (audioFile.size > MAX_VOICE_FILE_SIZE) {
    return json({ error: "Fichier trop gros (max 10MB)" }, 400);
  }

  // Forward to ElevenLabs Instant Voice Clone
  const elevenForm = new FormData();
  elevenForm.append("name", `maclaque_${deviceId.slice(0, 8)}_${name}`);
  elevenForm.append("files", audioFile);
  elevenForm.append("description", `Maclaque custom voice: ${name}`);

  const cloneResponse = await fetch("https://api.elevenlabs.io/v1/voices/add", {
    method: "POST",
    headers: {
      "xi-api-key": env.ELEVENLABS_API_KEY,
    },
    body: elevenForm,
  });

  if (!cloneResponse.ok) {
    const errText = await cloneResponse.text();
    return json({ error: `Erreur de clonage: ${cloneResponse.status} — ${errText}` }, 502);
  }

  const cloneResult = (await cloneResponse.json()) as { voice_id: string };
  const newVoiceId = cloneResult.voice_id;

  // Store cloned voice for this device
  clonedVoices.push({ voiceId: newVoiceId, name, createdAt: new Date().toISOString() });
  await env.KV.put(`clones:${deviceId}`, JSON.stringify(clonedVoices));

  return json({
    voice_id: newVoiceId,
    name,
    clones_remaining: limits.clones - clonedVoices.length,
  }, 200);
}

// ── List cloned voices ────────────────────────────────────────────────
async function handleVoiceList(
  env: Env,
  deviceId: string
): Promise<Response> {
  const tier = await getDeviceTier(env, deviceId);
  const limits = TIER_LIMITS[tier];
  const clonedVoices = await getClonedVoices(env, deviceId);

  return json({
    tier,
    clones: clonedVoices,
    clones_limit: limits.clones,
    clones_remaining: limits.clones - clonedVoices.length,
    packs_limit: limits.packs,
  }, 200);
}

// ── Tier activation (Maclaque+) ───────────────────────────────────────
async function handleTierActivate(
  request: Request,
  env: Env,
  deviceId: string
): Promise<Response> {
  let body: { code?: string };
  try {
    body = await request.json();
  } catch {
    return json({ error: "Invalid JSON body" }, 400);
  }

  const { code } = body;
  if (!code || typeof code !== "string") {
    return json({ error: "Code manquant" }, 400);
  }

  // Check code in KV (format: activation codes stored as "code:{code}" → "unused")
  const codeKey = `code:${code}`;
  const codeStatus = await env.KV.get(codeKey);

  if (!codeStatus) {
    return json({ error: "Code invalide" }, 400);
  }
  if (codeStatus !== "unused") {
    return json({ error: "Code déjà utilisé" }, 400);
  }

  // Activate Plus tier for this device
  await env.KV.put(`tier:${deviceId}`, "plus");
  await env.KV.put(codeKey, `used:${deviceId}:${new Date().toISOString()}`);

  return json({ tier: "plus", message: "Maclaque+ activé !" }, 200);
}

// ── Helpers ────────────────────────────────────────────────────────────
interface ClonedVoice {
  voiceId: string;
  name: string;
  createdAt: string;
}

async function getDeviceTier(env: Env, deviceId: string): Promise<string> {
  return (await env.KV.get(`tier:${deviceId}`)) || "free";
}

async function getClonedVoices(env: Env, deviceId: string): Promise<ClonedVoice[]> {
  const raw = await env.KV.get(`clones:${deviceId}`);
  if (!raw) return [];
  try {
    return JSON.parse(raw) as ClonedVoice[];
  } catch {
    return [];
  }
}

function json(data: object, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
