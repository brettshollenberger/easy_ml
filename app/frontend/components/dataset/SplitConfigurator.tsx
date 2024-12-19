import React, { Fragment } from 'react';
import { Tab } from '@headlessui/react';
import { Info } from 'lucide-react';
import { SearchableSelect } from '../SearchableSelect';
import { DateSplitter } from './splitters/DateSplitter';
import { RandomSplitter } from './splitters/RandomSplitter';
import { PredefinedSplitter } from './splitters/PredefinedSplitter';
import { StratifiedSplitter } from './splitters/StratifiedSplitter';
import { KFoldSplitter } from './splitters/KFoldSplitter';
import { LeavePOutSplitter } from './splitters/LeavePOutSplitter';
import { SPLITTER_OPTIONS, DEFAULT_CONFIGS } from './splitters/constants';
import type { SplitterType, SplitConfig, ColumnConfig } from './splitters/types';

interface SplitConfiguratorProps {
  type: SplitterType;
  splitter_attributes: SplitConfig;
  columns: ColumnConfig[];
  available_files: string[];
  onChange: (type: SplitterType, attributes: SplitConfig) => void;
}

export function SplitConfigurator({ type, splitter_attributes, columns, available_files, onSplitterChange, onChange }: SplitConfiguratorProps) {
  const dateColumns = columns.filter(col => col.type === 'datetime').map(col => col.name);

  const handleTypeChange = (newType: SplitterType) => {
    onChange(newType, DEFAULT_CONFIGS[newType]);
  };

  const handleSplitterChange = (type: SplitterType, newAttributes: SplitConfig) => {
    onChange(type, newAttributes);
  };

  const renderSplitter = () => {
    switch (type) {
      case 'date':
        return (
          <DateSplitter
            attributes={splitter_attributes}
            columns={dateColumns}
            onChange={(attrs) => handleSplitterChange(type, attrs)}
          />
        );
      case 'random':
        return (
          <RandomSplitter
            attributes={splitter_attributes}
            onChange={(attrs) => handleSplitterChange(type, attrs)}
          />
        );
      case 'predefined':
        return (
          <PredefinedSplitter
            attributes={splitter_attributes}
            available_files={available_files}
            onChange={(attrs) => handleSplitterChange(type, attrs)}
          />
        );
      case 'stratified':
        return (
          <StratifiedSplitter
            attributes={splitter_attributes}
            columns={columns}
            onChange={(attrs) => handleSplitterChange(type, attrs)}
          />
        );
      case 'stratified_kfold':
      case 'group_kfold':
        return (
          <KFoldSplitter
            attributes={splitter_attributes}
            columns={columns}
            onChange={(attrs) => handleSplitterChange(type, attrs)}
          />
        );
      case 'group_shuffle':
        return (
          <StratifiedSplitter
            attributes={splitter_attributes}
            columns={columns}
            onChange={(attrs) => handleSplitterChange(type, {
              groupColumn: attrs.targetColumn,
              testSize: attrs.testSize,
              validSize: attrs.validSize
            })}
          />
        );
      case 'leave_p_out':
        return (
          <LeavePOutSplitter
            attributes={splitter_attributes}
            onChange={(attrs) => handleSplitterChange(type, attrs)}
          />
        );
      default:
        return null;
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Split Type
        </label>
        <SearchableSelect
          options={SPLITTER_OPTIONS}
          value={type}
          onChange={(value) => handleTypeChange(value as SplitterType)}
        />
      </div>

      <div className="bg-gray-50 rounded-lg p-4">
        {renderSplitter()}
      </div>
    </div>
  );
}

export type { SplitterType };
export type { ColumnConfig };