import React from 'react';
import { Code2, Settings, Trash2, FolderOpen } from 'lucide-react';
import type { Feature, FeatureGroup } from '../../types';

interface FeatureCardProps {
  feature: Feature;
  group: FeatureGroup;
}

export function FeatureCard({ feature, group }: FeatureCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div className="flex justify-between items-start mb-4">
        <div className="flex items-start gap-3">
          <Code2 className="w-5 h-5 text-blue-600 mt-1" />
          <div>
            <h3 className="text-lg font-semibold text-gray-900">
              {feature.name}
            </h3>
            <p className="text-sm text-gray-500 mt-1">
              {feature.description}
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <Link
            to={`/features/${feature.id}/edit`}
            className="text-gray-400 hover:text-blue-600 transition-colors"
            title="Edit feature"
          >
            <Settings className="w-5 h-5" />
          </Link>
          <button
            className="text-gray-400 hover:text-red-600 transition-colors"
            title="Delete feature"
          >
            <Trash2 className="w-5 h-5" />
          </button>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4 mt-4">
        <div>
          <span className="text-sm text-gray-500">Input Columns</span>
          <div className="flex flex-wrap gap-2 mt-1">
            {feature.inputColumns.map((column) => (
              <span
                key={column}
                className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800"
              >
                {column}
              </span>
            ))}
          </div>
        </div>
        <div>
          <span className="text-sm text-gray-500">Output Columns</span>
          <div className="flex flex-wrap gap-2 mt-1">
            {feature.outputColumns.map((column) => (
              <span
                key={column}
                className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
              >
                {column}
              </span>
            ))}
          </div>
        </div>
      </div>

      <div className="mt-4 pt-4 border-t border-gray-100">
        <div className="flex items-center justify-between">
          <Link
            to={`/features/groups/${group.id}`}
            className="flex items-center gap-2 text-sm text-gray-500 hover:text-gray-700"
          >
            <FolderOpen className="w-4 h-4" />
            {group.name}
          </Link>
          <span className="text-sm text-gray-500">
            Last updated {new Date(feature.updatedAt).toLocaleDateString()}
          </span>
        </div>
      </div>
    </div>
  );
}