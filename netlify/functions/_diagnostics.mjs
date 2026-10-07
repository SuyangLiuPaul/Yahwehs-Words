// Whitelist only support metadata. Never spread a client diagnostic object.
export function sanitizeDiagnostics(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const result = {};
  if (typeof value.diagnosisId === 'string' && /^YD-[0-9a-f]{32}$/.test(value.diagnosisId)) result.diagnosisId = value.diagnosisId;
  for (const key of ['appVersion', 'platform', 'channel', 'app']) {
    if (typeof value[key] === 'string' && /^[a-zA-Z0-9_.-]{1,40}$/.test(value[key])) result[key] = value[key];
  }
  if (typeof value.idPersistent === 'boolean') result.idPersistent = value.idPersistent;
  const kinds = new Set(['update', 'companion', 'audio', 'report']);
  const results = new Set(['started', 'succeeded', 'failed', 'playing', 'paused', 'interrupted', 'available', 'upToDate', 'required', 'connected', 'disconnected']);
  if (Array.isArray(value.events)) result.events = value.events.slice(-20).flatMap(event => {
    if (!event || !kinds.has(event.kind) || !results.has(event.result) || typeof event.at !== 'string' || !/^\d{4}-\d{2}-\d{2}T[0-9:.]+Z$/.test(event.at) || event.at.length > 30) return [];
    return [{kind: event.kind, result: event.result, at: event.at}];
  });
  if (value.companions && typeof value.companions === 'object') {
    const peers = {};
    for (const platform of ['watchos', 'wearos']) {
      const id = value.companions[platform];
      if (typeof id === 'string' && /^YD-[0-9a-f]{32}$/.test(id)) peers[platform] = id;
    }
    if (Object.keys(peers).length) result.companions = peers;
  }
  return result;
}
