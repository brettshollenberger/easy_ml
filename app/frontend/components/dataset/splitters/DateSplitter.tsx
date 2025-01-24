import React from 'react';
import { SearchableSelect } from '../../SearchableSelect';
import type { DateSplitConfig } from '../types';

interface DateSplitterProps {
  attributes: DateSplitConfig;
  columns: string[];
  onChange: (attributes: DateSplitConfig) => void;
}

export function DateSplitter({ attributes, columns, onChange }: DateSplitterProps) {
  return (
    <div className="space-y-4">
      <div>
        <label htmlFor="date_col" className="block text-sm font-medium text-gray-700">
          Date Column
        </label>
        <SearchableSelect
          id="date_col"
          value={attributes.date_col}
          options={columns.map(col => ({ value: col, label: col }))}
          onChange={(value) => onChange({ ...attributes, date_col: value })}
          placeholder="Select date column"
        />
      </div>

      <div className="grid grid-cols-2 gap-4">
        <div>
          <label htmlFor="months_test" className="block text-sm font-medium text-gray-700">
            Test Months
          </label>
          <input
            type="number"
            id="months_test"
            value={attributes.months_test}
            onChange={(e) => onChange({ ...attributes, months_test: parseInt(e.target.value) })}
            className="mt-1 p-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            min="1"
          />
        </div>

        <div>
          <label htmlFor="months_valid" className="block text-sm font-medium text-gray-700">
            Validation Months
          </label>
          <input
            type="number"
            id="months_valid"
            value={attributes.months_valid}
            onChange={(e) => onChange({ ...attributes, months_valid: parseInt(e.target.value) })}
            className="mt-1 p-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            min="1"
          />
        </div>
      </div>
    </div>
  );
}
