import { useCallback, useEffect, useRef, useState } from "react";
import { friendlyError } from "../api/client";

interface Loaded<T> {
  data: T | null;
  error: string | null;
  loading: boolean;
  reload: () => void;
}

/** Runs `fn` on mount (and whenever `key` changes) and on `reload()`. Ignores stale answers. */
export function useLoad<T>(fn: () => Promise<T>, key: string = ""): Loaded<T> {
  const [data, setData] = useState<T | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const fnRef = useRef(fn);
  fnRef.current = fn;
  const seq = useRef(0);

  const run = useCallback(() => {
    const mine = ++seq.current;
    setLoading(true);
    setError(null);
    fnRef.current().then(
      (d) => {
        if (mine !== seq.current) return;
        setData(d);
        setLoading(false);
      },
      (e) => {
        if (mine !== seq.current) return;
        setError(friendlyError(e));
        setLoading(false);
      },
    );
  }, []);

  useEffect(() => {
    run();
    return () => {
      seq.current++; // drop the answer of a request that is still running
    };
  }, [run, key]);

  return { data, error, loading, reload: run };
}
