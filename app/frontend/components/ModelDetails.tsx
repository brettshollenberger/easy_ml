import React, { useState } from 'react';
import { ArrowLeft, Calendar, Clock, BarChart2, Database } from 'lucide-react';
import type { Model, RetrainingJob, RetrainingRun } from '../types';
import { DatasetPreview } from './DatasetPreview';
import { mockDatasets } from '../mockData';

interface ModelDetailsProps {
  model: Model;
  runs: RetrainingRun[];
  job?: RetrainingJob;
  onBack: () => void;
}

export function ModelDetails({ model, runs, job, onBack }: ModelDetailsProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'dataset'>('overview');
  const dataset = mockDatasets.find(d => d.id === model.datasetId);

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <button
          onClick={onBack}
          className="flex items-center text-gray-600 hover:text-gray-800"
        >
          <ArrowLeft className="w-4 h-4 mr-2" />
          Back to Models
        </button>

        <div className="flex space-x-4">
          <button
            onClick={() => setActiveTab('overview')}
            className={`px-4 py-2 text-sm font-medium rounded-md ${
              activeTab === 'overview'
                ? 'bg-blue-100 text-blue-700'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            Overview
          </button>
          <button
            onClick={() => setActiveTab('dataset')}
            className={`px-4 py-2 text-sm font-medium rounded-md ${
              activeTab === 'dataset'
                ? 'bg-blue-100 text-blue-700'
                : 'text-gray-500 hover:text-gray-700'
            }`}
          >
            Dataset
          </button>
        </div>
      </div>

      {activeTab === 'overview' ? (
        <div className="bg-white rounded-lg shadow-lg p-6">
          <div className="mb-8">
            <div className="flex justify-between items-start">
              <div>
                <h2 className="text-2xl font-bold text-gray-900">{model.name}</h2>
                <p className="text-gray-600 mt-1">Type: {model.modelType}</p>
              </div>
              <span
                className={`px-3 py-1 rounded-full text-sm font-medium ${
                  model.status === 'ready'
                    ? 'bg-green-100 text-green-800'
                    : model.status === 'training'
                    ? 'bg-yellow-100 text-yellow-800'
                    : model.status === 'error'
                    ? 'bg-red-100 text-red-800'
                    : 'bg-gray-100 text-gray-800'
                }`}
              >
                {model.status}
              </span>
            </div>

            {job && (
              <div className="mt-6 bg-gray-50 rounded-lg p-4">
                <h3 className="text-lg font-semibold mb-4">Training Schedule</h3>
                <div className="grid grid-cols-2 gap-4">
                  <div className="flex items-center gap-2">
                    <Calendar className="w-5 h-5 text-gray-400" />
                    <span>Runs {job.frequency}</span>
                  </div>
                  <div className="flex items-center gap-2">
                    <Clock className="w-5 h-5 text-gray-400" />
                    <span>at {job.at}:00</span>
                  </div>
                </div>
              </div>
            )}
          </div>

          <div className="space-y-6">
            <h3 className="text-lg font-semibold">Training History</h3>
            <div className="space-y-4">
              {runs.map((run) => (
                <div
                  key={run.id}
                  className="border border-gray-200 rounded-lg p-4 hover:border-gray-300 transition-colors"
                >
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <span className="text-sm text-gray-500">
                        {new Date(run.startedAt || '').toLocaleString()}
                      </span>
                      <div className="flex items-center gap-2 mt-1">
                        <span
                          className={`px-2 py-1 rounded-md text-sm font-medium ${
                            run.status === 'completed'
                              ? 'bg-green-100 text-green-800'
                              : 'bg-red-100 text-red-800'
                          }`}
                        >
                          {run.status}
                        </span>
                        {run.shouldPromote && (
                          <span className="px-2 py-1 bg-blue-100 text-blue-800 rounded-md text-sm font-medium">
                            Promoted
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-1">
                      <BarChart2 className="w-4 h-4 text-gray-400" />
                      <span className="text-sm text-gray-600">
                        v{model.version}
                      </span>
                    </div>
                  </div>

                  {run.metadata && run.metadata.metrics && (
                    <div className="grid grid-cols-2 sm:grid-cols-3 gap-4">
                      {Object.entries(
                        run.metadata.metrics as Record<string, number>
                      ).map(([key, value]) => (
                        <div key={key} className="bg-gray-50 rounded-md p-3">
                          <div className="text-sm font-medium text-gray-500">
                            {key}
                          </div>
                          <div className="mt-1 flex items-center gap-2">
                            <span className="text-lg font-semibold">
                              {value.toFixed(4)}
                            </span>
                            {run.threshold && (
                              <span
                                className={`text-sm ${
                                  run.shouldPromote
                                    ? 'text-green-600'
                                    : 'text-red-600'
                                }`}
                              >
                                ({run.threshold.toFixed(4)})
                              </span>
                            )}
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      ) : (
        dataset && <DatasetPreview dataset={dataset} />
      )}
    </div>
  );
}