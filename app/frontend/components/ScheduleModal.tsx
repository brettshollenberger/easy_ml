import React, { useState } from 'react';
import { X, AlertCircle, Calendar, Settings2 } from 'lucide-react';
import { SearchableSelect } from './SearchableSelect';

interface ScheduleModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (data: any) => void;
  initialData: {
    task: string;
    metrics: string[];
    modelType?: string;
  };
}

type Booster = 'gbtree' | 'gblinear' | 'dart';

interface Parameter {
  name: string;
  description: string;
  min: number;
  max: number;
  step: number;
}

const BOOSTERS: Record<Booster, {
  description: string;
  parameters: Parameter[];
}> = {
  gbtree: {
    description: 'Traditional Gradient Boosting Decision Tree',
    parameters: [
      {
        name: 'learning_rate',
        description: 'Step size shrinkage used to prevent overfitting',
        min: 0.001,
        max: 1,
        step: 0.001
      },
      {
        name: 'max_depth',
        description: 'Maximum depth of a tree',
        min: 1,
        max: 20,
        step: 1
      },
      {
        name: 'min_child_weight',
        description: 'Minimum sum of instance weight needed in a child',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'gamma',
        description: 'Minimum loss reduction required to make a further partition',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'subsample',
        description: 'Subsample ratio of the training instances',
        min: 0.1,
        max: 1,
        step: 0.1
      },
      {
        name: 'colsample_bytree',
        description: 'Subsample ratio of columns when constructing each tree',
        min: 0.1,
        max: 1,
        step: 0.1
      },
      {
        name: 'lambda',
        description: 'L2 regularization term on weights',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'alpha',
        description: 'L1 regularization term on weights',
        min: 0,
        max: 10,
        step: 0.1
      }
    ]
  },
  gblinear: {
    description: 'Generalized Linear Model with gradient boosting',
    parameters: [
      {
        name: 'learning_rate',
        description: 'Step size shrinkage used to prevent overfitting',
        min: 0.001,
        max: 1,
        step: 0.001
      },
      {
        name: 'lambda',
        description: 'L2 regularization term on weights',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'alpha',
        description: 'L1 regularization term on weights',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'feature_selector',
        description: 'Feature selection and ordering method',
        min: 0,
        max: 4,
        step: 1
      }
    ]
  },
  dart: {
    description: 'Dropouts meet Multiple Additive Regression Trees',
    parameters: [
      {
        name: 'learning_rate',
        description: 'Step size shrinkage used to prevent overfitting',
        min: 0.001,
        max: 1,
        step: 0.001
      },
      {
        name: 'max_depth',
        description: 'Maximum depth of a tree',
        min: 1,
        max: 20,
        step: 1
      },
      {
        name: 'min_child_weight',
        description: 'Minimum sum of instance weight needed in a child',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'gamma',
        description: 'Minimum loss reduction required to make a further partition',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'subsample',
        description: 'Subsample ratio of the training instances',
        min: 0.1,
        max: 1,
        step: 0.1
      },
      {
        name: 'colsample_bytree',
        description: 'Subsample ratio of columns when constructing each tree',
        min: 0.1,
        max: 1,
        step: 0.1
      },
      {
        name: 'lambda',
        description: 'L2 regularization term on weights',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'alpha',
        description: 'L1 regularization term on weights',
        min: 0,
        max: 10,
        step: 0.1
      },
      {
        name: 'rate_drop',
        description: 'Dropout rate (a fraction of previous trees to drop)',
        min: 0,
        max: 1,
        step: 0.1
      },
      {
        name: 'skip_drop',
        description: 'Probability of skipping the dropout procedure during iteration',
        min: 0,
        max: 1,
        step: 0.1
      }
    ]
  }
};

const METRICS = {
  classification: [
    { value: 'accuracy_score', label: 'Accuracy', description: 'Overall prediction accuracy' },
    { value: 'precision_score', label: 'Precision', description: 'Ratio of true positives to predicted positives' },
    { value: 'recall_score', label: 'Recall', description: 'Ratio of true positives to actual positives' },
    { value: 'f1_score', label: 'F1 Score', description: 'Harmonic mean of precision and recall' }
  ],
  regression: [
    { value: 'mean_absolute_error', label: 'Mean Absolute Error', description: 'Average absolute differences between predicted and actual values' },
    { value: 'mean_squared_error', label: 'Mean Squared Error', description: 'Average squared differences between predicted and actual values' },
    { value: 'root_mean_squared_error', label: 'Root Mean Squared Error', description: 'Square root of mean squared error' },
    { value: 'r2_score', label: 'R² Score', description: 'Proportion of variance in the target that is predictable' }
  ]
};

export function ScheduleModal({ isOpen, onClose, onSave, initialData }: ScheduleModalProps) {
  const [formData, setFormData] = useState({
    trainingSchedule: {
      frequency: 'daily' as const,
      dayOfWeek: 1,
      dayOfMonth: 1,
      hour: 2
    },
    tuningSchedule: {
      enabled: false,
      frequency: 'weekly' as const,
      dayOfWeek: 1,
      dayOfMonth: 1,
      hour: 2,
      trials: 10,
      booster: 'gbtree' as Booster,
      parameters: {} as Record<string, { min: number; max: number }>
    },
    evaluator: {
      metric: METRICS[initialData.task === 'classification' ? 'classification' : 'regression'][0].value,
      direction: initialData.task === 'classification' ? 'maximize' as const : 'minimize' as const,
      threshold: initialData.task === 'classification' ? 0.85 : 0.1
    }
  });

  if (!isOpen) return null;

  const handleParameterChange = (parameter: string, type: 'min' | 'max', value: number) => {
    setFormData(prev => ({
      ...prev,
      tuningSchedule: {
        ...prev.tuningSchedule,
        parameters: {
          ...prev.tuningSchedule.parameters,
          [parameter]: {
            ...prev.tuningSchedule.parameters[parameter],
            [type]: value
          }
        }
      }
    }));
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg w-full max-w-6xl max-h-[90vh] overflow-hidden">
        <div className="flex justify-between items-center p-4 border-b">
          <h2 className="text-lg font-semibold">Training Schedule Configuration</h2>
          <button
            onClick={onClose}
            className="text-gray-500 hover:text-gray-700"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 grid grid-cols-2 gap-8 max-h-[calc(90vh-8rem)] overflow-y-auto">
          <div className="space-y-8">
            {/* Training Schedule */}
            <div className="space-y-4">
              <div className="flex items-center gap-2">
                <Calendar className="w-5 h-5 text-blue-600" />
                <h3 className="text-lg font-medium text-gray-900">Training Schedule</h3>
              </div>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">
                    Frequency
                  </label>
                  <SearchableSelect
                    options={[
                      { value: 'daily', label: 'Daily', description: 'Run once every day' },
                      { value: 'weekly', label: 'Weekly', description: 'Run once every week' },
                      { value: 'monthly', label: 'Monthly', description: 'Run once every month' }
                    ]}
                    value={formData.trainingSchedule.frequency}
                    onChange={(value) => setFormData(prev => ({
                      ...prev,
                      trainingSchedule: {
                        ...prev.trainingSchedule,
                        frequency: value as 'daily' | 'weekly' | 'monthly'
                      }
                    }))}
                  />
                </div>

                {formData.trainingSchedule.frequency === 'weekly' && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Day of Week
                    </label>
                    <SearchableSelect
                      options={[
                        { value: 0, label: 'Sunday' },
                        { value: 1, label: 'Monday' },
                        { value: 2, label: 'Tuesday' },
                        { value: 3, label: 'Wednesday' },
                        { value: 4, label: 'Thursday' },
                        { value: 5, label: 'Friday' },
                        { value: 6, label: 'Saturday' }
                      ]}
                      value={formData.trainingSchedule.dayOfWeek}
                      onChange={(value) => setFormData(prev => ({
                        ...prev,
                        trainingSchedule: {
                          ...prev.trainingSchedule,
                          dayOfWeek: value as number
                        }
                      }))}
                    />
                  </div>
                )}

                {formData.trainingSchedule.frequency === 'monthly' && (
                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Day of Month
                    </label>
                    <SearchableSelect
                      options={Array.from({ length: 31 }, (_, i) => ({
                        value: i + 1,
                        label: `Day ${i + 1}`
                      }))}
                      value={formData.trainingSchedule.dayOfMonth}
                      onChange={(value) => setFormData(prev => ({
                        ...prev,
                        trainingSchedule: {
                          ...prev.trainingSchedule,
                          dayOfMonth: value as number
                        }
                      }))}
                    />
                  </div>
                )}

                <div>
                  <label className="block text-sm font-medium text-gray-700">
                    Hour (UTC)
                  </label>
                  <SearchableSelect
                    options={Array.from({ length: 24 }, (_, i) => ({
                      value: i,
                      label: `${i}:00`
                    }))}
                    value={formData.trainingSchedule.hour}
                    onChange={(value) => setFormData(prev => ({
                      ...prev,
                      trainingSchedule: {
                        ...prev.trainingSchedule,
                        hour: value as number
                      }
                    }))}
                  />
                </div>
              </div>
            </div>

            {/* Evaluator Configuration */}
            <div className="space-y-4">
              <div className="flex items-center gap-2">
                <AlertCircle className="w-5 h-5 text-blue-600" />
                <h3 className="text-lg font-medium text-gray-900">Evaluator Configuration</h3>
              </div>
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700">
                    Metric
                  </label>
                  <SearchableSelect
                    options={METRICS[initialData.task === 'classification' ? 'classification' : 'regression']}
                    value={formData.evaluator.metric}
                    onChange={(value) => setFormData(prev => ({
                      ...prev,
                      evaluator: {
                        ...prev.evaluator,
                        metric: value as string,
                        direction: value.toString().includes('error') ? 'minimize' : 'maximize'
                      }
                    }))}
                  />
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700">
                    Threshold
                  </label>
                  <input
                    type="number"
                    step="0.01"
                    value={formData.evaluator.threshold}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      evaluator: {
                        ...prev.evaluator,
                        threshold: parseFloat(e.target.value)
                      }
                    }))}
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>

                <div className="bg-blue-50 rounded-md p-4">
                  <div className="flex items-start">
                    <AlertCircle className="w-5 h-5 text-blue-400 mt-0.5" />
                    <div className="ml-3">
                      <h3 className="text-sm font-medium text-blue-800">Deployment Criteria</h3>
                      <p className="mt-2 text-sm text-blue-700">
                        The model will be automatically deployed when the {formData.evaluator.metric} is{' '}
                        {formData.evaluator.direction === 'minimize' ? 'below' : 'above'} {formData.evaluator.threshold}.
                      </p>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Hyperparameter Tuning */}
          <div className="space-y-4">
            <div className="flex items-center justify-between border-b pb-4">
              <div className="flex items-center gap-2">
                <Settings2 className="w-5 h-5 text-blue-600" />
                <h3 className="text-lg font-medium text-gray-900">Hyperparameter Tuning</h3>
              </div>
              <div className="flex items-center">
                <input
                  type="checkbox"
                  id="tuningEnabled"
                  checked={formData.tuningSchedule.enabled}
                  onChange={(e) => setFormData(prev => ({
                    ...prev,
                    tuningSchedule: {
                      ...prev.tuningSchedule,
                      enabled: e.target.checked
                    }
                  }))}
                  className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <label htmlFor="tuningEnabled" className="ml-2 text-sm text-gray-700">
                  Enable tuning
                </label>
              </div>
            </div>

            {formData.tuningSchedule.enabled && (
              <div className="space-y-6">
                <div className="grid grid-cols-2 gap-4">
                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Frequency
                    </label>
                    <SearchableSelect
                      options={[
                        { value: 'weekly', label: 'Weekly', description: 'Tune hyperparameters once every week' },
                        { value: 'monthly', label: 'Monthly', description: 'Tune hyperparameters once every month' }
                      ]}
                      value={formData.tuningSchedule.frequency}
                      onChange={(value) => setFormData(prev => ({
                        ...prev,
                        tuningSchedule: {
                          ...prev.tuningSchedule,
                          frequency: value as 'weekly' | 'monthly'
                        }
                      }))}
                    />
                  </div>

                  <div>
                    <label className="block text-sm font-medium text-gray-700">
                      Number of Trials
                    </label>
                    <input
                      type="number"
                      min="1"
                      max="100"
                      value={formData.tuningSchedule.trials}
                      onChange={(e) => setFormData(prev => ({
                        ...prev,
                        tuningSchedule: {
                          ...prev.tuningSchedule,
                          trials: parseInt(e.target.value)
                        }
                      }))}
                      className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-2">
                    XGBoost Booster
                  </label>
                  <SearchableSelect
                    options={Object.entries(BOOSTERS).map(([key, value]) => ({
                      value: key,
                      label: key.toUpperCase(),
                      description: value.description
                    }))}
                    value={formData.tuningSchedule.booster}
                    onChange={(value) => setFormData(prev => ({
                      ...prev,
                      tuningSchedule: {
                        ...prev.tuningSchedule,
                        booster: value as Booster,
                        parameters: {}
                      }
                    }))}
                  />
                </div>

                <div className="space-y-4">
                  <h4 className="text-sm font-medium text-gray-900">Parameter Ranges</h4>
                  <div className="space-y-4 max-h-[400px] overflow-y-auto pr-2">
                    {BOOSTERS[formData.tuningSchedule.booster].parameters.map((param) => (
                      <div key={param.name} className="bg-gray-50 p-4 rounded-lg">
                        <div className="flex items-center justify-between mb-2">
                          <label className="text-sm font-medium text-gray-900">
                            {param.name}
                          </label>
                          <span className="text-xs text-gray-500">{param.description}</span>
                        </div>
                        <div className="grid grid-cols-2 gap-4">
                          <div>
                            <label className="block text-xs text-gray-500 mb-1">
                              Minimum
                            </label>
                            <input
                              type="number"
                              min={param.min}
                              max={param.max}
                              step={param.step}
                              value={formData.tuningSchedule.parameters[param.name]?.min ?? param.min}
                              onChange={(e) => handleParameterChange(
                                param.name,
                                'min',
                                parseFloat(e.target.value)
                              )}
                              className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                            />
                          </div>
                          <div>
                            <label className="block text-xs text-gray-500 mb-1">
                              Maximum
                            </label>
                            <input
                              type="number"
                              min={param.min}
                              max={param.max}
                              step={param.step}
                              value={formData.tuningSchedule.parameters[param.name]?.max ?? param.max}
                              onChange={(e) => handleParameterChange(
                                param.name,
                                'max',
                                parseFloat(e.target.value)
                              )}
                              className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                            />
                          </div>
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              </div>
            )}
          </div>
        </div>

        <div className="border-t p-4 flex justify-end gap-3">
          <button
            type="button"
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
          >
            Cancel
          </button>
          <button
            type="button"
            onClick={() => onSave(formData)}
            className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            Save Schedule
          </button>
        </div>
      </div>
    </div>
  );
}