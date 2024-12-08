import React from 'react';
import { Activity, Calendar, Database, Settings, ExternalLink, Trash2 } from 'lucide-react';
import { Link } from "@inertiajs/react";
import type { Model, RetrainingJob, RetrainingRun } from '../types';

interface ModelCardProps {
  model: Model;
  onViewDetails: (modelId: number) => void;
  handleDelete: (modelId: number) => void;
}

export function ModelCard({ model, onViewDetails, handleDelete, rootPath }: ModelCardProps) {
  const dataset = model.dataset;
  const job = model.retraining_job;
  const lastRun = model.last_run;

  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div className="flex flex-col gap-2">
        <div className="flex items-center gap-2">
          <span className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium
            ${model.deployment_status === 'inference' 
              ? 'bg-blue-100 text-blue-800'
              : 'bg-gray-100 text-gray-800'}`}
          >
            {model.deployment_status}
          </span>
        </div>

        <div className="flex justify-between items-start">
          <h3 className="text-lg font-semibold text-gray-900">{model.name}</h3>
          <div className="flex gap-2">
            <Link
              href={`${rootPath}/models/${model.id}/edit`}
              className="text-gray-400 hover:text-gray-600"
              title="Edit model"
            >
              <Settings className="w-5 h-5" />
            </Link>
            <Link
              href={`${rootPath}/models/${model.id}`}
              className="text-gray-400 hover:text-gray-600"
              title="View details"
            >
              <ExternalLink className="w-5 h-5" />
            </Link>
            <button
              onClick={() => handleDelete(model.id)}
              className="text-gray-400 hover:text-gray-600"
              title="Delete model"
            >
              <Trash2 className="w-5 h-5" />
            </button>
          </div>
        </div>

        <p className="text-sm text-gray-500">
          <span className="font-semibold">Model Type: </span>
          {model.formatted_model_type}
        </p>
        <p className="text-sm text-gray-500">
          <span className="font-semibold">Version: </span>
          {model.version}
        </p>
      </div>

      <div className="grid grid-cols-2 gap-4 mt-4">
        <div className="flex items-center gap-2">
          <Database className="w-4 h-4 text-gray-400" />
          {dataset ? (
            <Link 
              href={`${rootPath}/datasets/${dataset.id}`}
              className="text-sm text-blue-600 hover:text-blue-800"
            >
              {dataset.name}
            </Link>
          ) : (
            <span className="text-sm text-gray-600">Dataset not found</span>
          )}
        </div>
        <div className="flex items-center gap-2">
          <Calendar className="w-4 h-4 text-gray-400" />
          <span className="text-sm text-gray-600">
            {job ? `Retrains ${model.formatted_frequency}` : 'No schedule'}
          </span>
        </div>
        <div className="flex items-center gap-2">
          <Activity className="w-4 h-4 text-gray-400" />
          <span className="text-sm text-gray-600">
            {model.last_run_at
              ? `Last run: ${new Date(model.last_run_at || '').toLocaleDateString()}`
              : 'Never run'}
          </span>
        </div>
      </div>

      {lastRun && (
        <div className="mt-4 pt-4 border-t border-gray-100">
          <div className="flex flex-wrap gap-2">
            {Object.entries(lastRun.metrics as Record<string, number>).map(([key, value]) => (
              <div
                key={key}
                className={`px-2 py-1 rounded-md text-xs font-medium ${
                  lastRun.should_promote
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