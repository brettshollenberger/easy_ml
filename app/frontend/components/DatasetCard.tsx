import React from 'react';
import { Link } from '@inertiajs/react';
import { Database, Trash2, ExternalLink, Loader2, AlertCircle, ChevronDown, ChevronUp, RefreshCw, XCircle, Download, Upload } from 'lucide-react';
import { Dataset, DatasetWorkflowStatus, Column } from "@types/dataset";
import { StackTrace } from './StackTrace';

interface Props {
  dataset: Dataset;
  rootPath: string;
  onDelete: (id: number) => void;
  onRefresh: (id: number) => void;
  onAbort: (id: number) => void;
  isErrorExpanded: boolean;
  onToggleError: (id: number) => void;
}

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

export function DatasetCard({
  dataset,
  rootPath,
  onDelete,
  onRefresh,
  onAbort,
  isErrorExpanded,
  onToggleError
}: Props) {
  // Create a hidden file input for handling uploads
  const fileInputRef = React.useRef<HTMLInputElement>(null);

  const handleDownload = () => {
    window.location.href = `${rootPath}/datasets/${dataset.id}/download`;
  };

  const handleUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('config', file);

    fetch(`${rootPath}/datasets/${dataset.id}/upload`, {
      method: 'POST',
      body: formData,
      credentials: 'same-origin',
      headers: {
        'X-CSRF-Token': document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || '',
      },
    }).then(response => {
      if (response.ok) {
        window.location.reload();
      } else {
        console.error('Upload failed');
      }
    });
  };

  return (
    <div className="bg-white rounded-lg shadow-md p-6 hover:shadow-lg transition-shadow">
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
            onClick={() => onRefresh(dataset.id)}
            disabled={dataset.workflow_status === 'analyzing'}
            className={`transition-colors ${
              dataset.workflow_status === 'analyzing'
                ? 'text-gray-300 cursor-not-allowed'
                : 'text-gray-400 hover:text-blue-600'
            }`}
            title={dataset.workflow_status === 'analyzing' ? 'Dataset is being analyzed' : 'Refresh dataset'}
          >
            <RefreshCw className="w-5 h-5" />
          </button>
          {dataset.workflow_status === 'analyzing' && (
            <button
              onClick={() => onAbort(dataset.id)}
              className="text-gray-400 hover:text-red-600 transition-colors"
              title="Abort analysis"
            >
              <XCircle className="w-5 h-5" />
            </button>
          )}
          <button
            onClick={handleDownload}
            className="text-gray-400 hover:text-blue-600 transition-colors"
            title="Download dataset configuration"
          >
            <Download className="w-5 h-5" />
          </button>
          <button
            onClick={() => fileInputRef.current?.click()}
            className="text-gray-400 hover:text-green-600 transition-colors"
            title="Upload dataset configuration"
          >
            <Upload className="w-5 h-5" />
          </button>
          <input
            type="file"
            ref={fileInputRef}
            onChange={handleUpload}
            accept=".json"
            className="hidden"
          />
          <button
            className="text-gray-400 hover:text-red-600 transition-colors"
            title="Delete dataset"
            onClick={() => onDelete(dataset.id)}
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
            onClick={() => onToggleError(dataset.id)}
            className="flex items-center gap-2 text-sm text-red-600 hover:text-red-700"
          >
            <AlertCircle className="w-4 h-4" />
            <span>View Error Details</span>
            {isErrorExpanded ? (
              <ChevronUp className="w-4 h-4" />
            ) : (
              <ChevronDown className="w-4 h-4" />
            )}
          </button>
          {isErrorExpanded && (
            <StackTrace stacktrace={dataset.stacktrace} />
          )}
        </div>
      )}
    </div>
  );
}
