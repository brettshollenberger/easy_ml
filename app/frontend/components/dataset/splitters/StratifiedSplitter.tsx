import React from 'react';
import { SearchableSelect } from '../../SearchableSelect';

interface StratifiedSplitterProps {
  targetColumn: string;
  testSize: number;
  validSize: number;
  columns: Array<{ name: string; type: string }>;
  onChange: (config: { targetColumn: string; testSize: number; validSize: number }) => void;
}

export function StratifiedSplitter({
  targetColumn,
  testSize,
  validSize,
  columns,
  onChange
}: StratifiedSplitterProps) {
  return (
    <div className="space-y-4">
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Target Column
        </label>
        <SearchableSelect
          options={columns.map(col => ({
            value: col.name,
            label: col.name,
            description: `Type: ${col.type}`
          }))}
          value={targetColumn}
          onChange={(value) => onChange({
            targetColumn: value as string,
            testSize,
            validSize
          })}
          placeholder="Select target column..."
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Test Set Size (%)
          </label>
          <input
            type="number"
            min={1}
            max={40}
            value={testSize}
            onChange={(e) => onChange({
              targetColumn,
              testSize: parseInt(e.target.value) || 0,
              validSize
            })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            Validation Set Size (%)
          </label>
          <input
            type="number"
            min={1}
            max={40}
            value={validSize}
            onChange={(e) => onChange({
              targetColumn,
              testSize,
              validSize: parseInt(e.target.value) || 0
            })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          />
        </div>
      </div>
    </div>
  );
}