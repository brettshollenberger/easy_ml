import React, { useState, useEffect } from 'react';
import { TrainFront, Lock, AlertCircle } from 'lucide-react';
import { SearchableSelect } from './SearchableSelect';
import { ScheduleModal } from './ScheduleModal';
import { router } from '@inertiajs/react';
import { useInertiaForm } from 'use-inertia-form';
import { usePage } from '@inertiajs/react';
import type { Dataset } from '../types';

interface ModelFormProps {
  initialData?: {
    id: number;
    name: string;
    modelType: string;
    datasetId: number;
    task: string;
    objective?: string;
    metrics?: string[];
    weights_column?: string;
    retraining_job?: {
      frequency: string;
      at: {
        hour: number;
        day_of_week?: string;
        day_of_month?: number;
      };
      batch_mode?: string;
      batch_size?: number;
      batch_overlap?: number;
      batch_key?: string;
      tuning_frequency?: string;
      active: boolean;
      metric?: string;
      threshold?: number;
      tuner_config?: {
        n_trials: number;
        objective: string;
        config: Record<string, any>;
      };
      tuning_enabled?: boolean;
    };
  };
  datasets: Array<Dataset>;
  constants: {
    tasks: { value: string; label: string }[];
    objectives: Record<string, { value: string; label: string; description?: string }[]>;
    metrics: Record<string, { value: string; label: string; direction: string }[]>;
    timezone: string;
    retraining_job_constants: any;
    tuner_job_constants: any;
  };
  isEditing?: boolean;
  errors?: any;
}

const ErrorDisplay = ({ error }: { error?: string }) => (
  error ? (
    <div className="mt-1 flex items-center gap-1 text-sm text-red-600">
      <AlertCircle className="w-4 h-4" />
      {error}
    </div>
  ) : null
);

export function ModelForm({ initialData, datasets, constants, isEditing, errors: initialErrors }: ModelFormProps) {
  const { rootPath } = usePage().props;
  const [showScheduleModal, setShowScheduleModal] = useState(false);
  const [isDataSet, setIsDataSet] = useState(false);

  const form = useInertiaForm({
    model: {
      id: initialData?.id,
      name: initialData?.name || '',
      model_type: initialData?.model_type || 'xgboost',
      dataset_id: initialData?.dataset_id || '',
      task: initialData?.task || 'classification',
      objective: initialData?.objective || 'binary:logistic',
      metrics: initialData?.metrics || ['accuracy_score'],
      weights_column: initialData?.weights_column || '',
      retraining_job_attributes: initialData?.retraining_job ? {
        id: initialData.retraining_job.id,
        frequency: initialData.retraining_job.frequency,
        tuning_frequency: initialData.retraining_job.tuning_frequency || 'month',
        batch_mode: initialData.retraining_job.batch_mode,
        batch_size: initialData.retraining_job.batch_size,
        batch_overlap: initialData.retraining_job.batch_overlap,
        batch_key: initialData.retraining_job.batch_key,
        at: {
          hour: initialData.retraining_job.at?.hour ?? 2,
          day_of_week: initialData.retraining_job.at?.day_of_week ?? 1,
          day_of_month: initialData.retraining_job.at?.day_of_month ?? 1
        },
        active: initialData.retraining_job.active,
        metric: initialData.retraining_job.metric,
        threshold: initialData.retraining_job.threshold,
        tuner_config: initialData.retraining_job.tuner_config,
        tuning_enabled: initialData.retraining_job.tuning_enabled || false,
      } : undefined
    }
  });

  const { data, setData, post, patch, processing, errors: formErrors } = form;
  const errors = { ...initialErrors, ...formErrors };

  const objectives: { value: string; label: string; description?: string }[] = 
    constants.objectives[data.model.model_type]?.[data.model.task] || [];

  useEffect(() => {
    if (isDataSet) {
      save();
      setIsDataSet(false); // Reset the flag
    }
  }, [isDataSet]);

  const handleScheduleSave = (scheduleData: any) => {
    setData({
      ...data,
      model: {
        ...data.model,
        retraining_job_attributes: scheduleData.retraining_job_attributes
      }
    });
    setIsDataSet(true);
  };

  const save = () => {
    if (data.model.retraining_job_attributes) {
      const at: any = { hour: data.model.retraining_job_attributes.at.hour };
      
      // Only include relevant date attributes based on frequency
      switch (data.model.retraining_job_attributes.frequency) {
        case 'day':
          // For daily frequency, only include hour
          break;
        case 'week':
          // For weekly frequency, include hour and day_of_week
          at.day_of_week = data.model.retraining_job_attributes.at.day_of_week;
          break;
        case 'month':
          // For monthly frequency, include hour and day_of_month
          at.day_of_month = data.model.retraining_job_attributes.at.day_of_month;
          break;
      }

      // Update the form data with the cleaned at object
      setData('model.retraining_job_attributes.at', at);
    }

    if (data.model.id) {
      patch(`${rootPath}/models/${data.model.id}`, {
        onSuccess: () => {
          router.visit(`${rootPath}/models`);
        },
      });
    } else {
      post(`${rootPath}/models`, {
        onSuccess: () => {
          router.visit(`${rootPath}/models`);
        },
      });
    }
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    save();
  };

  const selectedDataset = datasets.find(d => d.id === data.model.dataset_id);
  const columns = selectedDataset?.columns || [];

  const filteredTunerJobConstants = constants.tuner_job_constants[data.model.model_type] || {};

  const handleTaskChange = (value: string) => {
    // First update the task
    setData('model.task', value);
    
    // Then force reset metrics to empty array
    setData('model.metrics', []);

    // Update objective based on new task
    setData('model.objective', value === 'classification' ? 'binary:logistic' : 'reg:squarederror');
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-8">
      <div className="flex justify-between items-center border-b pb-4">
        <h3 className="text-lg font-medium text-gray-900">Model Configuration</h3>
        <button
          type="button"
          onClick={() => setShowScheduleModal(true)}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <TrainFront className="w-4 h-4" />
          Configure Training
        </button>
      </div>

      <div className="space-y-6">
        <div className="grid grid-cols-2 gap-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
              Model Name
            </label>
            <input
              type="text"
              id="name"
              value={data.model.name}
              onChange={(e) => setData('model.name', e.target.value)}
              className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 py-2 px-4 shadow-sm border-gray-300 border"
            />
            <ErrorDisplay error={errors.name} />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Model Type
            </label>
            <SearchableSelect
              options={[{ value: 'xgboost', label: 'XGBoost', description: 'Gradient boosting framework' }]}
              value={data.model.model_type}
              onChange={(value) => setData('model.model_type', value as string)}
              placeholder="Select model type"
            />
            <ErrorDisplay error={errors.model_type} />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Dataset
            </label>
            {isEditing ? (
              <div className="flex items-center gap-2 p-2 bg-gray-50 rounded-md border border-gray-200">
                <Lock className="w-4 h-4 text-gray-400" />
                <span className="text-gray-700">{selectedDataset?.name}</span>
              </div>
            ) : (
              <SearchableSelect
                options={datasets.map(dataset => ({
                  value: dataset.id,
                  label: dataset.name,
                  description: `${dataset.num_rows.toLocaleString()} rows`
                }))}
                value={data.model.dataset_id}
                onChange={(value) => setData('model.dataset_id', value)}
                placeholder="Select dataset"
              />
            )}
            <ErrorDisplay error={errors.dataset_id} />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Weights Column (Optional)
            </label>
            <SearchableSelect
              value={data.model.weights_column}
              options={columns.map(col => ({ value: col.name, label: col.name }))}
              onChange={(value) => setData('model.weights_column', value)}
              isClearable={true}
            />
            <ErrorDisplay error={errors.weights_column} />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Task
            </label>
            <SearchableSelect
              options={constants.tasks}
              value={data.model.task}
              onChange={handleTaskChange}
            />
            <ErrorDisplay error={errors.task} />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Objective
            </label>
            <SearchableSelect
              options={objectives || []}
              value={data.model.objective}
              onChange={(value) => setData('model.objective', value as string)}
              placeholder="Select objective"
            />
            <ErrorDisplay error={errors.objective} />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Metrics
          </label>
          <div className="grid grid-cols-2 gap-4">
            {constants.metrics[data.model.task]?.map(metric => (
              <label
                key={metric.value}
                className="relative flex items-center px-4 py-3 bg-white border rounded-lg hover:bg-gray-50 cursor-pointer"
              >
                <input
                  type="checkbox"
                  checked={data.model.metrics.includes(metric.value)}
                  onChange={(e) => {
                    const newMetrics = e.target.checked
                      ? [...data.model.metrics, metric.value]
                      : data.model.metrics.filter(m => m !== metric.value);
                    setData('model.metrics', newMetrics);
                  }}
                  className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                />
                <div className="ml-3">
                  <span className="block text-sm font-medium text-gray-900">{metric.label}</span>
                  <span className="block text-xs text-gray-500">Direction: {metric.direction}</span>
                </div>
              </label>
            ))}
          </div>
          <ErrorDisplay error={errors.metrics} />
        </div>
      </div>

      {data.model.retraining_job_attributes && data.model.retraining_job_attributes.batch_mode && (
        <>
          <div className="mt-4">
            <label className="block text-sm font-medium text-gray-700">
              Batch Key
            </label>
            <SearchableSelect
              value={data.model.retraining_job_attributes.batch_key || ''}
              onChange={(value) => setData('model', {
                ...data.model,
                retraining_job_attributes: {
                  ...data.model.retraining_job_attributes,
                  batch_key: value
                }
              })}
              options={selectedDataset?.columns?.map(column => ({
                value: column.name,
                label: column.name
              })) || []}
              placeholder="Select a column for batch key"
            />
            <ErrorDisplay error={errors['model.retraining_job_attributes.batch_key']} />
          </div>
        </>
      )}

      <div className="flex justify-end gap-3 pt-4 border-t">
        <button
          type="button"
          onClick={() => router.visit(`${rootPath}/models`)}
          className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
        >
          Cancel
        </button>
        <button
          type="submit"
          className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          {isEditing ? 'Save Changes' : 'Create Model'}
        </button>
      </div>

      <ScheduleModal
        isOpen={showScheduleModal}
        onClose={() => setShowScheduleModal(false)}
        onSave={handleScheduleSave}
        initialData={{
          task: data.model.task,
          metrics: data.model.metrics,
          modelType: data.model.model_type,
          dataset: selectedDataset,
          retraining_job: data.model.retraining_job_attributes
        }}
        metrics={constants.metrics}
        tunerJobConstants={filteredTunerJobConstants}
        timezone={constants.timezone}
        retrainingJobConstants={constants.retraining_job_constants}
      />
    </form>
  );
}