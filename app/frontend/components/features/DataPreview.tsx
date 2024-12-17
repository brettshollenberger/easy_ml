import React, { useState } from 'react';
import { Play, AlertTriangle } from 'lucide-react';
import type { Dataset } from '../../types';

interface DataPreviewProps {
  dataset: Dataset;
  code: string;
  inputColumns: string[];
  outputColumns: string[];
}

export function DataPreview({ dataset, code, inputColumns, outputColumns }: DataPreviewProps) {
  const [isRunning, setIsRunning] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [previewData, setPreviewData] = useState<Record<string, any>[] | null>(null);

  const runFeature = () => {
    setIsRunning(true);
    setError(null);

    // Simulate feature execution
    setTimeout(() => {
      try {
        // In a real implementation, this would execute the Ruby code
        // For now, we'll just show the original data
        setPreviewData(dataset.sampleData);
        setIsRunning(false);
      } catch (err) {
        setError(err instanceof Error ? err.message : 'An error occurred');
        setIsRunning(false);
      }
    }, 1000);
  };

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h4 className="text-sm font-medium text-gray-900">Data Preview</h4>
        <button
          onClick={runFeature}
          disabled={isRunning}
          className="inline-flex items-center gap-2 px-3 py-1.5 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 disabled:opacity-50"
        >
          <Play className="w-4 h-4" />
          {isRunning ? 'Running...' : 'Run Preview'}
        </button>
      </div>

      {error && (
        <div className="bg-red-50 border border-red-200 rounded-lg p-4">
          <div className="flex items-start gap-2">
            <AlertTriangle className="w-5 h-5 text-red-500 mt-0.5" />
            <div>
              <h4 className="text-sm font-medium text-red-800">
                Feature Error
              </h4>
              <pre className="mt-1 text-sm text-red-700 whitespace-pre-wrap font-mono">
                {error}
              </pre>
            </div>
          </div>
        </div>
      )}

      <div className="border border-gray-200 rounded-lg overflow-hidden">
        <div className="grid grid-cols-2 divide-x divide-gray-200">
          <div>
            <div className="px-4 py-2 bg-gray-50 border-b border-gray-200">
              <h5 className="text-sm font-medium text-gray-700">Input Data</h5>
            </div>
            <div className="overflow-x-auto">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    {inputColumns.map((column) => (
                      <th
                        key={column}
                        className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                      >
                        {column}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-200">
                  {dataset.sampleData.map((row, i) => (
                    <tr key={i}>
                      {inputColumns.map((column) => (
                        <td
                          key={column}
                          className="px-4 py-2 text-sm text-gray-900 whitespace-nowrap"
                        >
                          {String(row[column])}
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>

          <div>
            <div className="px-4 py-2 bg-gray-50 border-b border-gray-200">
              <h5 className="text-sm font-medium text-gray-700">
                {previewData ? 'Featureed Data' : 'Output Preview'}
              </h5>
            </div>
            <div className="overflow-x-auto">
              {previewData ? (
                <table className="min-w-full divide-y divide-gray-200">
                  <thead className="bg-gray-50">
                    <tr>
                      {outputColumns.map((column) => (
                        <th
                          key={column}
                          className="px-4 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
                        >
                          {column}
                        </th>
                      ))}
                    </tr>
                  </thead>
                  <tbody className="bg-white divide-y divide-gray-200">
                    {previewData.map((row, i) => (
                      <tr key={i}>
                        {outputColumns.map((column) => (
                          <td
                            key={column}
                            className="px-4 py-2 text-sm text-gray-900 whitespace-nowrap"
                          >
                            {String(row[column])}
                          </td>
                        ))}
                      </tr>
                    ))}
                  </tbody>
                </table>
              ) : (
                <div className="p-8 text-center text-sm text-gray-500">
                  Run the feature to see the preview
                </div>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}