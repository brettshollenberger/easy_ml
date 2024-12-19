import React from 'react';

interface LeavePOutSplitterProps {
  p: number;
  onChange: (p: number) => void;
}

export function LeavePOutSplitter({ p, onChange }: LeavePOutSplitterProps) {
  return (
    <div className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Number of samples to leave out (P)
        </label>
        <input
          type="number"
          min={1}
          max={100}
          value={p}
          onChange={(e) => onChange(parseInt(e.target.value) || 1)}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        />
        <p className="mt-1 text-sm text-gray-500">
          Each training set will have P samples removed, which form the test set.
        </p>
      </div>
    </div>
  );
}