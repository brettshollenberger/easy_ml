import React from 'react';
import { SearchableSelect } from '../../SearchableSelect';

interface KFoldSplitterProps {
  type: 'kfold' | 'stratified' | 'group';
  targetColumn?: string;
  groupColumn?: string;
  nSplits: number;
  columns: Array<{ name: string; type: string }>;
  onChange: (config: {
    targetColumn?: string;
    groupColumn?: string;
    nSplits: number;
  }) => void;
}

export function KFoldSplitter({
  type,
  targetColumn,
  groupColumn,
  nSplits,
  columns,
  onChange
}: KFoldSplitterProps) {
  return (
    <div className="space-y-4">
      {(type === 'stratified' || type === 'group') && (
        <div>
          <label className="block text-sm font-medium text-gray-700 mb-1">
            {type === 'stratified' ? 'Target Column' : 'Group Column'}
          </label>
          <SearchableSelect
            options={columns.map(col => ({
              value: col.name,
              label: col.name,
              description: `Type: ${col.type}`
            }))}
            value={type === 'stratified' ? targetColumn : groupColumn}
            onChange={(value) => onChange({
              targetColumn: type === 'stratified' ? value as string : targetColumn,
              groupColumn: type === 'group' ? value as string : groupColumn,
              nSplits
            })}
            placeholder={`Select ${type === 'stratified' ? 'target' : 'group'} column...`}
          />
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Number of Splits
        </label>
        <input
          type="number"
          min={2}
          max={10}
          value={nSplits}
          onChange={(e) => onChange({
            targetColumn,
            groupColumn,
            nSplits: parseInt(e.target.value) || 2
          })}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        />
      </div>
    </div>
  );
}