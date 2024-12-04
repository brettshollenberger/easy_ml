import React, { useState, useEffect } from 'react';
import { Database, AlertCircle, ChevronDown, ChevronUp, Loader2 } from 'lucide-react';
import { SearchableSelect } from '../components/SearchableSelect';
import { useInertiaForm } from 'use-inertia-form';
import { usePage, router } from '@inertiajs/react';
import type { NewDatasetForm, NewDatasetFormProps } from '../types/dataset';

export default function NewDatasetPage({ constants, datasources }: NewDatasetFormProps) {
  const [step, setStep] = useState(1);
  const [showError, setShowError] = useState<number | null>(null);
  const { rootPath } = usePage().props;

  const form = useInertiaForm<NewDatasetForm>({
    dataset: {
      name: '',
      description: '',
      datasource_id: undefined,
      splitter_attributes: {
        splitter_type: 'date',
        date_col: '',
        months_test: 2,
        months_valid: 2
      }
    }
  });

  const { data: formData, setData, post } = form;

  const selectedDatasource = formData.dataset.datasource_id 
    ? datasources.find(d => d.id === Number(formData.dataset.datasource_id))
    : null;

  const availableCols = selectedDatasource?.columns || [];

  const isDatasourceReady = selectedDatasource && 
    !selectedDatasource.is_syncing && 
    !selectedDatasource.sync_error;

  const canProceedToStep2 = formData.dataset.name && isDatasourceReady;

  const handleDatasourceSelect = () => {
    if (!canProceedToStep2) return;
    setStep(2);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    post(`${rootPath}/datasets`, {
      onSuccess: () => {
        router.visit(`${rootPath}/datasets`);
      },
      onError: (errors) => {
        console.error('Failed to create dataset:', errors);
      }
    });
  };

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
          </div>
          <div className="flex justify-between mt-2">
            <span className="text-sm font-medium text-gray-600">
              Basic Info
            </span>
            <span className="text-sm font-medium text-gray-600 mr-4">
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
                className="block text-sm font-medium text-gray-700 mb-1"
              >
                Datasource
              </label>
              <SearchableSelect
                value={formData.dataset.datasource_id}
                onChange={(value) => setData('dataset.datasource_id', value)}
                options={datasources.map(datasource => ({
                  value: datasource.id,
                  label: datasource.name
                }))}
                placeholder="Select a datasource..."
              />
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
                  value={formData?.dataset?.splitter_attributes?.date_col || null}
                  onChange={(value) => setData('dataset.splitter_attributes.date_col', value)}
                  options={availableCols.filter(col => {
                    return selectedDatasource?.schema[col] === 'datetime'
                  }).map(col => ({
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
                    value={formData.dataset.splitter_attributes.months_test}
                    onChange={(e) =>
                      setData('dataset.splitter_attributes.months_test', parseInt(e.target.value) || 0)
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
                    value={formData.dataset.splitter_attributes.months_valid}
                    onChange={(e) =>
                      setData('dataset.splitter_attributes.months_valid', parseInt(e.target.value) || 0)
                    }
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>
              </div>
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
                type="submit"
                disabled={!formData.dataset.splitter_attributes.date_col}
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