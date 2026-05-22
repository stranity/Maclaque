interface Env {
  KV: KVNamespace;
  ELEVENLABS_API_KEY: string;
  APP_SECRET: string;
}

const ALLOWED_VOICES = new Set([
  "IKne3meq5aSn9XLyUdCD", // Charlie
  "N2lVS1w4EtoT3dr4eOWO", // Callum
  "pFZP5JQG7iQjIQuC4Bku", // Lily
  "TX3LPaxmHKxFdv7VOQHJ", // Liam
  "XB0fDUnXU5powFXDhCwa", // Charlotte
]);

const MAX_GENERATIONS_PER_DEVICE = 15;
const MAX_TEXT_LENGTH = 200;

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const url = new URL(request.url);
    if (request.method !== "POST" || url.pathname !== "/v1/generate") {
      return new Response("Not Found", { status: 404 });
    }

    // Validate app secret
    const appSecret = request.headers.get("X-App-Secret");
    if (!appSecret || appSecret !== env.APP_SECRET) {
      return json({ error: "Unauthorized" }, 401);
    }

    // Device UUID for generation tracking
    const deviceId = request.headers.get("X-Device-Id");
    if (!deviceId || deviceId.length < 10) {
      return json({ error: "Missing device identifier" }, 400);
    }

    // Check generation counter per device
    const counterKey = `gens:${deviceId}`;
    const currentCount = parseInt((await env.KV.get(counterKey)) || "0", 10);
    if (currentCount >= MAX_GENERATIONS_PER_DEVICE) {
      return json(
        { error: `Generation limit reached (${MAX_GENERATIONS_PER_DEVICE})` },
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
      return json(
        { error: `ElevenLabs error: ${ttsResponse.status}` },
        502
      );
    }

    // Increment counter
    await env.KV.put(counterKey, String(currentCount + 1));

    return new Response(ttsResponse.body, {
      status: 200,
      headers: {
        "Content-Type": "audio/mpeg",
        "X-Generations-Remaining": String(
          MAX_GENERATIONS_PER_DEVICE - currentCount - 1
        ),
      },
    });
  },
};

function json(data: object, status: number): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
