import React, { useState, useMemo } from 'react';
// import { Inertia } from '@inertiajs/inertia';
import { Brain, Plus } from 'lucide-react';
import { ModelCard } from '../components/ModelCard';
import { ModelDetails } from '../components/ModelDetails';
import { EmptyState } from '../components/EmptyState';
import { SearchInput } from '../components/SearchInput';
import { Pagination } from '../components/Pagination';
import { mockModels, mockRetrainingJobs, mockRetrainingRuns } from '../mockData';

// let models = []; //mockModels;
// let retrainingJobs = []; //mockRetrainingJobs;
// let retrainingRuns = []; mockRetrainingRuns;
const models = [];
const retrainingRuns = [];
const retrainingJobs = [];
const ITEMS_PER_PAGE = 6;

export function ModelsPage() {
  const [selectedModelId, setSelectedModelId] = useState<number | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [currentPage, setCurrentPage] = useState(1);

  const filteredModels = useMemo(() => {
    return models.filter(model =>
      model.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      model.modelType.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [searchQuery]);

  const totalPages = Math.ceil(filteredModels.length / ITEMS_PER_PAGE);
  const paginatedModels = filteredModels.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  const selectedModel = models.find((m) => m.id === selectedModelId);
  const modelRuns = retrainingRuns.filter((r) => r.modelId === selectedModelId);
  const modelJob = retrainingJobs.find((j) => j.model === selectedModel?.name);

  if (models.length === 0) {
    return (
      <div className="p-8">
        <EmptyState
          icon={Brain}
          title="Create your first ML model"
          description="Get started by creating a machine learning model. You can train models for classification, regression, and more."
          actionLabel="Create Model"
          onAction={() => console.log("Clicked!")}//Inertia.visit('/models/new')}
        />
      </div>
    );
  }

  return (
    <div className="p-8">
      {selectedModel ? (
        <ModelDetails
          model={selectedModel}
          runs={modelRuns}
          job={modelJob}
          onBack={() => setSelectedModelId(null)}
        />
      ) : (
        <div className="space-y-6">
          <div className="flex justify-between items-center">
            <div className="flex items-center gap-4">
              <h2 className="text-xl font-semibold text-gray-900">Models</h2>
              <SearchInput
                value={searchQuery}
                onChange={setSearchQuery}
                placeholder="Search models..."
              />
            </div>
            <button
              onClick={() => console.log("clicked!") } //Inertia.visit('/models/new')}
              className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              <Plus className="w-4 h-4" />
              New Model
            </button>
          </div>

          {paginatedModels.length === 0 ? (
            <div className="text-center py-12 bg-white rounded-lg shadow">
              <Brain className="mx-auto h-12 w-12 text-gray-400" />
              <h3 className="mt-2 text-sm font-medium text-gray-900">No models found</h3>
              <p className="mt-1 text-sm text-gray-500">
                No models match your search criteria. Try adjusting your search or create a new model.
              </p>
              <div className="mt-6">
                <button
                  onClick={() => console.log("CLICKED") }//Inertia.visit('/models/new')}
                  className="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
                >
                  <Plus className="w-4 h-4 mr-2" />
                  New Model
                </button>
              </div>
            </div>
          ) : (
            <>
              <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                {paginatedModels.map((model) => (
                  <ModelCard
                    key={model.id}
                    model={model}
                    job={retrainingJobs.find((j) => j.model === model.name)}
                    lastRun={retrainingRuns.find((r) => r.modelId === model.id)}
                    onViewDetails={setSelectedModelId}
                  />
                ))}
              </div>

              {totalPages > 1 && (
                <Pagination
                  currentPage={currentPage}
                  totalPages={totalPages}
                  onPageChange={setCurrentPage}
                />
              )}
            </>
          )}
        </div>
      )}
    </div>
  );
}