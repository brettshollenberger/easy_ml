import React from 'react';
import { Info } from 'lucide-react';
import type { RandomSplitConfig } from '../types';

interface RandomSplitterProps {
  attributes: RandomSplitConfig;
  onChange: (attributes: RandomSplitConfig) => void;
}

export function RandomSplitter({ attributes, onChange }: RandomSplitterProps) {
  return (
    <div className="space-y-4">
      <div className="flex items-start gap-2">
        <Info className="w-5 h-5 text-blue-500 mt-0.5" />
        <p className="text-sm text-blue-700">
          Random splitting will automatically split your data into 60% training, 20% test, and 20% validation sets.
        </p>
      </div>

      <div className="grid grid-cols-3 gap-4">
        <div>
          <label htmlFor="train_ratio" className="block text-sm font-medium text-gray-700">
            Training Ratio
          </label>
          <input
            type="number"
            id="train_ratio"
            value={attributes.train_ratio ?? 0.6}
            onChange={(e) => onChange({ ...attributes, train_ratio: parseFloat(e.target.value) })}
            className="mt-1 p-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            min="0"
            max="1"
            step="0.1"
          />
        </div>

        <div>
          <label htmlFor="test_ratio" className="block text-sm font-medium text-gray-700">
            Test Ratio
          </label>
          <input
            type="number"
            id="test_ratio"
            value={attributes.test_ratio ?? 0.2}
            onChange={(e) => onChange({ ...attributes, test_ratio: parseFloat(e.target.value) })}
            className="mt-1 p-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            min="0"
            max="1"
            step="0.1"
          />
        </div>

        <div>
          <label htmlFor="valid_ratio" className="block text-sm font-medium text-gray-700">
            Validation Ratio
          </label>
          <input
            type="number"
            id="valid_ratio"
            value={attributes.valid_ratio ?? 0.2}
            onChange={(e) => onChange({ ...attributes, valid_ratio: parseFloat(e.target.value) })}
            className="mt-1 p-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
            min="0"
            max="1"
            step="0.1"
          />
        </div>
      </div>

      <div>
        <label htmlFor="seed" className="block text-sm font-medium text-gray-700">
          Random Seed (optional)
        </label>
        <input
          type="number"
          id="seed"
          value={attributes.seed ?? ''}
          onChange={(e) => onChange({ ...attributes, seed: e.target.value ? parseInt(e.target.value) : undefined })}
          className="mt-1 p-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          placeholder="Enter a random seed"
        />
      </div>
    </div>
  );
}
