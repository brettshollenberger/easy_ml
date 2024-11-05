import React, { useState, useEffect } from 'react';
import { Database, Search, AlertCircle, ChevronDown, ChevronUp, Loader2 } from 'lucide-react';
import { SearchableSelect } from '../components/SearchableSelect';
import { useAlerts } from '../components/AlertProvider';
import { useInertiaForm } from 'use-inertia-form';
import { usePage } from '@inertiajs/react';
import type { Dataset, Props } from '../types/dataset';

export default function NewDatasetPage({ constants, datasources }: Props) {
  const [step, setStep] = useState(1);
  const [searchQuery, setSearchQuery] = useState('');
  const [showError, setShowError] = useState<number | null>(null);
  const { rootPath } = usePage().props;
  const [availableCols, setAvailableCols] = useState<string[]>([]);

  const form = useInertiaForm<Dataset>({
    dataset: {
      name: '',
      description: '',
      datasource_id: '',
      drop_cols: [],
      preprocessing_steps: {
        training: {}
      },
      splitter: {
        date: {
          date_col: '',
          months_test: 2,
          months_valid: 1
        }
      }
    }
  });

  const { data: formData, setData, post, processing } = form;

  const selectedDatasource = formData.dataset.datasource_id 
    ? datasources.find(d => d.id === Number(formData.dataset.datasource_id))
    : null;

  const isDatasourceReady = selectedDatasource && 
    !selectedDatasource.is_syncing && 
    !selectedDatasource.sync_error;

  const canProceedToStep2 = formData.dataset.name && isDatasourceReady;

  const handleDatasourceSelect = () => {
    if (!canProceedToStep2) return;
    
    if (selectedDatasource.columns) {
      setStep(2);
    } else {
      alert("Forgot to do this!");
    }
  };

  const handleSplitConfig = () => {
    setStep(3);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    console.log('Creating dataset:', formData);
  };

  useEffect(() => {
    if (selectedDatasource?.columns) {
      setAvailableCols(
        selectedDatasource.columns.filter(
          col => !formData.dataset.drop_cols.includes(col)
        )
      );
    }
  }, [selectedDatasource?.columns, formData.dataset.drop_cols]);

  return (
    <div className="max-w-2xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-6">
          Create New Dataset
        </h2>

        <div className="mb-8">
          <div className="flex items-center">
            <div
              className={`flex items-center justify-center w-8 h-8 rounded-full ${
                step >= 1 ? 'bg-blue-600' : 'bg-gray-200'
              } text-white font-medium text-sm`}
            >
              1
            </div>
            <div
              className={`flex-1 h-0.5 mx-2 ${
                step >= 2 ? 'bg-blue-600' : 'bg-gray-200'
              }`}
            />
            <div
              className={`flex items-center justify-center w-8 h-8 rounded-full ${
                step >= 2 ? 'bg-blue-600' : 'bg-gray-200'
              } text-white font-medium text-sm`}
            >
              2
            </div>
            <div
              className={`flex-1 h-0.5 mx-2 ${
                step >= 3 ? 'bg-blue-600' : 'bg-gray-200'
              }`}
            />
            <div
              className={`flex items-center justify-center w-8 h-8 rounded-full ${
                step >= 3 ? 'bg-blue-600' : 'bg-gray-200'
              } text-white font-medium text-sm`}
            >
              3
            </div>
          </div>
          <div className="flex justify-between mt-2">
            <span className="text-sm font-medium text-gray-600">
              Basic Info
            </span>
            <span className="text-sm font-medium text-gray-600">
              Select Columns
            </span>
            <span className="text-sm font-medium text-gray-600">
              Configure Split
            </span>
          </div>
        </div>

        {step === 1 ? (
          <div className="space-y-6">
            <div>
              <label
                htmlFor="name"
                className="block text-sm font-medium text-gray-700"
              >
                Dataset Name
              </label>
              <input
                type="text"
                id="name"
                value={formData.dataset.name}
                onChange={(e) => setData('dataset.name', e.target.value)}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
              />
            </div>

            <div>
              <label
                htmlFor="description"
                className="block text-sm font-medium text-gray-700"
              >
                Description
              </label>
              <textarea
                id="description"
                value={formData.dataset.description}
                onChange={(e) => setData('dataset.description', e.target.value)}
                rows={3}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>

            <div>
              <label
                htmlFor="datasource"
                className="block text-sm font-medium text-gray-700"
              >
                Datasource
              </label>
              <select
                id="datasource"
                value={formData.dataset.datasource_id}
                onChange={(e) => setData('dataset.datasource_id', e.target.value)}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
              >
                <option value="">Select a datasource</option>
                {datasources.map((source) => (
                  <option key={source.id} value={source.id}>
                    {source.name}
                  </option>
                ))}
              </select>
            </div>

            {selectedDatasource && (
              <div className={`rounded-lg p-4 ${
                selectedDatasource.sync_error 
                  ? 'bg-red-50' 
                  : selectedDatasource.is_syncing 
                    ? 'bg-blue-50'
                    : 'bg-green-50'
              }`}>
                <div className="flex items-start gap-2">
                  {selectedDatasource.is_syncing ? (
                    <>
                      <Loader2 className="w-5 h-5 text-blue-500 animate-spin" />
                      <div>
                        <h4 className="text-sm font-medium text-blue-800">
                          Datasource is syncing
                        </h4>
                        <p className="mt-1 text-sm text-blue-700">
                          Please wait while we sync your data. This may take a few minutes.
                        </p>
                      </div>
                    </>
                  ) : selectedDatasource.sync_error ? (
                    <>
                      <AlertCircle className="w-5 h-5 text-red-500" />
                      <div>
                        <h4 className="text-sm font-medium text-red-800">
                          Sync failed
                        </h4>
                        <p className="mt-1 text-sm text-red-700">
                          There was an error syncing your datasource.
                        </p>
                        <button
                          onClick={() => setShowError(selectedDatasource.id)}
                          className="mt-2 flex items-center gap-1 text-sm text-red-700 hover:text-red-800"
                        >
                          View error details
                          {showError === selectedDatasource.id ? (
                            <ChevronUp className="w-4 h-4" />
                          ) : (
                            <ChevronDown className="w-4 h-4" />
                          )}
                        </button>
                        {showError === selectedDatasource.id && (
                          <pre className="mt-2 p-2 text-xs text-red-700 bg-red-100 rounded-md whitespace-pre-wrap break-words font-mono max-h-32 overflow-y-auto">
                            {selectedDatasource.stacktrace}
                          </pre>
                        )}
                      </div>
                    </>
                  ) : (
                    <>
                      <Database className="w-5 h-5 text-green-500" />
                      <div>
                        <h4 className="text-sm font-medium text-green-800">
                          Datasource ready
                        </h4>
                        <p className="mt-1 text-sm text-green-700">
                          Your datasource is synced and ready to use.
                        </p>
                      </div>
                    </>
                  )}
                </div>
              </div>
            )}

            <div className="flex justify-end">
              <button
                type="button"
                onClick={handleDatasourceSelect}
                disabled={!canProceedToStep2}
                className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-300 disabled:cursor-not-allowed"
              >
                Next
              </button>
            </div>
          </div>
        ) : step === 2 ? (
          <div className="space-y-6">
            <div className="space-y-4">
              <div className="flex items-center justify-between pb-4 border-b border-gray-200">
                <span className="text-sm font-medium text-gray-700">
                  Column Name
                </span>
                <span className="text-sm font-medium text-gray-700">Include</span>
              </div>
              {selectedDatasource?.columns?.map((column, index) => {
                return (
                  <div
                    key={column}
                    className="flex items-center justify-between"
                  >
                    <span className="text-sm text-gray-900">{column}</span>
                    <input
                      type="checkbox"
                      checked={!formData.dataset.drop_cols?.includes(column)}
                      onChange={(e) => {
                        const newDropCols = !e.target.checked
                          ? [...(formData.dataset.drop_cols || []), column]
                          : (formData.dataset.drop_cols || []).filter(col => col !== column);
                        setData('dataset.drop_cols', newDropCols);
                      }}
                      className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                    />
                  </div>
                );
              })}
            </div>

            <div className="flex justify-between">
              <button
                type="button"
                onClick={() => setStep(1)}
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                Back
              </button>
              <button
                type="button"
                onClick={handleSplitConfig}
                className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Next
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="space-y-4">
              <div>
                <label
                  htmlFor="dateColumn"
                  className="block text-sm font-medium text-gray-700 mb-1"
                >
                  Date Column To Split On
                </label>
                <SearchableSelect
                  value={formData.dataset.splitter.date.date_col}
                  onChange={(value) => setData('dataset.splitter.date.date_col', value)}
                  options={availableCols.map(col => ({
                    value: col,
                    label: col
                  }))}
                  placeholder="Select a date column..."
                />
              </div>

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label
                    htmlFor="monthsTest"
                    className="block text-sm font-medium text-gray-700"
                  >
                    Test Set (months)
                  </label>
                  <input
                    type="number"
                    id="monthsTest"
                    min="1"
                    max="12"
                    value={formData.dataset.splitter.date.months_test}
                    onChange={(e) =>
                      setData('dataset.splitter.date.months_test', parseInt(e.target.value) || 0)
                    }
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label
                    htmlFor="monthsValid"
                    className="block text-sm font-medium text-gray-700"
                  >
                    Validation Set (months)
                  </label>
                  <input
                    type="number"
                    id="monthsValid"
                    min="1"
                    max="12"
                    value={formData.dataset.splitter.date.months_valid}
                    onChange={(e) =>
                      setData('dataset.splitter.date.months_valid', parseInt(e.target.value) || 0)
                    }
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>
              </div>
            </div>

            <div className="flex justify-between">
              <button
                type="button"
                onClick={() => setStep(2)}
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                Back
              </button>
              <button
                type="submit"
                disabled={!formData.dataset.splitter.date.date_col}
                className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-300 disabled:cursor-not-allowed"
              >
                Create Dataset
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}