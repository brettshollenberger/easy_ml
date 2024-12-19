import React, { useState, useEffect } from 'react';
import { Database, AlertCircle, ChevronDown, ChevronUp, Loader2 } from 'lucide-react';
import { SearchableSelect } from '../components/SearchableSelect';
import { useInertiaForm } from 'use-inertia-form';
import { usePage, router } from '@inertiajs/react';
import type { Datasource } from '../types/datasource';
import type { 
  NewDatasetForm, 
  NewDatasetFormProps, 
  SplitterType, 
  SplitConfig,
  DateSplitConfig,
  RandomSplitConfig,
  PredefinedSplitConfig,
  StratifiedSplitConfig,
  KFoldConfig,
  LeavePOutConfig,
  ColumnConfig
} from '../components/dataset/splitters/types';
import { SplitConfigurator } from '../components/dataset/SplitConfigurator';
import { validateSplitterConfig } from '../components/dataset/splitters/types';

export default function NewDatasetPage({ constants, datasources }: NewDatasetFormProps) {
  const [step, setStep] = useState(1);
  const [showError, setShowError] = useState<number | null>(null);
  const [selectedSplitterType, setSelectedSplitterType] = useState<SplitterType>('random');
  const { rootPath } = usePage().props;

  const getDefaultConfig = (type: SplitterType): SplitConfig => {
    switch (type) {
      case 'date':
        const dateConfig: DateSplitConfig = {
          date_column: '',
          months_test: 2,
          months_valid: 2
        };
        return dateConfig;
      case 'random':
        const randomConfig: RandomSplitConfig = {};
        return randomConfig;
      case 'predefined':
        const predefinedConfig: PredefinedSplitConfig = {
          train_files: [],
          test_files: [],
          valid_files: []
        };
        return predefinedConfig;
      case 'stratified':
        const stratifiedConfig: StratifiedSplitConfig = {
          stratify_column: '',
          train_ratio: 0.6,
          test_ratio: 0.2,
          valid_ratio: 0.2
        };
        return stratifiedConfig;
      case 'stratified_kfold':
      case 'group_kfold':
        const kfoldConfig: KFoldConfig = {
          target_column: '',
          group_column: '',
          n_splits: 5
        };
        return kfoldConfig;
      case 'leave_p_out':
        const lpoConfig: LeavePOutConfig = {
          p: 1,
          shuffle: true,
          random_state: 42
        };
        return lpoConfig;
      default:
        const defaultConfig: RandomSplitConfig = {};
        return defaultConfig;
    }
  };
  
  const form = useInertiaForm<NewDatasetForm>({
    dataset: {
      name: '',
      datasource_id: '',
      splitter_attributes: {
        splitter_type: selectedSplitterType,
        ...getDefaultConfig(selectedSplitterType)
      }
    }
  });

  // Update form when splitter type changes
  useEffect(() => {
    form.setData('dataset.splitter_attributes', {
      splitter_type: selectedSplitterType,
      ...getDefaultConfig(selectedSplitterType)
    });
  }, [selectedSplitterType]);

  const handleSplitterChange = (type: SplitterType, attributes: SplitConfig) => {
    setSelectedSplitterType(type);
    form.setData('dataset.splitter_attributes', {
      splitter_type: type,
      ...attributes
    });
  };
  console.log(form.dataset?.splitter_attributes)

  const { data: formData, setData, post } = form;

  const selectedDatasource = formData.dataset.datasource_id 
    ? datasources.find(d => d.id === Number(formData.dataset.datasource_id))
    : null;

  const availableCols: ColumnConfig[] = (selectedDatasource?.columns || []).map(col => ({
    name: col,
    type: (selectedDatasource?.schema || {})[col] || ''
  }));

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

  const getValidationError = (): string | undefined => {
    if (!formData.dataset.name) {
      return "Please enter a dataset name";
    }
    if (!formData.dataset.datasource_id) {
      return "Please select a datasource";
    }
    
    const splitterValidation = validateSplitterConfig(
      formData.dataset.splitter_attributes.splitter_type,
      formData.dataset.splitter_attributes
    );
    
    return splitterValidation.error;
  };

  const isFormValid = () => {
    return !getValidationError();
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
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 py-2 px-4 shadow-sm border-gray-300 border"
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
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 py-2 px-4 shadow-sm border-gray-300 border"
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
            <SplitConfigurator
              type={selectedSplitterType}
              splitter_attributes={form.data.dataset.splitter_attributes}
              columns={availableCols}
              available_files={selectedDatasource.available_files}
              onChange={handleSplitterChange}
            />

            {getValidationError() && (
              <div className="mt-2 text-sm text-red-600">
                {getValidationError()}
              </div>
            )}

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
                disabled={!isFormValid()}
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