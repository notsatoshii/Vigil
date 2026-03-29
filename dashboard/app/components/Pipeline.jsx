import React from 'react';

const STAGES = [
  { key: 'PLAN', label: 'Plan', color: '#a78bfa', bg: 'rgba(167,139,250,0.08)', border: 'rgba(167,139,250,0.3)' },
  { key: 'CRITIQUE', label: 'Critique', color: '#f472b6', bg: 'rgba(244,114,182,0.08)', border: 'rgba(244,114,182,0.3)' },
  { key: 'BUILD', label: 'Build', color: '#38bdf8', bg: 'rgba(56,189,248,0.08)', border: 'rgba(56,189,248,0.3)' },
  { key: 'VERIFY', label: 'Verify', color: '#22c55e', bg: 'rgba(34,197,94,0.08)', border: 'rgba(34,197,94,0.3)' },
];

export default function Pipeline({ kanban }) {
  const counts = { PLAN: 0, CRITIQUE: 0, BUILD: 0, VERIFY: 0 };

  (kanban?.inProgress || []).forEach(t => {
    const u = t.toUpperCase();
    if (u.includes('PLAN')) counts.PLAN++;
    else if (u.includes('CRITIQU')) counts.CRITIQUE++;
    else if (u.includes('BUILD')) counts.BUILD++;
    else if (u.includes('VERIF')) counts.VERIFY++;
  });
  (kanban?.inReview || []).forEach(() => counts.VERIFY++);

  return (
    <section>
      <h2 className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold mb-3">Pipeline</h2>
      <div className="flex items-stretch gap-2">
        {STAGES.map((stage, i) => {
          const count = counts[stage.key];
          const active = count > 0;
          return (
            <React.Fragment key={stage.key}>
              {i > 0 && (
                <div className="flex items-center text-vigil-muted text-lg select-none">
                  <svg className={`w-4 h-4 ${active ? 'text-slate-400' : ''}`} fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M9 5l7 7-7 7" />
                  </svg>
                </div>
              )}
              <div
                className={`flex-1 rounded-lg border text-center py-4 px-2 transition-all duration-300 ${
                  active ? 'animate-glow' : ''
                }`}
                style={{
                  background: active ? stage.bg : '#0c1119',
                  borderColor: active ? stage.border : '#1a2332',
                  color: active ? stage.color : '#334155',
                }}
              >
                <div className="text-2xl sm:text-3xl font-bold font-mono leading-none mb-1">
                  {count}
                </div>
                <div className="text-[9px] sm:text-[10px] uppercase tracking-[1.5px] font-bold">
                  {stage.label}
                </div>
              </div>
            </React.Fragment>
          );
        })}
      </div>
    </section>
  );
}
