import React, { useContext, useState } from 'react';
import { CaptureContext } from '../App.jsx';
import { startCapture } from '../api.js';

export default function CaptureButton({ scope, target, label, primary, disabled }) {
  const { setActiveRun, currentPlatform } = useContext(CaptureContext);
  const [error, setError] = useState(null);
  const [loading, setLoading] = useState(false);

  const handleClick = async () => {
    if (disabled || loading || !currentPlatform) return;
    setLoading(true);
    setError(null);
    try {
      const { runId } = await startCapture(currentPlatform, { scope, target });
      setActiveRun({ runId, scope, target });
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <button
      className={`btn${primary ? ' btn--primary' : ''}${disabled ? ' btn--disabled' : ''}`}
      onClick={handleClick}
      disabled={disabled || loading}
      title={error ?? undefined}
    >
      {loading ? '...' : label}
    </button>
  );
}
