import React, { useState, useEffect } from 'react';
import { Calendar, Clock, BarChart2, Database, ChevronLeft, ChevronRight, Rocket, Loader2, LineChart } from 'lucide-react';
import type { Model, RetrainingJob, RetrainingRun } from '../types';
import { router } from "@inertiajs/react";

interface ModelDetailsProps {
  model: Model;
  onBack: () => void;
}

interface PaginatedRuns {
  runs: RetrainingRun[];
  total_count: number;
  limit: number;
  offset: number;
}

const ITEMS_PER_PAGE = 3;

const METRIC_MAPPINGS: Record<string, string> = {
  root_mean_squared_error: 'rmse',
  mean_absolute_error: 'mae',
  mean_squared_error: 'mse',
  r2_score: 'r2',
  accuracy_score: 'accuracy',
  precision_score: 'precision',
  recall_score: 'recall'
};

export function ModelDetails({ model, onBack, rootPath }: ModelDetailsProps) {
  const [activeTab, setActiveTab] = useState<'overview' | 'dataset'>('overview');
  const [runs, setRuns] = useState<RetrainingRun[]>(model.retraining_runs?.runs || []);
  const [loading, setLoading] = useState(false);
  const [pagination, setPagination] = useState({
    offset: 0,
    limit: 20,
    total_count: model.retraining_runs?.total_count || 0
  });
  const [currentPage, setCurrentPage] = useState(1);
  const dataset = model.dataset;
  const job = model.retraining_job;
  const hasMoreRuns = pagination.offset + pagination.limit < pagination.total_count;

  useEffect(() => {
    let pollInterval: number | undefined;

    const deployingRun = runs.find(run => run.is_deploying);
    if (deployingRun) {
      pollInterval = window.setInterval(async () => {
        router.get(window.location.href, {
          preserveScroll: true,
          preserveState: true,
          only: ['runs']
        })
      }, 2000);
    }
        
    return () => {
      if (pollInterval) {
        window.clearInterval(pollInterval);
      }
    };
  }, [runs]);

  const handleDeploy = async (run: RetrainingRun) => {
    if (run.is_deploying) return;
    
    const updatedRuns = runs.map(r => 
      r.id === run.id ? { ...r, is_deploying: true } : r
    );
    setRuns(updatedRuns);

    try {
      await router.post(`${rootPath}/models/${model.id}/deploys`, {
        retraining_run_id: run.id
      }, {
        preserveScroll: true,
        preserveState: true
      });
    } catch (error) {
      console.error('Failed to deploy model:', error);
      // Reset deploying state on error
      const resetRuns = runs.map(r => 
        r.id === run.id ? { ...r, is_deploying: false } : r
      );
      setRuns(resetRuns);
    }
  };

  useEffect(() => {
    const totalPages = Math.ceil(runs.length / ITEMS_PER_PAGE);
    const remainingPages = totalPages - currentPage;
    
    if (remainingPages <= 2 && hasMoreRuns) {
      loadMoreRuns();
    }
  }, [currentPage, runs, hasMoreRuns]);

  const totalPages = Math.ceil(runs.length / ITEMS_PER_PAGE);
  const paginatedRuns = runs.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  const updateCurrentPage = (newPage) => {
    setCurrentPage(newPage);
    if (totalPages - newPage < 2 && hasMoreRuns) {
      loadMoreRuns();
    }
  }

  const isCurrentlyDeployed = (run: RetrainingRun) => {
    return run.status === 'deployed';
  };

  const formatMetricKey = (key: string) => {
    return METRIC_MAPPINGS[key] || key;
  };

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
                  <span>{job.active ? `Runs ${job.formatted_frequency}` : "None (Triggered Manually)"}</span>
                </div>
                {
                  job.active && (
                    <div className="flex items-center gap-2">
                      <Clock className="w-5 h-5 text-gray-400" />
                      <span>at {job.at.hour}:00</span>
                    </div>
                  )
                }
              </div>
            </div>
          )}
        </div>

        {activeTab === 'overview' ? (
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <h3 className="text-lg font-semibold">Retraining Runs</h3>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => updateCurrentPage(p => Math.max(1, p - 1))}
                  disabled={currentPage === 1}
                  className="p-1 rounded-md hover:bg-gray-100 disabled:opacity-50"
                >
                  <ChevronLeft className="w-5 h-5" />
                </button>
                <span className="text-sm text-gray-600">
                  Page {currentPage} of {totalPages}
                </span>
                <button
                  onClick={() => updateCurrentPage(p => Math.min(totalPages, p + 1))}
                  disabled={currentPage === totalPages}
                  className="p-1 rounded-md hover:bg-gray-100 disabled:opacity-50"
                >
                  <ChevronRight className="w-5 h-5" />
                </button>
              </div>
            </div>

            <div className="space-y-4">
              {paginatedRuns.map((run, index) => (
                <div key={index} className="border border-gray-200 rounded-lg p-4 hover:border-gray-300 transition-colors">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <div className="flex items-center gap-2 mt-1">
                        {
                          !isCurrentlyDeployed(run) && (
                            <span
                              className={`px-2 py-1 rounded-md text-sm font-medium ${
                                run.status === 'success'
                                  ? 'bg-green-100 text-green-800'
                                  : run.status === 'running' ? 'bg-blue-100 text-blue-800' : 'bg-red-100 text-red-800'
                              }`}
                            >
                              {run.status}
                            </span>
                          )
                        }
                        {isCurrentlyDeployed(run) && (
                          <span className="px-2 py-1 bg-purple-100 text-purple-800 rounded-md text-sm font-medium flex items-center gap-1">
                            <Rocket className="w-4 h-4" />
                            deployed
                          </span>
                        )}
                        {run.metrics_url && (
                          <a
                            href={run.metrics_url}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1 px-2 py-1 bg-gray-100 text-gray-700 rounded-md text-sm font-medium hover:bg-gray-200 transition-colors"
                            title="View run metrics"
                          >
                            <LineChart className="w-4 h-4" />
                            metrics
                          </a>
                        )}
                      </div>
                    </div>
                    <div className="flex items-center gap-1">
                      <BarChart2 className="w-4 h-4 text-gray-400" />
                      <span className="text-sm text-gray-600">
                        {new Date(run.started_at).toLocaleString()}
                      </span>
                      {run.status === 'success' && run.deployable && (
                        <div className="flex gap-2 items-center">
                          {isCurrentlyDeployed(run) ? (
                            <span className="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-xs font-medium bg-green-100 text-green-800">
                              deployed
                            </span>
                          ) : (
                            <button
                              onClick={() => handleDeploy(run)}
                              disabled={run.is_deploying}
                              className={`ml-4 inline-flex items-center gap-2 px-3 py-1 rounded-md text-sm font-medium 
                                ${run.is_deploying 
                                  ? 'bg-yellow-100 text-yellow-800' 
                                  : 'bg-blue-600 text-white hover:bg-blue-500'
                                }`}
                            >
                              {run.is_deploying ? (
                                <>
                                  <Loader2 className="w-3 h-3 animate-spin" />
                                  Deploying...
                                </>
                              ) : (
                                <>
                                  <Rocket className="w-3 h-3" />
                                  Deploy
                                </>
                              )}
                            </button>
                          )}
                        </div>
                      )}
                    </div>
                  </div>

                  {run && run.metrics && (
                    <div className="grid grid-cols-2 sm:grid-cols-4 gap-4">
                      {Object.entries(
                        run.metrics as Record<string, number>
                      ).map(([key, value]) => (
                        <div key={key} className="bg-gray-50 rounded-md p-3">
                          <div className="text-sm font-medium text-gray-500">
                            {formatMetricKey(key)}
                          </div>
                          <div className="mt-1 flex items-center gap-2">
                            <span className="text-lg font-semibold">
                              {value.toFixed(4)}
                            </span>
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
                        <span className="text-sm font-medium">{dataset.num_rows.toLocaleString()}</span>
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