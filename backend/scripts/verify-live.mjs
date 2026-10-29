// Uses a signed-in user's token and existing consent; never enables consent itself.
const base = process.env.VALORA_API_URL;
const token = process.env.VALORA_ACCESS_TOKEN;
if (!base || !token) throw new Error('Set VALORA_API_URL and VALORA_ACCESS_TOKEN for a signed-in Nebius test user.');
const url = new URL(base);
if (url.protocol !== 'https:' || !url.hostname.startsWith('valora-nebius-api.')) throw new Error('Only the isolated Nebius Worker is accepted.');
const headers = { authorization: `Bearer ${token}`, 'content-type':'application/json' };
const consent = await fetch(new URL('/v1/ai/consent',url),{headers,signal:AbortSignal.timeout(15000)});
if (!consent.ok || (await consent.json()).data?.enabled !== true) throw new Error('Sign in and enable Nebius consent in the app before verification.');
const started = performance.now();
const response = await fetch(new URL('/v1/ai/respond',url),{
  method:'POST', headers, signal:AbortSignal.timeout(60000),
  body:JSON.stringify({task:'conversation',complexity:'routine',prompt:'Suggest one simple vegetarian lunch. This is synthetic test data.'}),
});
if (!response.ok) throw new Error(`Live verification failed with HTTP ${response.status}; inspect sanitized app errors.`);
const {data} = await response.json();
if (data?.provider !== 'nebius' || !data.model?.startsWith('nvidia/') || typeof data.text !== 'string' || !data.text.trim()) throw new Error('Expected a real NVIDIA response from Nebius.');
console.log(JSON.stringify({provider:data.provider,model:data.model,elapsedMs:Math.round(performance.now()-started),usage:data.usage,completed:true}));
