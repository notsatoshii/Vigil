import React from 'react';

export default function AttentionPanel({ sessions }) {
  const items = [];

  if (sessions?.pendingApprovals > 0) {
    items.push({
      title: `${sessions.pendingApprovals} pending approval(s)`,
      sub: 'Review and act via Telegram',
      cmd: '/approve N',
      critical: false,
    });
  }
  if (sessions?.deadLetters > 0) {
    items.push({
      title: `${sessions.deadLetters} failed message(s)`,
      sub: 'OPERATE will retry automatically',
      cmd: '',
      critical: true,
    });
  }
  if (sessions?.gatewayErrors > 3) {
    items.push({
      title: `${sessions.gatewayErrors} gateway errors today`,
      sub: 'Check telegram-gateway.log',
      cmd: '/status',
      critical: false,
    });
  }

  if (items.length === 0) return null;

  const hasCritical = items.some(i => i.critical);

  return (
    <section className={`rounded-lg p-3 border ${
      hasCritical
        ? 'border-red-500/40 bg-red-500/5 shadow-[0_0_20px_rgba(239,68,68,0.1)] animate-pulse-fast'
        : 'border-amber-500/30 bg-amber-500/5'
    }`}>
      <h2 className="text-[10px] uppercase tracking-[2px] text-amber-400 font-bold mb-2 flex items-center gap-2">
        Needs Attention
        <span className="bg-vigil-muted text-slate-200 text-[9px] px-1.5 py-px rounded-full font-semibold">
          {items.length}
        </span>
      </h2>
      <div className="space-y-2">
        {items.map((item, i) => (
          <div
            key={i}
            className={`p-2.5 px-3 bg-vigil-surface rounded-md ${
              item.critical ? 'border-l-[3px] border-red-500' : 'border-l-[3px] border-amber-500'
            }`}
          >
            <div className="text-xs font-semibold text-slate-200">{item.title}</div>
            <div className="text-[10px] text-slate-500 mt-0.5">
              {item.sub}
              {item.cmd && (
                <span className="ml-1 font-mono text-sky-400 bg-sky-400/8 px-1 py-px rounded text-[10px]">
                  {item.cmd}
                </span>
              )}
            </div>
          </div>
        ))}
      </div>
    </section>
  );
}
