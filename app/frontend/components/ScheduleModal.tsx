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
    retrainingJob?: {
      frequency: string;
      at: string | number;
      active: boolean;
      tunerConfig?: {
        n_trials: number;
        objective: string;
        config: Record<string, any>;
      };
    };
  };
  hyperparameterConstants: any;
  timezone: string;
  trainingScheduleConstants: any;
}

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

export function ScheduleModal({ isOpen, onClose, onSave, initialData, hyperparameterConstants, timezone, trainingScheduleConstants }: ScheduleModalProps) {
  const [formData, setFormData] = useState({
    trainingSchedule: {
      enabled: initialData.retrainingJob?.active ?? false,
      frequency: initialData.retrainingJob?.frequency || trainingScheduleConstants.frequency[0].value as string,
      dayOfWeek: typeof initialData.retrainingJob?.at === 'number' ? initialData.retrainingJob.at : 1,
      dayOfMonth: typeof initialData.retrainingJob?.at === 'number' ? initialData.retrainingJob.at : 1,
      hour: typeof initialData.retrainingJob?.at === 'number' ? initialData.retrainingJob.at : 2
    },
    tuningSchedule: {
      enabled: !!initialData.retrainingJob?.tunerConfig,
      frequency: 'weekly' as const,
      dayOfWeek: 1,
      dayOfMonth: 1,
      hour: 2,
      n_trials: initialData.retrainingJob?.tunerConfig?.n_trials || 10,
      parameters: initialData.retrainingJob?.tunerConfig?.config || {}
    },
    evaluator: {
      metric: METRICS[initialData.task === 'classification' ? 'classification' : 'regression'][0].value,
      threshold: initialData.task === 'classification' ? 0.85 : 0.1
    }
  });

  if (!isOpen) return null;

  const handleBaseParameterChange = (parameter: string, value: string) => {
    setFormData(prev => ({
      ...prev,
      tuningSchedule: {
        ...prev.tuningSchedule,
        parameters: {
          ...prev.tuningSchedule.parameters,
          [parameter]: value
        }
      }
    }));
  };

  const renderHyperparameterControls = () => {
    const baseParameters = Object.entries(hyperparameterConstants).filter(
      ([key, value]) => Array.isArray(value.options)
    );

    const selectedBaseParams = Object.keys(formData.tuningSchedule.parameters);

    return (
      <div className="space-y-4">
        {baseParameters.map(([key, value]) => (
          <div key={key}>
            <label className="block text-sm font-medium text-gray-700">
              {value.label}
            </label>
            <SearchableSelect
              options={value.options.map((option: any) => ({
                value: option.value,
                label: option.label,
                description: option.description
              }))}
              value={formData.tuningSchedule.parameters[key] || ''}
              onChange={(val) => handleBaseParameterChange(key, val as string)}
            />
          </div>
        ))}

        {selectedBaseParams.map(param => {
          const subParams = Object.entries(hyperparameterConstants).filter(
            ([key, value]) => value.depends_on === param
          );
          return (
            <div className="space-y-4">
              <h4 className="text-sm font-medium text-gray-900">Parameter Ranges</h4>
              <div className="space-y-4 max-h-[400px] overflow-y-auto pr-2">
                {subParams.map(([subKey, subValue]: any) => {
                  const selectedValue = formData.tuningSchedule.parameters[param];
                  const relevantParams = subValue[selectedValue];
                  return relevantParams ? Object.entries(relevantParams).map(([paramKey, paramValue]: any) => {
                    if (paramValue.min !== undefined && paramValue.max !== undefined) {
                      return (
                        <div key={paramKey} className="bg-gray-50 p-4 rounded-lg">
                          <div className="flex items-center justify-between mb-2">
                            <label className="text-sm font-medium text-gray-900">
                              {paramValue.label}
                            </label>
                            <span key={paramKey} className="text-xs text-gray-500">{paramValue.description}</span>
                          </div>
                          <div className="grid grid-cols-2 gap-4">
                            <div>
                              <label className="block text-xs text-gray-500 mb-1">
                                Minimum
                              </label>
                              <input
                                type="number"
                                min={paramValue.min}
                                max={paramValue.max}
                                step={paramValue.step}
                                value={formData.tuningSchedule.parameters[paramKey]?.min ?? paramValue.min}
                                onChange={(e) => handleParameterChange(
                                  paramKey,
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
                                min={paramValue.min}
                                max={paramValue.max}
                                step={paramValue.step}
                                value={formData.tuningSchedule.parameters[paramKey]?.max ?? paramValue.max}
                                onChange={(e) => handleParameterChange(
                                  paramKey,
                                  'max',
                                  parseFloat(e.target.value)
                                )}
                                className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                              />
                            </div>
                          </div>
                        </div>
                      );
                    }
                    return null;
                  }) : null;
                })}
              </div>
            </div>
          );
        })}
      </div>
    );
  };

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

  const handleTrainingScheduleChange = (field: string, value: string | number) => {
    setFormData(prev => ({
      ...prev,
      trainingSchedule: {
        ...prev.trainingSchedule,
        [field]: value
      }
    }));
  };

  const handleEvaluatorChange = (field: string, value: string | number) => {
    setFormData(prev => ({
      ...prev,
      evaluator: {
        ...prev.evaluator,
        [field]: value
      }
    }));
  };

  const handleSave = () => {
    const atParams = {
      hour: formData.trainingSchedule.hour
    };

    if (formData.trainingSchedule.frequency === "week") {
      atParams["day_of_week"] = formData.trainingSchedule.dayOfWeek;
    } else if (formData.trainingSchedule.frequency === "month") {
      atParams["day_of_month"] = formData.trainingSchedule.dayOfMonth;
    }

    onSave({
      trainingSchedule: {
        ...formData.trainingSchedule,
        at: atParams
      },
      evaluator: {
        ...formData.evaluator
      },
      tuningSchedule: {
        ...formData.tuningSchedule
      }
    });
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
          {/* Left Column */}
          <div className="space-y-8">
            {/* Training Schedule */}
            <div className="space-y-4">
              <div className="flex items-center justify-between">
                <div className="flex items-center gap-2">
                  <Calendar className="w-5 h-5 text-blue-600" />
                  <h3 className="text-lg font-medium text-gray-900">Training Schedule</h3>
                </div>
                <div className="flex items-center">
                  <input
                    type="checkbox"
                    id="scheduleEnabled"
                    checked={formData.trainingSchedule.enabled}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      trainingSchedule: {
                        ...prev.trainingSchedule,
                        enabled: e.target.checked
                      }
                    }))}
                    className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <label htmlFor="scheduleEnabled" className="ml-2 text-sm text-gray-700">
                    Enable scheduled training
                  </label>
                </div>
              </div>

              {!formData.trainingSchedule.enabled && (
                <div className="bg-gray-50 rounded-lg p-4">
                  <div className="flex items-start gap-2">
                    <AlertCircle className="w-5 h-5 text-gray-400 mt-0.5" />
                    <div>
                      <h4 className="text-sm font-medium text-gray-900">Manual Training Mode</h4>
                      <p className="mt-1 text-sm text-gray-500">
                        The model will only be trained when you manually trigger training. You can do this from the model details page at any time.
                      </p>
                    </div>
                  </div>
                </div>
              )}

              {formData.trainingSchedule.enabled && (
                <>
                  <div className="space-y-6">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-sm font-medium text-gray-700">
                          Frequency
                        </label>
                        <SearchableSelect
                          options={trainingScheduleConstants.frequency.map((freq: { value: string; label: string; description: string }) => ({
                            value: freq.value,
                            label: freq.label,
                            description: freq.description
                          }))}
                          value={formData.trainingSchedule.frequency}
                          onChange={(value) => handleTrainingScheduleChange('frequency', value)}
                        />
                      </div>

                      {formData.trainingSchedule.frequency === 'week' && (
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
                            onChange={(value) => handleTrainingScheduleChange('dayOfWeek', value)}
                          />
                        </div>
                      )}

                      {formData.trainingSchedule.frequency === 'month' && (
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
                            onChange={(value) => handleTrainingScheduleChange('dayOfMonth', value)}
                          />
                        </div>
                      )}

                      <div>
                        <label className="block text-sm font-medium text-gray-700">
                          Hour ({timezone})
                        </label>
                        <SearchableSelect
                          options={Array.from({ length: 24 }, (_, i) => ({
                            value: i,
                            label: `${i}:00`
                          }))}
                          value={formData.trainingSchedule.hour}
                          onChange={(value) => handleTrainingScheduleChange('hour', value)}
                        />
                      </div>
                    </div>
                  </div>

                  {/* Evaluator Configuration */}
                  <div className="border-t border-gray-200 pt-6">
                    <div className="flex items-center gap-2 mb-4">
                      <AlertCircle className="w-5 h-5 text-blue-600" />
                      <h3 className="text-lg font-medium text-gray-900">Evaluator Configuration</h3>
                    </div>

                    <div className="space-y-6">
                      <div className="grid grid-cols-2 gap-4">
                        <div>
                          <label className="block text-sm font-medium text-gray-700">
                            Metric
                          </label>
                          <SearchableSelect
                            options={METRICS[initialData.task === 'classification' ? 'classification' : 'regression'].map((metric) => ({
                              value: metric.value,
                              label: metric.label,
                              description: metric.description
                            }))}
                            value={formData.evaluator.metric}
                            onChange={(value) => handleEvaluatorChange('metric', value)}
                          />
                        </div>

                        <div>
                          <label className="block text-sm font-medium text-gray-700">
                            Threshold
                          </label>
                          <input
                            type="number"
                            value={formData.evaluator.threshold}
                            onChange={(e) => handleEvaluatorChange('threshold', parseFloat(e.target.value))}
                            step={0.01}
                            min={0}
                            max={1}
                            className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 py-2 px-4 shadow-sm border-gray-300 border"
                          />
                        </div>

                      </div>

                        {/* Deployment Criteria */}
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
                </>
              )}
            </div>
          </div>

          {/* Right Column */}
          <div className="space-y-8">
            {formData.trainingSchedule.enabled && (
              <div className="space-y-4">
                <div className="flex items-center justify-between">
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
                          max="1000"
                          value={formData.tuningSchedule.n_trials}
                          onChange={(e) => setFormData(prev => ({
                            ...prev,
                            tuningSchedule: {
                              ...prev.tuningSchedule,
                              n_trials: parseInt(e.target.value)
                            }
                          }))}
                          className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 py-2 px-4 shadow-sm border-gray-300 border"
                        />
                      </div>
                    </div>
                    {renderHyperparameterControls()}
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        <div className="flex justify-end gap-4 p-4 border-t">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-500"
          >
            Cancel
          </button>
          <button
            onClick={handleSave}
            className="px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 rounded-md"
          >
            Save Changes
          </button>
        </div>
      </div>
    </div>
  );
}