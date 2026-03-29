import { useState, useEffect, useRef, useCallback } from 'react';

export function useVigilSocket() {
  const [data, setData] = useState(null);
  const [connected, setConnected] = useState(false);
  const wsRef = useRef(null);
  const reconnectRef = useRef(null);

  const connect = useCallback(() => {
    const protocol = location.protocol === 'https:' ? 'wss:' : 'ws:';
    const ws = new WebSocket(`${protocol}//${location.host}`);
    wsRef.current = ws;

    ws.onopen = () => setConnected(true);
    ws.onclose = () => {
      setConnected(false);
      reconnectRef.current = setTimeout(connect, 3000);
    };
    ws.onerror = () => {};
    ws.onmessage = (e) => {
      try {
        const msg = JSON.parse(e.data);
        if (msg.type === 'update') setData(msg.data);
      } catch {}
    };
  }, []);

  useEffect(() => {
    connect();
    return () => {
      clearTimeout(reconnectRef.current);
      wsRef.current?.close();
    };
  }, [connect]);

  // Fallback polling when WebSocket is down
  useEffect(() => {
    if (connected) return;
    const interval = setInterval(async () => {
      try {
        const r = await fetch('/data.json?' + Date.now());
        setData(await r.json());
      } catch {}
    }, 10000);
    return () => clearInterval(interval);
  }, [connected]);

  return { data, connected };
}
