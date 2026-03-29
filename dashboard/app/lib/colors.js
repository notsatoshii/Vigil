export const wsColors = {
  PLAN: '#a78bfa', CRITIQUE: '#f472b6', BUILD: '#38bdf8', VERIFY: '#22c55e',
  RESEARCH: '#fbbf24', OPERATE: '#94a3b8', SECURE: '#ef4444', CEO: '#e2e8f0',
  ADVISOR: '#c084fc', IMPROVE: '#2dd4bf', COMMANDER: '#38bdf8', TELEGRAM: '#64748b',
  MIGRATION: '#64748b', HANDOFF: '#94a3b8'
};

export const allWorkstreams = [
  'PLAN', 'CRITIQUE', 'BUILD', 'VERIFY', 'SECURE',
  'RESEARCH', 'OPERATE', 'CEO', 'ADVISOR', 'IMPROVE'
];

export function getWorkstreamFromText(text) {
  const match = text.match(/^(PLAN|CRITIQUE|BUILD|VERIFY|IMPROVE|OPERATE|RESEARCH|SECURE|CEO|ADVISOR)[\s:]/i);
  return match ? match[1].toUpperCase() : null;
}
