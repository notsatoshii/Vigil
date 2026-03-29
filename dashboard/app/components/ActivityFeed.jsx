import React, { useState, useEffect } from 'react';
import { ago } from '../lib/time';
import { wsColors } from '../lib/colors';

export default function ActivityFeed({ activity }) {
  const [, setTick] = useState(0);

  useEffect(() => {
    const id = setInterval(() => setTick(t => t + 1), 5000);
    return () => clearInterval(id);
  }, []);

  const entries = [];

  // Add handoffs
  if (activity?.handoffs) {
    activity.handoffs.forEach(h => {
      const ws = h.name.split('-')[0].toUpperCase();
      const validWs = ['PLAN', 'BUILD', 'VERIFY', 'OPERATE', 'CRITIQUE', 'RESEARCH', 'SECURE', 'CEO', 'ADVISOR', 'IMPROVE'];
      entries.push({
        time: h.time,
        ws: validWs.includes(ws) ? ws : 'HANDOFF',
        text: h.name.replace(/-/g, ' ') + (h.summary ? ' : ' + h.summary : ''),
        done: true,
      });
    });
  }

  // Add sessions
  if (activity?.sessions) {
    activity.sessions.forEach(s => {
      const parts = s.split('|');
      const timeStr = parts[0]?.trim().replace(/[\[\]]/g, '') || '';
      const rest = parts.slice(1).join('|').trim();
      const ws = rest.split(' ')[0] || 'SYSTEM';
      const desc = rest.substring(ws.length).trim();
      let epoch = 0;
      try { epoch = Math.floor(new Date(timeStr).getTime() / 1000); } catch {}
      entries.push({ time: epoch, ws, text: desc, done: true });
    });
  }

  entries.sort((a, b) => b.time - a.time);
  const visible = entries.slice(0, 15);

  return (
    <section>
      <h2 className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold mb-3">Activity</h2>
      <ul className="space-y-0">
        {visible.length > 0 ? visible.map((e, i) => (
          <li key={i} className="flex gap-3 py-2.5 border-b border-vigil-border/50 last:border-b-0 animate-fade-in">
            <span className="text-[10px] text-slate-500 min-w-[40px] font-mono pt-0.5">{ago(e.time)}</span>
            <span
              className="text-[9px] font-bold tracking-wide uppercase min-w-[65px] pt-0.5"
              style={{ color: wsColors[e.ws] || '#64748b' }}
            >
              {e.ws}
            </span>
            <span className="flex-1 text-[13px] leading-relaxed text-slate-300">{e.text}</span>
            <span className="text-[11px] pt-0.5 text-green-500">{e.done ? '\u2713' : ''}</span>
          </li>
        )) : (
          <li className="text-[13px] text-slate-600 py-2">No activity yet.</li>
        )}
      </ul>
    </section>
  );
}
