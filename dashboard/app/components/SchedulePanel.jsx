import React, { useState, useEffect } from 'react';

export default function SchedulePanel({ upcoming }) {
  const [, setTick] = useState(0);

  // Tick every second for countdown updates
  useEffect(() => {
    const id = setInterval(() => setTick(t => t + 1), 1000);
    return () => clearInterval(id);
  }, []);

  if (!upcoming || upcoming.length === 0) {
    return (
      <section>
        <h2 className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold mb-2">Scheduled</h2>
        <div className="text-[11px] text-slate-600">No scheduled jobs</div>
      </section>
    );
  }

  return (
    <section>
      <h2 className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold mb-2">Scheduled</h2>
      <div className="text-[11px]">
        {upcoming.map((job, i) => (
          <div key={i} className="flex justify-between py-1.5 border-b border-vigil-border last:border-b-0">
            <span className="text-slate-400">{job.name.replace(/-/g, ' ')}</span>
            <span className="text-sky-400 font-mono text-[10px]">{job.next}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
