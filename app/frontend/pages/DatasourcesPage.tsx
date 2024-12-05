import React, { useState, useMemo, useEffect } from 'react';
import { Link, usePage, router } from '@inertiajs/react';
import { HardDrive, Plus, Trash2, Settings, RefreshCw, ChevronDown, ChevronUp, AlertCircle } from 'lucide-react';
import { EmptyState } from '../components/EmptyState';
import { SearchInput } from '../components/SearchInput';
import { Pagination } from '../components/Pagination';
import type { Datasource } from '../types/datasource';
import { Badge } from "@/components/ui/badge";

const ITEMS_PER_PAGE = 6;

export default function DatasourcesPage({ datasources }: { datasources: Datasource[] }) {
  const { rootPath } = usePage().props;
  const [searchQuery, setSearchQuery] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [expandedErrors, setExpandedErrors] = useState<number[]>([]);

  const filteredDatasources = useMemo(() => {
    return datasources.filter(source =>
      source.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      source.s3_bucket.toLowerCase().includes(searchQuery.toLowerCase())
    );
  }, [searchQuery, datasources]);

  const totalPages = Math.ceil(filteredDatasources.length / ITEMS_PER_PAGE);
  const paginatedDatasources = filteredDatasources.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  const handleDelete = (datasourceId: number) => {
    if (confirm('Are you sure you want to delete this datasource? This action cannot be undone.')) {
      router.delete(`${rootPath}/datasources/${datasourceId}`);
    }
  };

  const toggleError = (id: number) => {
    setExpandedErrors(prev =>
      prev.includes(id)
        ? prev.filter(expandedId => expandedId !== id)
        : [...prev, id]
    );
  };

  const handleSync = async (id: number) => {
    try {
      router.post(`${rootPath}/datasources/${id}/sync`, {}, {
        preserveScroll: true, // Keeps the scroll position
        preserveState: true,  // Keeps the form state
        onSuccess: () => {
          // The page will automatically refresh with new data
        },
        onError: () => {
          // Handle error case if needed
          console.error('Failed to sync datasource');
        }
      });
    } catch (error) {
      console.error('Failed to sync datasource:', error);
    }
  };

  const formatLastSyncedAt = (lastSyncedAt: string) => {
    if (lastSyncedAt === 'Not Synced') return lastSyncedAt;
    
    const date = new Date(lastSyncedAt);
    return isNaN(date.getTime()) ? lastSyncedAt : date.toLocaleString();
  };

  useEffect(() => {
    let pollInterval: number | undefined;

    // Check if any datasource is syncing
    const isAnySyncing = datasources.some(d => d.is_syncing);

    if (isAnySyncing) {
      // Start polling every 5 seconds
      pollInterval = window.setInterval(() => {
        router.get(window.location.href, {}, {
          preserveScroll: true,
          preserveState: true,
          only: ['datasources']
        });
      }, 2000);
    }

    // Cleanup function
    return () => {
      if (pollInterval) {
        window.clearInterval(pollInterval);
      }
    };
  }, [datasources]);

  if (datasources.length === 0) {
    return (
      <div className="p-8">
        <EmptyState
          icon={HardDrive}
          title="Connect your first data source"
          description="Connect to your data sources to start creating datasets and training models"
          actionLabel="Add Datasource"
          onAction={() => { router.visit(`${rootPath}/datasources/new`) }}
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
            href={`${rootPath}/datasources/new`}
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
                href={`${rootPath}/datasources/new`}
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
                        <div className="flex items-center gap-2">
                          <h3 className="text-lg font-semibold text-gray-900">
                            {datasource.name}
                          </h3>
                          {datasource.is_syncing ? (
                            <Badge variant="warning">syncing</Badge>
                          ) : datasource.sync_error ? (
                            <Badge variant="important">sync error</Badge>
                          ) : datasource.last_synced_at !== 'Not Synced' ? (
                            <Badge variant="success">synced</Badge>
                          ) : (
                            <Badge variant="warning">not synced</Badge>
                          )}
                        </div>
                        <p className="text-sm text-gray-500 mt-1">
                          s3://{datasource.s3_bucket}/{datasource.s3_prefix}
                        </p>
                      </div>
                    </div>
                    <div className="flex gap-2">
                    <button
                        onClick={() => handleSync(datasource.id)}
                        disabled={datasource.is_syncing}
                        className={`text-gray-400 hover:text-blue-600 transition-colors ${
                          datasource.is_syncing ? 'animate-spin' : ''
                        }`}
                        title="Sync datasource"
                      >
                        <RefreshCw className="w-5 h-5" />
                      </button>
                      <Link
                        href={`${rootPath}/datasources/${datasource.id}/edit`}
                        className="text-gray-400 hover:text-blue-600 transition-colors"
                        title="Edit datasource"
                      >
                        <Settings className="w-5 h-5" />
                      </Link>
                      <button
                        onClick={() => handleDelete(datasource.id)}
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
                        {datasource.s3_region}
                      </p>
                    </div>
                    <div>
                      <span className="text-sm text-gray-500">Last Sync</span>
                      <p className="text-sm font-medium text-gray-900">
                        {formatLastSyncedAt(datasource.last_synced_at)}
                      </p>
                    </div>
                  </div>

                  {datasource.sync_error && datasource.stacktrace && (
                    <div className="mt-4 pt-4 border-t border-gray-100">
                      <button
                        onClick={() => toggleError(datasource.id)}
                        className="flex items-center gap-2 text-sm text-red-600 hover:text-red-700"
                      >
                        <AlertCircle className="w-4 h-4" />
                        <span>View Error Details</span>
                        {expandedErrors.includes(datasource.id) ? (
                          <ChevronUp className="w-4 h-4" />
                        ) : (
                          <ChevronDown className="w-4 h-4" />
                        )}
                      </button>
                      {expandedErrors.includes(datasource.id) && (
                        <div className="mt-2 p-3 bg-red-50 rounded-md">
                          <pre className="text-xs text-red-700 whitespace-pre-wrap font-mono">
                            {datasource.stacktrace}
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