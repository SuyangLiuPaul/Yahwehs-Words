// One recommended model for current clients; credentials remain BYOK only.
export const RECOMMENDED_GEMINI_MODEL = 'gemini-3.8-flash';

export async function callRecommendedGemini({apiKey, prompt, systemMessage,
  baseUrl, signal, json = false}) {
  const apiBase = baseUrl.replace(/\/openai\/?$/, '');
  const response = await fetch(`${apiBase}/models/${RECOMMENDED_GEMINI_MODEL}:generateContent`, {
    method: 'POST',
    headers: {'x-goog-api-key': apiKey, 'Content-Type': 'application/json'},
    body: JSON.stringify({
      systemInstruction: {parts: [{text: systemMessage}]},
      contents: [{role: 'user', parts: [{text: prompt}]}],
      generationConfig: {
        maxOutputTokens: 8192,
        thinkingConfig: {thinkingLevel: 'medium'},
        ...(json ? {responseMimeType: 'application/json'} : {}),
      },
    }),
    signal,
  });
  if (!response.ok) return response;
  const data = await response.json();
  const candidate = data.candidates?.[0];
  const content = (candidate?.content?.parts ?? [])
    .filter(part => part.thought !== true && typeof part.text === 'string')
    .map(part => part.text).join('');
  // Keep the existing answer/JSON validation and error handling at callers.
  return Response.json({choices: [{message: {content},
    finish_reason: candidate?.finishReason === 'MAX_TOKENS' ? 'length' : 'stop'}]});
}
