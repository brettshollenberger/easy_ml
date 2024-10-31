import React from 'react';
import { Activity, Calendar, Database, Settings, ExternalLink } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import type { Model, RetrainingJob, RetrainingRun } from '../types';

interface ModelCardProps {
  model: Model;
  job?: RetrainingJob;
  lastRun?: RetrainingRun;
  onViewDetails: (modelId: number) => void;
}

export function ModelCard({ model, job, lastRun, onViewDetails }: ModelCardProps) {
  const navigate = useNavigate();

  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div className="flex flex-col gap-2">
        <div className="flex items-center gap-2">
          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
            ${model.deploymentStatus === 'inference' 
              ? 'bg-blue-100 text-blue-800'
              : 'bg-gray-100 text-gray-800'}`}
          >
            {model.deploymentStatus}
          </span>
          {model.promoted && (
            <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-purple-100 text-purple-800">
              promoted
            </span>
          )}
        </div>

        <div className="flex justify-between items-start">
          <h3 className="text-lg font-semibold text-gray-900">{model.name}</h3>
          <div className="flex gap-2">
            <button
              onClick={() => navigate(`/models/${model.id}/edit`)}
              className="text-gray-400 hover:text-gray-600"
              title="Edit model"
            >
              <Settings className="w-5 h-5" />
            </button>
            <button
              onClick={() => onViewDetails(model.id)}
              className="text-gray-400 hover:text-gray-600"
              title="View details"
            >
              <ExternalLink className="w-5 h-5" />
            </button>
          </div>
        </div>

        <p className="text-sm text-gray-500">Version {model.version} • Type: {model.modelType}</p>
      </div>

      <div className="grid grid-cols-2 gap-4 mt-4">
        <div className="flex items-center gap-2">
          <Database className="w-4 h-4 text-gray-400" />
          <span className="text-sm text-gray-600">Dataset #{model.datasetId}</span>
        </div>
        <div className="flex items-center gap-2">
          <Calendar className="w-4 h-4 text-gray-400" />
          <span className="text-sm text-gray-600">
            {job ? `Retrains ${job.frequency}` : 'No schedule'}
          </span>
        </div>
        <div className="flex items-center gap-2">
          <Activity className="w-4 h-4 text-gray-400" />
          <span className="text-sm text-gray-600">
            {lastRun
              ? `Last run: ${new Date(lastRun.completedAt || '').toLocaleDateString()}`
              : 'Never run'}
          </span>
        </div>
      </div>

      {lastRun && lastRun.metadata && (
        <div className="mt-4 pt-4 border-t border-gray-100">
          <div className="flex flex-wrap gap-2">
            {Object.entries(lastRun.metadata.metrics as Record<string, number>).map(([key, value]) => (
              <div
                key={key}
                className={`px-2 py-1 rounded-md text-xs font-medium ${
                  lastRun.shouldPromote
                    ? 'bg-green-100 text-green-800'
                    : 'bg-red-100 text-red-800'
                }`}
              >
                {key}: {value.toFixed(4)}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}