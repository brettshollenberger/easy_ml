import React, { useState, useMemo, useEffect } from 'react';
import { Link, usePage, router } from '@inertiajs/react';
import { Database, Plus } from 'lucide-react';
import { EmptyState } from '../components/EmptyState';
import { SearchInput } from '../components/SearchInput';
import { Pagination } from '../components/Pagination';
import { DatasetCard } from '../components/DatasetCard';
import { Dataset } from "@types/dataset";

interface Props {
  datasets: Dataset[];
}

const ITEMS_PER_PAGE = 6;

export default function DatasetsPage({ datasets }: Props) {
  const { rootPath } = usePage().props;
  const [searchQuery, setSearchQuery] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [expandedErrors, setExpandedErrors] = useState<number[]>([]);

  const filteredDatasets = useMemo(() => {
    return datasets.filter(dataset =>
      dataset.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      dataset.description.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [datasets, searchQuery]);

  const totalPages = Math.ceil(filteredDatasets.length / ITEMS_PER_PAGE);
  const paginatedDatasets = filteredDatasets.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  const handleDelete = (datasetId: number) => {
    if (confirm('Are you sure you want to delete this dataset?')) {
      router.delete(`${rootPath}/datasets/${datasetId}`);
    }
  };

  const handleRefresh = (datasetId: number) => {
    router.post(`${rootPath}/datasets/${datasetId}/refresh`);
  };

  const handleAbort = (datasetId: number) => {
    router.post(`${rootPath}/datasets/${datasetId}/abort`, {}, {
      preserveScroll: true,
      preserveState: true
    });
  };

  useEffect(() => {
    let pollInterval: number | undefined;

    const isAnyAnalyzing = datasets.some(d => d.workflow_status === 'analyzing');

    if (isAnyAnalyzing) {
      pollInterval = window.setInterval(() => {
        router.get(window.location.href, {}, {
          preserveScroll: true,
          preserveState: true,
          only: ['datasets']
        });
      }, 2000);
    }

    return () => {
      if (pollInterval) {
        window.clearInterval(pollInterval);
      }
    };
  }, [datasets]);

  const toggleError = (id: number) => {
    setExpandedErrors(prev =>
      prev.includes(id)
        ? prev.filter(expandedId => expandedId !== id)
        : [...prev, id]
    );
  };

  if (datasets.length === 0) {
    return (
      <div className="p-8">
        <EmptyState
          icon={Database}
          title="Create your first dataset"
          description="Create a dataset to start training your machine learning models"
          actionLabel="Create Dataset"
          onAction={() => { router.visit(`${rootPath}/datasets/new`) }}
        />
      </div>
    );
  }

  return (
    <div className="p-8">
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-4">
            <h2 className="text-xl font-semibold text-gray-900">Datasets</h2>
            <SearchInput
              value={searchQuery}
              onChange={setSearchQuery}
              placeholder="Search datasets..."
            />
          </div>
          <Link
            href={`${rootPath}/datasets/new`}
            className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <Plus className="w-4 h-4" />
            New Dataset
          </Link>
        </div>

        {paginatedDatasets.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-lg shadow">
            <Database className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">No datasets found</h3>
            <p className="mt-1 text-sm text-gray-500">
              No datasets match your search criteria. Try adjusting your search or create a new dataset.
            </p>
            <div className="mt-6">
              <Link
                href={`${rootPath}/datasets/new`}
                className="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <Plus className="w-4 h-4 mr-2" />
                New Dataset
              </Link>
            </div>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {paginatedDatasets.map((dataset) => (
                <DatasetCard
                  key={dataset.id}
                  dataset={dataset}
                  rootPath={rootPath}
                  onDelete={handleDelete}
                  onRefresh={handleRefresh}
                  onAbort={handleAbort}
                  isErrorExpanded={expandedErrors.includes(dataset.id)}
                  onToggleError={toggleError}
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
    </div>
  );
}
