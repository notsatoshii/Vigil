import React, { useState } from 'react';
import { wsColors } from '../lib/colors';

export default function KanbanCard({ item, pulse }) {
  const [expanded, setExpanded] = useState(false);

  const parts = item.split('|||');
  const title = parts[0].trim();
  const detail = parts[1] ? parts[1].trim() : title;
  const short = title.length > 60 ? title.substring(0, 60) + '...' : title;

  // Extract workstream for color
  const match = title.match(/^(?:\[[\w-]+\]\s*)?(?:PLAN|CRITIQUE|BUILD|VERIFY|IMPROVE|OPERATE|RESEARCH|SECURE|CEO|ADVISOR)/i);
  const ws = match ? match[0].replace(/\[.*?\]\s*/, '').toUpperCase() : null;
  const borderColor = ws ? (wsColors[ws] || '#1a2332') : '#1a2332';

  return (
    <div
      onClick={() => setExpanded(!expanded)}
      className={`text-[10px] p-1.5 px-2 rounded cursor-pointer mb-1 leading-snug break-words transition-all duration-200 ${
        pulse ? 'animate-breathe' : ''
      }`}
      style={{
        background: '#0c1119',
        borderLeft: `3px solid ${borderColor}`,
      }}
    >
      <div className="font-semibold text-slate-300">{short}</div>
      {expanded && detail !== title && (
        <div className="mt-1.5 pt-1.5 border-t border-vigil-border text-[9px] text-slate-400 leading-relaxed animate-fade-in">
          {detail}
        </div>
      )}
    </div>
  );
}
