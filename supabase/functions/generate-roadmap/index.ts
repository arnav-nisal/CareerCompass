// Edge Function to generate a career roadmap with model fallback and backoff retries.

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
      },
    });
  }

  const corsJson = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
  };

  try {
    if (req.method !== 'POST') {
      return new Response(JSON.stringify({ error: 'Only POST is supported.' }), {
        status: 405,
        headers: { ...corsJson, 'Allow': 'POST, OPTIONS' },
      });
    }

    // Body: { prompt: string, requestedModel?: string }
    const bodyJson = await req.json().catch(() => null);
    const prompt = bodyJson?.prompt;
    const requestedModel = typeof bodyJson?.requestedModel === 'string' ? String(bodyJson.requestedModel) : undefined;

    if (!prompt || typeof prompt !== 'string') {
      return new Response(JSON.stringify({ error: 'Missing or invalid prompt in body.' }), {
        status: 400,
        headers: corsJson,
      });
    }

    const apiKey = Deno.env.get('GEMINI_API_KEY') || Deno.env.get('GEMINIAPIKEY');
    if (!apiKey) {
      return new Response(JSON.stringify({ error: 'GEMINI_API_KEY not set in environment.' }), {
        status: 500,
        headers: corsJson,
      });
    }

    const priority = requestedModel
      ? [requestedModel]
      : [
          'gemini-2.5-flash',
          'gemini-2.5-pro',
          'gemini-2.0-flash',
          'gemini-2.0-flash-lite',
        ];

    const requestBody = {
      contents: [{ role: 'user', parts: [{ text: prompt }] }],
    };

    let lastErr = '';
    for (const model of priority) {
      try {
        const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
        const data = await callWithRetries(url, requestBody);

        const text =
          data?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text ?? '').join('') ??
          data?.candidates?.[0]?.content?.parts?.[0]?.text ??
          '';

        if (typeof text === 'string' && text.trim().length > 0) {
          return new Response(JSON.stringify(text), { status: 200, headers: corsJson });
        }

        lastErr = `Empty response from ${model}`;
      } catch (e) {
        lastErr = `${model}: ${String(e)}`;
        continue;
      }
    }

    return new Response(
      JSON.stringify({ error: { code: 503, message: 'MODEL_OVERLOADED', details: lastErr } }),
      { status: 503, headers: corsJson },
    );
  } catch (e) {
    return new Response(
      JSON.stringify({ error: { code: 500, message: String(e) } }),
      { status: 500, headers: corsJson },
    );
  }
});

async function callWithRetries(url: string, body: unknown) {
  const maxAttempts = 3;
  let attempt = 0;
  let last = '';

  while (attempt < maxAttempts) {
    attempt++;
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });

    if (res.ok) {
      return await res.json();
    }

    const status = res.status;
    const text = await res.text().catch(() => '');
    last = `${status} ${text}`;

    if ([429, 500, 502, 503, 504].includes(status)) {
      const delayMs = Math.pow(2, attempt) * 400; // 800, 1600, 3200
      await new Promise((r) => setTimeout(r, delayMs));
      continue;
    }

    throw new Error(`Gemini API error: ${last}`);
  }

  throw new Error(`Gemini API error after retries: ${last}`);
}
