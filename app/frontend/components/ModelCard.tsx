import React from 'react';
import { Activity, Calendar, Database, Settings } from 'lucide-react';
import type { Model, RetrainingJob, RetrainingRun } from '../types';

interface ModelCardProps {
  model: Model;
  job?: RetrainingJob;
  lastRun?: RetrainingRun;
  onViewDetails: (modelId: number) => void;
}

export function ModelCard({ model, job, lastRun, onViewDetails }: ModelCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div className="flex justify-between items-start mb-4">
        <div>
          <h3 className="text-lg font-semibold text-gray-900 flex items-center gap-2">
            <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
              ${model.status === 'ready' ? 'bg-green-100 text-green-800' : 
                model.status === 'training' ? 'bg-yellow-100 text-yellow-800' :
                model.status === 'error' ? 'bg-red-100 text-red-800' :
                'bg-gray-100 text-gray-800'}`}>
              {model.status}
            </span>
            {model.name}
          </h3>
          <p className="text-sm text-gray-500 mt-1">Type: {model.modelType}</p>
        </div>
        <button
          onClick={() => onViewDetails(model.id)}
          className="text-blue-600 hover:text-blue-800"
        >
          <Settings className="w-5 h-5" />
        </button>
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