import React, { useState } from 'react';
import { Calendar, Clock, BarChart2, Database, ChevronLeft, ChevronRight } from 'lucide-react';
import type { Model, RetrainingJob, RetrainingRun } from '../types';

interface ModelDetailsProps {
  model: Model;
  onBack: () => void;
}

const ITEMS_PER_PAGE = 3;

export function ModelDetails({ model, onBack }: ModelDetailsProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'dataset'>('overview');
  const [currentPage, setCurrentPage] = useState(1);
  const dataset = model.dataset;
  const job = model.retraining_job;
  const runs = model.last_run ? [model.last_run] : [];

  const totalPages = Math.ceil(runs.length / ITEMS_PER_PAGE);
  const paginatedRuns = runs.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div className="flex space-x-4 ml-auto">
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

      <div className="bg-white rounded-lg shadow-lg p-6">
        <div className="mb-8">
          <div className="flex justify-between items-start">
            <div>
              <h2 className="text-2xl font-bold text-gray-900">{model.name}</h2>
              <p className="text-gray-600 mt-1">
                <span className="font-medium">Version:</span> {model.version} • <span className="font-medium">Type:</span> {model.formatted_model_type}
              </p>
            </div>
            <span
              className={`px-3 py-1 rounded-full text-sm font-medium ${
                model.deployment_status === 'inference'
                  ? 'bg-blue-100 text-blue-800'
                  : 'bg-gray-100 text-gray-800'
              }`}
            >
              {model.deployment_status}
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
                  <span>at {job.at.hour}:00</span>
                </div>
              </div>
            </div>
          )}
        </div>

        {activeTab === 'overview' ? (
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-semibold">Training History</h3>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="p-1 rounded-md hover:bg-gray-100 disabled:opacity-50"
                >
                  <ChevronLeft className="w-5 h-5" />
                </button>
                <span className="text-sm text-gray-600">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="p-1 rounded-md hover:bg-gray-100 disabled:opacity-50"
                >
                  <ChevronRight className="w-5 h-5" />
                </button>
              </div>
            </div>

            <div className="space-y-4">
              {paginatedRuns.map((run) => (
                <div
                  key={run.id}
                  className="border border-gray-200 rounded-lg p-4 hover:border-gray-300 transition-colors"
                >
                  <div className="flex justify-between items-start mb-3">
                    <div>
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
                        {run.should_promote && (
                          <span className="px-2 py-1 bg-blue-100 text-blue-800 rounded-md text-sm font-medium">
                            Promoted
                          </span>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-1">
                      <BarChart2 className="w-4 h-4 text-gray-400" />
                      <span className="text-sm text-gray-600">
                        {new Date(run.started_at || '').toLocaleString()}
                      </span>
                    </div>
                  </div>

                  {run && run.metrics && (
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                      {Object.entries(
                        run.metrics as Record<string, number>
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
                                  run.should_promote
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
        ) : (
          dataset && (
            <div>
              <div className="flex items-center gap-2 mb-4">
                <Database className="w-5 h-5 text-blue-600" />
                <h3 className="text-lg font-semibold">{dataset.name}</h3>
              </div>
              <div className="grid grid-cols-2 gap-6">
                <div>
                  <h4 className="text-sm font-medium text-gray-700 mb-2">Columns</h4>
                  <div className="bg-gray-50 rounded-lg p-4">
                    <div className="space-y-2">
                      {dataset.columns.map(column => (
                        <div key={column.name} className="flex justify-between items-center">
                          <span className="text-sm text-gray-900">{column.name}</span>
                          <span className="text-xs text-gray-500">{column.type}</span>
                        </div>
                      ))}
                    </div>
                  </div>
                </div>
                <div>
                  <h4 className="text-sm font-medium text-gray-700 mb-2">Statistics</h4>
                  <div className="bg-gray-50 rounded-lg p-4">
                    <div className="space-y-2">
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-gray-900">Total Rows</span>
                        <span className="text-sm font-medium">{dataset.row_count.toLocaleString()}</span>
                      </div>
                      <div className="flex justify-between items-center">
                        <span className="text-sm text-gray-900">Last Updated</span>
                        <span className="text-sm font-medium">
                          {new Date(dataset.updated_at).toLocaleDateString()}
                        </span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )
        )}
      </div>
    </div>
  );
}