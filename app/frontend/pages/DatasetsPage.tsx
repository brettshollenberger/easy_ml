import React, { useState, useMemo, useEffect } from 'react';
import { Link, usePage, router } from '@inertiajs/react';
import { Database, Plus, Trash2, ExternalLink, Loader2, AlertCircle, ChevronDown, ChevronUp } from 'lucide-react';
import { EmptyState } from '../components/EmptyState';
import { SearchInput } from '../components/SearchInput';
import { Pagination } from '../components/Pagination';
import { Dataset, DatasetWorkflowStatus, Column } from "@types/dataset";
interface Props {
  datasets: Dataset[];
}

const ITEMS_PER_PAGE = 6;

const STATUS_STYLES: Record<DatasetWorkflowStatus, { bg: string; text: string; icon: React.ReactNode }> = {
  analyzing: {
    bg: 'bg-blue-100',
    text: 'text-blue-800',
    icon: <Loader2 className="w-4 h-4 animate-spin" />
  },
  ready: {
    bg: 'bg-green-100',
    text: 'text-green-800',
    icon: null
  },
  failed: {
    bg: 'bg-red-100',
    text: 'text-red-800',
    icon: <AlertCircle className="w-4 h-4" />
  },
};

export default function DatasetsPage({ datasets, constants }: Props) {
  console.log(datasets)
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
                <div
                  key={dataset.id}
                  className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow"
                >
                  <div className="flex justify-between items-start mb-4">
                    <div className="flex items-start gap-3">
                      <Database className="w-5 h-5 text-blue-600 mt-1" />
                      <div>
                        <div className="flex items-center gap-2">
                          <h3 className="text-lg font-semibold text-gray-900">
                            {dataset.name}
                          </h3>
                          <div className={`inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-medium ${STATUS_STYLES[dataset.workflow_status].bg} ${STATUS_STYLES[dataset.workflow_status].text}`}>
                            {STATUS_STYLES[dataset.workflow_status].icon}
                            <span>{dataset.workflow_status.charAt(0).toUpperCase() + dataset.workflow_status.slice(1)}</span>
                          </div>
                        </div>
                        <p className="text-sm text-gray-500 mt-1">
                          {dataset.description}
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Link
                        href={`${rootPath}/datasets/${dataset.id}`}
                        className={`transition-colors ${
                          dataset.workflow_status === 'analyzing'
                            ? 'text-gray-300 cursor-not-allowed pointer-events-none'
                            : 'text-gray-400 hover:text-blue-600'
                        }`}
                        title={dataset.workflow_status === 'analyzing' ? 'Dataset is being analyzed' : 'View details'}
                      >
                        <ExternalLink className="w-5 h-5" />
                      </Link>
                      <button
                        className="text-gray-400 hover:text-red-600 transition-colors"
                        title="Delete dataset"
                        onClick={() => handleDelete(dataset.id)}
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4 mt-4">
                    <div>
                      <span className="text-sm text-gray-500">Columns</span>
                      <p className="text-sm font-medium text-gray-900">
                        {dataset.columns.length} columns
                      </p>
                    </div>
                    <div>
                      <span className="text-sm text-gray-500">Rows</span>
                      <p className="text-sm font-medium text-gray-900">
                        {dataset.num_rows.toLocaleString()}
                      </p>
                    </div>
                  </div>

                  <div className="mt-4 pt-4 border-t border-gray-100">
                    <div className="flex flex-wrap gap-2">
                      {dataset.columns.slice(0, 3).map((column: Column) => (
                        <span
                          key={column.name}
                          className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800"
                        >
                          {column.name}
                        </span>
                      ))}
                      {dataset.columns.length > 3 && (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                          +{dataset.columns.length - 3} more
                        </span>
                      )}
                    </div>
                  </div>

                  {dataset.workflow_status === 'failed' && dataset.stacktrace && (
                    <div className="mt-4 pt-4 border-t border-gray-100">
                      <button
                        onClick={() => toggleError(dataset.id)}
                        className="flex items-center gap-2 text-sm text-red-600 hover:text-red-700"
                      >
                        <AlertCircle className="w-4 h-4" />
                        <span>View Error Details</span>
                        {expandedErrors.includes(dataset.id) ? (
                          <ChevronUp className="w-4 h-4" />
                        ) : (
                          <ChevronDown className="w-4 h-4" />
                        )}
                      </button>
                      {expandedErrors.includes(dataset.id) && (
                        <div className="mt-2 p-3 bg-red-50 rounded-md">
                          <pre className="text-xs text-red-700 whitespace-pre-wrap font-mono">
                            {dataset.stacktrace}
                          </pre>
                        </div>
                      )}
                    </div>
                  )}

                </div>
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
