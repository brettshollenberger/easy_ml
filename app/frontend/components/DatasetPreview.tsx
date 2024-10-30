import React, { useState } from 'react';
import { Database, Table, ChevronDown, ChevronUp, BarChart } from 'lucide-react';
import type { Dataset, Column } from '../types';

interface DatasetPreviewProps {
  dataset: Dataset;
}

export function DatasetPreview({ dataset }: DatasetPreviewProps) {
  const [showStats, setShowStats] = useState(false);

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex items-start justify-between mb-6">
        <div>
          <div className="flex items-center gap-2">
            <Database className="w-5 h-5 text-blue-600" />
            <h3 className="text-xl font-semibold text-gray-900">{dataset.name}</h3>
          </div>
          <p className="text-gray-600 mt-1">{dataset.description}</p>
          <p className="text-sm text-gray-500 mt-2">
            {dataset.rowCount.toLocaleString()} rows • Last updated{' '}
            {new Date(dataset.updatedAt).toLocaleDateString()}
          </p>
        </div>
        <button
          onClick={() => setShowStats(!showStats)}
          className="flex items-center gap-1 text-blue-600 hover:text-blue-800"
        >
          <BarChart className="w-4 h-4" />
          <span className="text-sm font-medium">
            {showStats ? 'Hide Statistics' : 'Show Statistics'}
          </span>
          {showStats ? (
            <ChevronUp className="w-4 h-4" />
          ) : (
            <ChevronDown className="w-4 h-4" />
          )}
        </button>
      </div>

      <div className="space-y-6">
        {showStats && (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
            {dataset.columns.map((column) => (
              <div
                key={column.name}
                className="bg-gray-50 rounded-lg p-4"
              >
                <div className="flex items-center justify-between mb-2">
                  <h4 className="font-medium text-gray-900">{column.name}</h4>
                  <span className="text-xs font-medium text-gray-500 px-2 py-1 bg-gray-200 rounded-full">
                    {column.type}
                  </span>
                </div>
                <p className="text-sm text-gray-600 mb-3">{column.description}</p>
                {column.statistics && (
                  <div className="space-y-1">
                    {Object.entries(column.statistics).map(([key, value]) => (
                      <div key={key} className="flex justify-between text-sm">
                        <span className="text-gray-500">
                          {key.charAt(0).toUpperCase() + key.slice(1)}:
                        </span>
                        <span className="font-medium text-gray-900">
                          {typeof value === 'number' ? 
                            value.toLocaleString(undefined, {
                              maximumFractionDigits: 2
                            }) : 
                            value}
                        </span>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            ))}
          </div>
        )}

        <div className="overflow-x-auto">
          <div className="inline-block min-w-full align-middle">
            <div className="overflow-hidden shadow-sm ring-1 ring-black ring-opacity-5 rounded-lg">
              <table className="min-w-full divide-y divide-gray-300">
                <thead className="bg-gray-50">
                  <tr>
                    {dataset.columns.map((column) => (
                      <th
                        key={column.name}
                        scope="col"
                        className="px-3 py-3.5 text-left text-sm font-semibold text-gray-900"
                      >
                        {column.name}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-gray-200 bg-white">
                  {dataset.sampleData.map((row, i) => (
                    <tr key={i}>
                      {dataset.columns.map((column) => (
                        <td
                          key={column.name}
                          className="whitespace-nowrap px-3 py-4 text-sm text-gray-500"
                        >
                          {row[column.name]?.toString()}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}