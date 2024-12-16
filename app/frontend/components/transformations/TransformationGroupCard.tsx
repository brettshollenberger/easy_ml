import React from 'react';
// import { Link } from 'react-router-dom';
import { FolderOpen, Settings, Trash2 } from 'lucide-react';
import type { FeatureationGroup } from '../../types';

interface FeatureationGroupCardProps {
  group: FeatureationGroup;
}

export function FeatureationGroupCard({ group }: FeatureationGroupCardProps) {
  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
      <div className="flex justify-between items-start mb-4">
        <div className="flex items-start gap-3">
          <FolderOpen className="w-5 h-5 text-blue-600 mt-1" />
          <div>
            <h3 className="text-lg font-semibold text-gray-900">
              {group.name}
            </h3>
            <p className="text-sm text-gray-500 mt-1">
              {group.description}
            </p>
          </div>
        </div>
        <div className="flex gap-2">
          <Link
            to={`/features/groups/${group.id}/edit`}
            className="text-gray-400 hover:text-blue-600 transition-colors"
            title="Edit group"
          >
            <Settings className="w-5 h-5" />
          </Link>
          <button
            className="text-gray-400 hover:text-red-600 transition-colors"
            title="Delete group"
          >
            <Trash2 className="w-5 h-5" />
          </button>
        </div>
      </div>

      <div className="mt-4 pt-4 border-t border-gray-100">
        <div className="flex items-center justify-between text-sm">
          <span className="text-gray-500">
            {group.features.length} features
          </span>
          <span className="text-gray-500">
            Last updated {new Date(group.updatedAt).toLocaleDateString()}
          </span>
        </div>
      </div>
    </div>
  );
}