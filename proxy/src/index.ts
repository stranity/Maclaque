interface Env {
  KV: KVNamespace;
  ELEVENLABS_API_KEY: string;
  LEMONSQUEEZY_API_KEY: string;
}

const ALLOWED_VOICES = new Set([
  "IKne3meq5aSn9XLyUdCD", // Charlie
  "N2lVS1w4EtoT3dr4eOWO", // Callum
  "pFZP5JQG7iQjIQuC4Bku", // Lily
  "TX3LPaxmHKxFdv7VOQHJ", // Liam
  "XB0fDUnXU5powFXDhCwa", // Charlotte
]);

const MAX_GENERATIONS = 15;
const MAX_TEXT_LENGTH = 200;
const LICENSE_CACHE_TTL = 86400; // 24h

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    // Only POST /v1/generate
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/v1/generate") {
      return new Response("Not Found", { status: 404 });
    }

    // Extract license key
    const licenseKey = request.headers.get("X-License-Key");
    if (!licenseKey) {
      return json({ error: "Missing license key" }, 401);
    }

    // Validate license (cached in KV)
    const isValid = await validateLicense(licenseKey, env);
    if (!isValid) {
      return json({ error: "Invalid or inactive license" }, 403);
    }

    // Check generation counter
    const counterKey = `gens:${licenseKey}`;
    const currentCount = parseInt((await env.KV.get(counterKey)) || "0", 10);
    if (currentCount >= MAX_GENERATIONS) {
      return json(
        { error: `Generation limit reached (${MAX_GENERATIONS})` },
        429
      );
    }

    // Parse and validate body
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
      return json(
        { error: `Text too long (max ${MAX_TEXT_LENGTH} characters)` },
        400
      );
    }
    if (!voice_id || !ALLOWED_VOICES.has(voice_id)) {
      return json({ error: "Invalid voice_id" }, 400);
    }

    // Forward to ElevenLabs
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
      const errBody = await ttsResponse.text();
      return json(
        { error: `ElevenLabs error: ${ttsResponse.status}` },
        502
      );
    }

    // Increment counter (no expiration — lifetime limit)
    await env.KV.put(counterKey, String(currentCount + 1));

    // Return raw MP3
    return new Response(ttsResponse.body, {
      status: 200,
      headers: {
        "Content-Type": "audio/mpeg",
        "X-Generations-Remaining": String(
          MAX_GENERATIONS - currentCount - 1
        ),
      },
    });
  },
};

async function validateLicense(
  licenseKey: string,
  env: Env
): Promise<boolean> {
  // Check KV cache first
  const cacheKey = `license:${licenseKey}`;
  const cached = await env.KV.get(cacheKey);
  if (cached === "valid") return true;
  if (cached === "invalid") return false;

  // Validate via LemonSqueezy API
  try {
    const response = await fetch(
      "https://api.lemonsqueezy.com/v1/licenses/validate",
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          license_key: licenseKey,
          instance_name: "maclaque-proxy",
        }),
      }
    );

    if (!response.ok) {
      await env.KV.put(cacheKey, "invalid", {
        expirationTtl: LICENSE_CACHE_TTL,
      });
      return false;
    }

    const data = (await response.json()) as { valid?: boolean };
    const valid = data.valid === true;

    await env.KV.put(cacheKey, valid ? "valid" : "invalid", {
      expirationTtl: LICENSE_CACHE_TTL,
    });

    return valid;
  } catch {
    // On network error, deny access
    return false;
  }
}

function json(data: object, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
