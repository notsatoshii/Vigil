import React from 'react';

const SVC_NAMES = {
  frontend: 'FE :3000', oracle: 'Oracle', accrue: 'Accrue', gateway: 'GW :18789',
  inbox: 'Inbox', telegram: 'TG Bot', dashboard: 'Dash :8080', caddy: 'Caddy :80'
};

export default function ServiceGrid({ services }) {
  if (!services) return null;

  return (
    <section>
      <h2 className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold mb-2">Services</h2>
      <div className="flex flex-wrap gap-1">
        {Object.entries(services).map(([key, up]) => (
          <div
            key={key}
            className={`text-[10px] px-2 py-1 rounded flex items-center gap-1.5 bg-vigil-surface border ${
              up ? 'border-vigil-border' : 'border-red-500/30'
            }`}
          >
            <span className={`w-1 h-1 rounded-full ${
              up ? 'bg-green-500' : 'bg-red-500 animate-breathe'
            }`} />
            <span className={up ? 'text-slate-400' : 'text-red-400 font-semibold'}>{SVC_NAMES[key] || key}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
