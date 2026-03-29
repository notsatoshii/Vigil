import React from 'react';

function Stat({ value, label }) {
  return (
    <div className="text-center py-3 px-2 bg-vigil-surface rounded-md border border-vigil-border">
      <div className="text-xl font-bold text-sky-400 font-mono">{value ?? '-'}</div>
      <div className="text-[8px] text-slate-500 uppercase tracking-[1.5px] mt-1 font-semibold">{label}</div>
    </div>
  );
}

export default function StatsPanel({ sessions, knowledge, system }) {
  return (
    <section>
      <h2 className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold mb-2">Stats</h2>
      <div className="grid grid-cols-3 gap-2 mb-3">
        <Stat value={sessions?.today} label="Today" />
        <Stat value={knowledge?.sources} label="Sources" />
        <Stat value={knowledge?.entities} label="Entities" />
      </div>
      <div className="grid grid-cols-3 gap-2">
        <Stat value={system?.diskPct ? system.diskPct + '%' : '-'} label="Disk" />
        <Stat value={system?.cpuLoad || '-'} label="CPU" />
        <Stat value={system?.ramPct ? system.ramPct + '%' : '-'} label="RAM" />
      </div>
    </section>
  );
}
