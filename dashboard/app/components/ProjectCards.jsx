import React from 'react';

export default function ProjectCards({ projects }) {
  const lever = projects?.lever || {};
  const landing = projects?.landing || {};

  return (
    <section>
      <h2 className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold mb-2">Projects</h2>
      <div className="space-y-1.5">
        <div className="flex justify-between items-center p-2 px-2.5 bg-vigil-surface rounded-md border border-vigil-border">
          <div>
            <div className="font-semibold text-xs text-slate-200">LEVER Protocol</div>
            <div className="text-[10px] text-slate-500 mt-0.5">{lever.bugsTotal || 12} audit items</div>
          </div>
          <span className="text-[8px] px-2 py-0.5 rounded-full font-bold tracking-wide bg-amber-500/10 text-amber-500 border border-amber-500/15">
            TESTNET
          </span>
        </div>
        <div className="flex justify-between items-center p-2 px-2.5 bg-vigil-surface rounded-md border border-vigil-border">
          <div>
            <div className="font-semibold text-xs text-slate-200">Landing Page</div>
            <div className="text-[10px] text-slate-500 mt-0.5">Redesign</div>
          </div>
          <span className="text-[8px] px-2 py-0.5 rounded-full font-bold tracking-wide bg-green-500/10 text-green-500 border border-green-500/15">
            ACTIVE
          </span>
        </div>
      </div>
    </section>
  );
}
