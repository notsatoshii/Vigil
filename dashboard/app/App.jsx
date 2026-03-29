import React, { useState } from 'react';
import { useVigilSocket } from './hooks/useVigilSocket';
import StatusBar from './components/StatusBar';
import Pipeline from './components/Pipeline';
import AttentionPanel from './components/AttentionPanel';
import KanbanBoard from './components/KanbanBoard';
import ActivityFeed from './components/ActivityFeed';
import ServiceGrid from './components/ServiceGrid';
import StatsPanel from './components/StatsPanel';
import ProjectCards from './components/ProjectCards';
import SchedulePanel from './components/SchedulePanel';
import ContextDrawer from './components/ContextDrawer';

function LoadingScreen() {
  return (
    <div className="min-h-screen bg-vigil-bg flex items-center justify-center">
      <div className="text-center">
        <div className="w-3 h-3 rounded-full bg-sky-400 animate-breathe mx-auto mb-4" />
        <div className="text-xs tracking-[4px] font-bold text-sky-400 mb-2">VIGIL</div>
        <div className="text-[10px] text-slate-500">Connecting...</div>
      </div>
    </div>
  );
}

export default function App() {
  const { data, connected } = useVigilSocket();
  const [drawerOpen, setDrawerOpen] = useState(false);

  if (!data) return <LoadingScreen />;

  const contextPanel = (
    <>
      <ServiceGrid services={data.services} />
      <StatsPanel sessions={data.sessions} knowledge={data.knowledge} system={data.system} />
      <ProjectCards projects={data.projects} />
      <SchedulePanel upcoming={data.upcoming} />
    </>
  );

  return (
    <div className="min-h-screen bg-vigil-bg text-slate-200">
      <StatusBar data={data} connected={connected} onToggleDrawer={() => setDrawerOpen(!drawerOpen)} />
      <div className="max-w-[1400px] mx-auto flex">
        <main className="flex-1 p-4 lg:p-5 space-y-5 lg:border-r border-vigil-border min-w-0">
          <Pipeline kanban={data.kanban} />
          <AttentionPanel sessions={data.sessions} />
          <KanbanBoard kanban={data.kanban} />
          <ActivityFeed activity={data.activity} />
        </main>
        <ContextDrawer open={drawerOpen} onClose={() => setDrawerOpen(false)}>
          {contextPanel}
        </ContextDrawer>
      </div>
    </div>
  );
}
