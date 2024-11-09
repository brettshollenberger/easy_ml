import { useState, useEffect, useCallback, useRef } from 'react';
import debounce from 'lodash/debounce';
import isEqual from 'lodash/isEqual';

interface AutosaveStatus {
  saving: boolean;
  saved: boolean;
  error: string | null;
}

export function useAutosave<T>(
  data: T,
  onSave: (data: T) => Promise<void>,
  debounceMs: number = 1000
) {
  const [status, setStatus] = useState<AutosaveStatus>({
    saving: false,
    saved: false,
    error: null
  });

  const previousSerializedData = useRef(JSON.stringify(data));

  const debouncedSave = useCallback(
    debounce(async (newData: T) => {
      setStatus(prev => ({ ...prev, saving: true, error: null }));
      try {
        await onSave(newData);
        previousSerializedData.current = JSON.stringify(newData); // Update reference after saving
        setStatus({ saving: false, saved: true, error: null });

        // Reset "saved" status after 3 seconds
        setTimeout(() => {
          setStatus(prev => ({ ...prev, saved: false }));
        }, 4000);
      } catch (err) {
        setStatus({
          saving: false,
          saved: false,
          error: err instanceof Error ? err.message : 'Failed to save changes'
        });
      }
    }, debounceMs),
    [onSave, debounceMs]
  );

  useEffect(() => {
    // Serialize current data for deep comparison
    const serializedData = JSON.stringify(data);

    if (serializedData !== previousSerializedData.current) {
      console.log(`changed data!`)
      debouncedSave(data); // Trigger save if there's a difference
    }

    return () => {
      debouncedSave.cancel();
    };
  }, [data, debouncedSave]);

  return status;
}
