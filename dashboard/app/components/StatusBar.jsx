import React, { useState, useEffect } from 'react';
import { ago } from '../lib/time';
import { wsColors, allWorkstreams } from '../lib/colors';

export default function StatusBar({ data, connected, onToggleDrawer }) {
  const [, setTick] = useState(0);

  // Update "ago" display every second
  useEffect(() => {
    const id = setInterval(() => setTick(t => t + 1), 1000);
    return () => clearInterval(id);
  }, []);

  const sys = data.system || {};
  const activeWs = (data.kanban?.inProgress || []).map(s => s.toUpperCase());

  const orbClass = sys.health === 'healthy' ? 'bg-green-500 shadow-[0_0_10px_rgba(34,197,94,0.3)]'
    : sys.ramPct > 85 ? 'bg-red-500 shadow-[0_0_10px_rgba(239,68,68,0.4)]'
    : 'bg-amber-500 shadow-[0_0_10px_rgba(245,158,11,0.3)]';

  return (
    <header className="sticky top-0 z-50 bg-vigil-surface/92 backdrop-blur-xl border-b border-vigil-border px-4 py-2.5 flex items-center justify-between">
      <div className="flex items-center gap-3.5">
        <span className={`w-2 h-2 rounded-full animate-breathe ${orbClass}`} />
        <span className="text-xs tracking-[4px] font-bold text-sky-400">VIGIL</span>
        <div className="hidden sm:flex gap-1">
          {allWorkstreams.map(w => {
            const isActive = activeWs.some(a => a.includes(w));
            return (
              <span
                key={w}
                className={`w-1.5 h-1.5 rounded-full ${isActive ? 'animate-breathe opacity-100' : 'opacity-30'}`}
                style={{ background: wsColors[w] }}
                title={w}
              />
            );
          })}
        </div>
      </div>
      <div className="flex gap-3 sm:gap-4 items-center text-[11px] text-slate-500">
        <div className="flex items-center gap-1">
          Active: <span className="font-mono font-semibold text-slate-200">{data.sessions?.active ?? '-'}</span>
        </div>
        <div className="flex items-center gap-1">
          RAM: <span className="font-mono font-semibold text-slate-200">{sys.ramPct ?? '-'}%</span>
        </div>
        <span className={`w-1.5 h-1.5 rounded-full ${connected ? 'bg-green-500 shadow-[0_0_6px_rgba(34,197,94,0.3)]' : 'bg-red-500 shadow-[0_0_6px_rgba(239,68,68,0.3)]'}`} />
        <span className="font-mono text-[10px] text-vigil-muted">{ago(data.epoch)}</span>
        <button onClick={onToggleDrawer} className="lg:hidden p-1 text-slate-400 hover:text-slate-200">
          <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
          </svg>
        </button>
      </div>
    </header>
  );
}
