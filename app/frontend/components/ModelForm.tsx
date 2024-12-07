import React, { useState, useEffect } from 'react';
// import { useNavigate } from 'react-router-dom';
import { Calendar, Lock, AlertCircle } from 'lucide-react';
import { SearchableSelect } from './SearchableSelect';
import { ScheduleModal } from './ScheduleModal';
import { router } from '@inertiajs/react';
import { useInertiaForm } from 'use-inertia-form';
import { usePage } from '@inertiajs/react';
import type { Dataset } from '../types';

interface ModelFormProps {
  initialData?: {
    name: string;
    modelType: string;
    datasetId: number;
    task: string;
    objective?: string;
    metrics?: string[];
  };
  datasets: Array<Dataset>;
  constants: {
    tasks: { value: string; label: string }[];
    objectives: Record<string, { value: string; label: string; description?: string }[]>;
    metrics: Record<string, { value: string; label: string; direction: string }[]>;
    timezone: string;
    training_schedule: any;
    hyperparameter_tuning: any;
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

  const form = useInertiaForm({
    model: {
      name: initialData?.name || '',
      model_type: initialData?.modelType || 'xgboost',
      dataset_id: initialData?.datasetId || '',
      task: initialData?.task || 'classification',
      objective: initialData?.objective || 'binary:logistic',
      metrics: initialData?.metrics || ['accuracy'],
      retraining_job_attributes: {
        frequency: constants.training_schedule.frequency,
        at: constants.training_schedule.at,
        active: true,
        tuner_config: {
          n_trials: constants.hyperparameter_tuning.n_trials,
          objective: constants.hyperparameter_tuning.objective,
          config: constants.hyperparameter_tuning.config
        }
      }
    }
  });

  const { data, setData, post, processing, errors: formErrors } = form;
  const errors = { ...initialErrors, ...formErrors };

  const objectives: { value: string; label: string; description?: string }[] = 
    constants.objectives[data.model.model_type]?.[data.model.task] || [];

  useEffect(() => {
    const availableMetrics = constants.metrics[data.model.task]?.map(metric => metric.value) || [];
    setData({
      ...data,
      model: {
        ...data.model,
        objective: data.model.task === 'classification' ? 'binary:logistic' : 'reg:squarederror',
        metrics: availableMetrics
      }
    });
  }, [data.model.task]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    // Create a copy of the data to modify
    const submissionData = { ...data };
    
    // If training schedule is not enabled, remove retraining_job_attributes
    if (!submissionData.model.retraining_job_attributes?.active) {
      delete submissionData.model.retraining_job_attributes;
    }
    
    post(`${rootPath}/models`, submissionData, {
      onSuccess: () => {
        router.visit(`${rootPath}/models`);
      },
      onError: () => {
        // Handle errors, e.g., show error messages
      }
    });
  };

  const selectedDataset = datasets.find(d => d.id === data.model.dataset_id);

  const filteredHyperparameterConstants = constants.hyperparameter_tuning[data.model.model_type] || {};

  return (
    <form onSubmit={handleSubmit} className="space-y-8">
      <div className="flex justify-between items-center border-b pb-4">
        <h3 className="text-lg font-medium text-gray-900">Model Configuration</h3>
        <button
          type="button"
          onClick={() => setShowScheduleModal(true)}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <Calendar className="w-4 h-4" />
          Configure Schedule
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
              Task
            </label>
            <SearchableSelect
              options={constants.tasks}
              value={data.model.task}
              onChange={(value) => setData('model.task', value as string)}
              placeholder="Select task"
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
                    const metrics = e.target.checked
                      ? [...data.model.metrics, metric.value]
                      : data.model.metrics.filter(m => m !== metric.value);
                    setData('model.metrics', metrics);
                  }}
                  className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <div className="ml-3">
                  <span className="block text-sm font-medium text-gray-900">
                    {metric.label}
                  </span>
                  <span className="block text-xs text-gray-500">
                    {metric.direction === 'maximize' ? 'Higher is better' : 'Lower is better'}
                  </span>
                </div>
              </label>
            ))}
          </div>
        </div>
      </div>

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
        onSave={(scheduleData) => {
          const updatedData = {
            model: {
              ...data.model,
              retraining_job_attributes: scheduleData.trainingSchedule.enabled ? {
                frequency: scheduleData.trainingSchedule.frequency,
                at: scheduleData.trainingSchedule.at,
                active: scheduleData.trainingSchedule.enabled,
                metric: scheduleData.evaluator.metric,
                direction: scheduleData.evaluator.direction,
                threshold: scheduleData.evaluator.threshold,
                tuner_config: scheduleData.tuningSchedule.enabled ? {
                  n_trials: scheduleData.tuningSchedule.trials,
                  config: scheduleData.tuningSchedule.parameters
                } : undefined
              } : undefined
            }
          };
          setData(updatedData);
          setShowScheduleModal(false);
        }}
        initialData={{
          task: data.model.task,
          metrics: data.model.metrics
        }}
        hyperparameterConstants={filteredHyperparameterConstants}
        timezone={constants.timezone}
        trainingScheduleConstants={constants.training_schedule}
      />
    </form>
  );
}