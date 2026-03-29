import React from 'react';
import KanbanCard from './KanbanCard';

const COLUMNS = [
  { key: 'backlog', title: 'Backlog', accent: '#1a2332' },
  { key: 'planned', title: 'Planned', accent: '#a78bfa' },
  { key: 'inProgress', title: 'In Progress', accent: '#38bdf8' },
  { key: 'inReview', title: 'In Review', accent: '#f59e0b' },
  { key: 'done', title: 'Done', accent: '#22c55e' },
];

function Column({ title, items, accent, pulse }) {
  return (
    <div className="bg-vigil-surface rounded-lg p-2 min-h-[80px]">
      <div className="text-[8px] uppercase tracking-[1.5px] text-slate-500 font-bold text-center mb-2">
        {title}{' '}
        <span className="text-sky-400">({items?.length || 0})</span>
      </div>
      {items && items.length > 0 ? (
        items.map((item, i) => <KanbanCard key={i} item={item} pulse={pulse} />)
      ) : (
        <div className="text-[9px] text-vigil-muted text-center py-2 opacity-30">&middot;</div>
      )}
    </div>
  );
}

export default function KanbanBoard({ kanban }) {
  const kb = kanban || {};

  return (
    <section>
      <h2 className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold mb-3">Task Board</h2>

      {/* Main columns: horizontal scroll on mobile, grid on desktop */}
      <div className="flex lg:grid lg:grid-cols-5 gap-1.5 overflow-x-auto pb-2 snap-x">
        {COLUMNS.map(col => (
          <div key={col.key} className="min-w-[160px] lg:min-w-0 snap-start">
            <Column
              title={col.title}
              items={kb[col.key]}
              accent={col.accent}
              pulse={col.key === 'inProgress'}
            />
          </div>
        ))}
      </div>

      {/* Blocked section: full width, red accent */}
      {kb.blocked && kb.blocked.length > 0 && (
        <div className="mt-2 bg-vigil-surface rounded-lg p-2 border border-red-500/20">
          <div className="text-[8px] uppercase tracking-[1.5px] text-red-400 font-bold mb-2">
            Blocked <span className="text-red-500">({kb.blocked.length})</span>
          </div>
          {kb.blocked.map((item, i) => (
            <KanbanCard key={i} item={item} />
          ))}
        </div>
      )}
    </section>
  );
}
