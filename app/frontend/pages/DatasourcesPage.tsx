import React, { useState, useMemo } from 'react';
// import { Link } from 'react-router-dom';
import { HardDrive, Plus, Trash2, Settings } from 'lucide-react';
import { EmptyState } from '../components/EmptyState';
import { SearchInput } from '../components/SearchInput';
import { Pagination } from '../components/Pagination';

const ITEMS_PER_PAGE = 6;

const mockDatasources = [
  {
    id: 1,
    name: 'Customer Data Lake',
    type: 's3',
    bucket: 'customer-data-lake',
    prefix: 'raw/customers/',
    region: 'us-east-1',
    lastSync: '2024-03-10T15:30:00Z',
    status: 'active',
  },
  {
    id: 2,
    name: 'Product Analytics',
    type: 's3',
    bucket: 'analytics-warehouse',
    prefix: 'product/events/',
    region: 'us-west-2',
    lastSync: '2024-03-09T12:00:00Z',
    status: 'active',
  },
];

export function DatasourcesPage() {
  const [searchQuery, setSearchQuery] = useState('');
  const [currentPage, setCurrentPage] = useState(1);

  const filteredDatasources = useMemo(() => {
    return mockDatasources.filter(source =>
      source.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      source.bucket.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [searchQuery]);

  const totalPages = Math.ceil(filteredDatasources.length / ITEMS_PER_PAGE);
  const paginatedDatasources = filteredDatasources.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  if (mockDatasources.length === 0) {
    return (
      <div className="p-8">
        <EmptyState
          icon={HardDrive}
          title="Connect your first data source"
          description="Connect to your data sources to start creating datasets and training models"
          actionLabel="Add Datasource"
          onAction={() => {/* Handle datasource creation */}}
        />
      </div>
    );
  }

  return (
    <div className="p-8">
      <div className="space-y-6">
        <div className="flex justify-between items-center">
          <div className="flex items-center gap-4">
            <h2 className="text-xl font-semibold text-gray-900">Datasources</h2>
            <SearchInput
              value={searchQuery}
              onChange={setSearchQuery}
              placeholder="Search datasources..."
            />
          </div>
          <Link
            to="/datasources/new"
            className="inline-flex items-center gap-2 px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <Plus className="w-4 h-4" />
            New Datasource
          </Link>
        </div>

        {paginatedDatasources.length === 0 ? (
          <div className="text-center py-12 bg-white rounded-lg shadow">
            <HardDrive className="mx-auto h-12 w-12 text-gray-400" />
            <h3 className="mt-2 text-sm font-medium text-gray-900">No datasources found</h3>
            <p className="mt-1 text-sm text-gray-500">
              No datasources match your search criteria. Try adjusting your search or add a new datasource.
            </p>
            <div className="mt-6">
              <Link
                to="/datasources/new"
                className="inline-flex items-center px-4 py-2 border border-transparent shadow-sm text-sm font-medium rounded-md text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                <Plus className="w-4 h-4 mr-2" />
                New Datasource
              </Link>
            </div>
          </div>
        ) : (
          <>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {paginatedDatasources.map((datasource) => (
                <div
                  key={datasource.id}
                  className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow"
                >
                  <div className="flex justify-between items-start mb-4">
                    <div className="flex items-start gap-3">
                      <HardDrive className="w-5 h-5 text-blue-600 mt-1" />
                      <div>
                        <h3 className="text-lg font-semibold text-gray-900">
                          {datasource.name}
                        </h3>
                        <p className="text-sm text-gray-500 mt-1">
                          s3://{datasource.bucket}/{datasource.prefix}
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Link
                        to={`/datasources/${datasource.id}/edit`}
                        className="text-gray-400 hover:text-blue-600 transition-colors"
                        title="Edit datasource"
                      >
                        <Settings className="w-5 h-5" />
                      </Link>
                      <button
                        className="text-gray-400 hover:text-red-600 transition-colors"
                        title="Delete datasource"
                      >
                        <Trash2 className="w-5 h-5" />
                      </button>
                    </div>
                  </div>

                  <div className="grid grid-cols-2 gap-4 mt-4">
                    <div>
                      <span className="text-sm text-gray-500">Region</span>
                      <p className="text-sm font-medium text-gray-900">
                        {datasource.region}
                      </p>
                    </div>
                    <div>
                      <span className="text-sm text-gray-500">Last Sync</span>
                      <p className="text-sm font-medium text-gray-900">
                        {new Date(datasource.lastSync).toLocaleString()}
                      </p>
                    </div>
                  </div>

                  <div className="mt-4 pt-4 border-t border-gray-100">
                    <span
                      className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium ${
                        datasource.status === 'active'
                          ? 'bg-green-100 text-green-800'
                          : 'bg-gray-100 text-gray-800'
                      }`}
                    >
                      {datasource.status}
                    </span>
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