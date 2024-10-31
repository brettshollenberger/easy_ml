import React, { useState } from 'react';
import { Plus, FolderPlus } from 'lucide-react';
import { Link } from 'react-router-dom';
import { mockTransformationGroups } from '../mockData';
import { TransformationCard } from '../components/transformations/TransformationCard';
import { TransformationGroupCard } from '../components/transformations/TransformationGroupCard';
import { EmptyState } from '../components/EmptyState';

export function TransformationsPage() {
  const [view, setView] = useState<'groups' | 'all'>('groups');

  if (mockTransformationGroups.length === 0) {
    return (
      <div className="p-8">
        <EmptyState
          icon={FolderPlus}
          title="Create your first transformation group"
          description="Create a group to organize your column transformations"
          actionLabel="Create Group"
          onAction={() => {/* Handle group creation */}}
        />
      </div>
    );
  }

  const allTransformations = mockTransformationGroups.flatMap(g => g.transformations);

  return (
    <div className="p-8">
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-4">
            <h2 className="text-xl font-semibold text-gray-900">Transformations</h2>
            <div className="flex rounded-md shadow-sm">
              <button
                onClick={() => setView('groups')}
                className={`px-4 py-2 text-sm font-medium rounded-l-md ${
                  view === 'groups'
                    ? 'bg-blue-600 text-white'
                    : 'bg-white text-gray-700 hover:text-gray-900 border border-gray-300'
                }`}
              >
                Groups
              </button>
              <button
                onClick={() => setView('all')}
                className={`px-4 py-2 text-sm font-medium rounded-r-md ${
                  view === 'all'
                    ? 'bg-blue-600 text-white'
                    : 'bg-white text-gray-700 hover:text-gray-900 border border-l-0 border-gray-300'
                }`}
              >
                All Transformations
              </button>
            </div>
          </div>
          <div className="flex gap-3">
            <Link
              to="/transformations/groups/new"
              className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 text-sm font-medium rounded-md text-gray-700 hover:bg-gray-50"
            >
              <FolderPlus className="w-4 h-4" />
              New Group
            </Link>
            <Link
              to="/transformations/new"
              className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700"
            >
              <Plus className="w-4 h-4" />
              New Transformation
            </Link>
          </div>
        </div>

        {view === 'groups' ? (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {mockTransformationGroups.map((group) => (
              <TransformationGroupCard key={group.id} group={group} />
            ))}
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
            {allTransformations.map((transformation) => (
              <TransformationCard
                key={transformation.id}
                transformation={transformation}
                group={mockTransformationGroups.find(g => g.id === transformation.groupId)!}
              />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}