import React from 'react';

export default function ContextDrawer({ open, onClose, children }) {
  return (
    <>
      {/* Desktop: always visible sidebar */}
      <aside className="hidden lg:block w-[320px] p-4 space-y-5 overflow-y-auto max-h-[calc(100vh-45px)] sticky top-[45px]">
        {children}
      </aside>

      {/* Mobile: slide-in drawer */}
      {open && (
        <>
          <div className="lg:hidden fixed inset-0 bg-black/60 z-40" onClick={onClose} />
          <aside className="lg:hidden fixed right-0 top-0 bottom-0 w-[300px] bg-vigil-bg border-l border-vigil-border z-50 p-4 space-y-5 overflow-y-auto animate-slide-in">
            <div className="flex justify-between items-center mb-2">
              <span className="text-[10px] uppercase tracking-[2px] text-slate-500 font-bold">Context</span>
              <button onClick={onClose} className="text-slate-400 hover:text-slate-200 p-1">
                <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              </button>
            </div>
            {children}
          </aside>
        </>
      )}
    </>
  );
}
