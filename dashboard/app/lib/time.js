export function ago(epoch) {
  if (!epoch) return '--';
  const s = Math.floor(Date.now() / 1000) - epoch;
  if (s < 0) return 'now';
  if (s < 60) return s + 's';
  if (s < 3600) return Math.floor(s / 60) + 'm';
  if (s < 86400) return Math.floor(s / 3600) + 'h';
  return Math.floor(s / 86400) + 'd';
}

export function countdown(targetStr) {
  if (!targetStr) return '--';
  const now = new Date();
  const parts = targetStr.match(/(\d+)h\s*(\d+)m/);
  if (parts) return targetStr;
  try {
    const target = new Date(targetStr);
    const diff = Math.floor((target - now) / 1000);
    if (diff <= 0) return 'now';
    const h = Math.floor(diff / 3600);
    const m = Math.floor((diff % 3600) / 60);
    const s = diff % 60;
    if (h > 0) return `${h}h ${m}m`;
    if (m > 0) return `${m}m ${s}s`;
    return `${s}s`;
  } catch {
    return targetStr;
  }
}
