import React, { useState, useMemo } from 'react';
// import { Link } from 'react-router-dom';
import { Database, Plus, Trash2, ExternalLink } from 'lucide-react';
import { EmptyState } from '../components/EmptyState';
import { SearchInput } from '../components/SearchInput';
import { Pagination } from '../components/Pagination';
import { mockDatasets } from '../mockData';

const ITEMS_PER_PAGE = 6;

export default function DatasetsPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [currentPage, setCurrentPage] = useState(1);

  const filteredDatasets = useMemo(() => {
    return datasets.filter(dataset =>
      dataset.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      dataset.description.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [searchQuery]);

  const totalPages = Math.ceil(filteredDatasets.length / ITEMS_PER_PAGE);
  const paginatedDatasets = filteredDatasets.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  if (datasets.length === 0) {
    return (
      <div className="p-8">
        <EmptyState
          icon={Database}
          title="Create your first dataset"
          description="Create a dataset to start training your machine learning models"
          actionLabel="Create Dataset"
          onAction={() => {/* Handle dataset creation */}}
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
            to="/datasets/new"
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
                to="/datasets/new"
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
                        <h3 className="text-lg font-semibold text-gray-900">
                          {dataset.name}
                        </h3>
                        <p className="text-sm text-gray-500 mt-1">
                          {dataset.description}
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Link
                        to={`/datasets/${dataset.id}`}
                        className="text-gray-400 hover:text-blue-600 transition-colors"
                        title="View details"
                      >
                        <ExternalLink className="w-5 h-5" />
                      </Link>
                      <button
                        className="text-gray-400 hover:text-red-600 transition-colors"
                        title="Delete dataset"
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
                        {dataset.rowCount.toLocaleString()}
                      </p>
                    </div>
                  </div>

                  <div className="mt-4 pt-4 border-t border-gray-100">
                    <div className="flex flex-wrap gap-2">
                      {dataset.columns.slice(0, 3).map((column) => (
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