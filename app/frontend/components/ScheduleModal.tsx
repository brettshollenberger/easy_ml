import React, { useState, useEffect } from 'react';
import { X, AlertCircle, Calendar, Settings2, Info, Layers, Repeat } from 'lucide-react';
import { SearchableSelect } from './SearchableSelect';

interface ScheduleModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (data: any) => void;
  initialData: {
    task: string;
    metrics: string[];
    modelType?: string;
    dataset?: {
      columns: Array<{ name: string }>;
    };
    retraining_job?: {
      frequency: string;
      tuning_frequency: string;
      at: {
        hour: number;
        day_of_week?: number;
        day_of_month?: number;
      }
      direction: string;
      batch_mode?: boolean;
      batch_size?: number;
      batch_overlap?: number;
      batch_key?: string;
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
  metrics: {
    [key: string]: Array<{
      value: string;
      label: string;
      description: string;
      direction: string;
    }>;
  };
  tunerJobConstants: any;
  timezone: string;
  retrainingJobConstants: any;
}

export function ScheduleModal({ isOpen, onClose, onSave, initialData, metrics, tunerJobConstants, timezone, retrainingJobConstants }: ScheduleModalProps) {
  const [showBatchTrainingInfo, setShowBatchTrainingInfo] = useState(false);
  const [activeBatchPopover, setActiveBatchPopover] = useState<'size' | 'overlap' | null>(null);

  // Get all base parameters (those with options)
  const baseParameters = Object.entries(tunerJobConstants)
    .filter(([_, value]) => Array.isArray(value.options))
    .reduce((acc, [key, value]) => ({
      ...acc,
      [key]: value.options[0].value // Default to first option if not set
    }), {});

  // Get default numeric parameters for the default booster
  const defaultBooster = baseParameters.booster;
  const defaultNumericParameters = Object.entries(tunerJobConstants.hyperparameters[defaultBooster] || {})
    .filter(([_, value]) => !Array.isArray(value.options))
    .reduce((acc, [key, value]) => ({
      ...acc,
      [key]: {
        min: value.min,
        max: value.max
      }
    }), {});

  const [formData, setFormData] = useState({
    retraining_job_attributes: {
      id: initialData.retraining_job?.id || null,
      active: initialData.retraining_job?.active ?? false,
      frequency: initialData.retraining_job?.frequency || retrainingJobConstants.frequency[0].value as string,
      tuning_frequency: initialData.retraining_job?.tuning_frequency || 'month',
      direction: initialData.retraining_job?.direction || 'maximize',
      batch_mode: initialData.retraining_job?.batch_mode || false,
      batch_size: initialData.retraining_job?.batch_size || 100,
      batch_overlap: initialData.retraining_job?.batch_overlap || 1,
      batch_key: initialData.retraining_job?.batch_key || '',
      at: {
        hour: initialData.retraining_job?.at?.hour ?? 2,
        day_of_week: initialData.retraining_job?.at?.day_of_week ?? 1,
        day_of_month: initialData.retraining_job?.at?.day_of_month ?? 1
      },
      metric: initialData.retraining_job?.metric || (metrics[initialData.task]?.[0]?.value ?? ''),
      threshold: initialData.retraining_job?.threshold || (initialData.task === 'classification' ? 0.85 : 0.1),
      tuner_config: initialData.retraining_job?.tuner_config ? {
        n_trials: initialData.retraining_job.tuner_config.n_trials || 10,
        config: {
          ...baseParameters,
          ...defaultNumericParameters,
          ...initialData.retraining_job.tuner_config.config
        }
      } : undefined,
      tuning_enabled: initialData.retraining_job?.tuning_enabled ?? false
    }
  });

  useEffect(() => {
    if (formData.retraining_job_attributes.tuner_config && Object.keys(formData.retraining_job_attributes.tuner_config.config).length === 0) {
      setFormData(prev => ({
        ...prev,
        retraining_job_attributes: {
          ...prev.retraining_job_attributes,
          tuner_config: {
            ...prev.retraining_job_attributes.tuner_config,
            config: {
              ...baseParameters,
              ...defaultNumericParameters
            }
          }
        }
      }));
    }
  }, [formData.retraining_job_attributes.tuner_config]);

  if (!isOpen) return null;

  const handleBaseParameterChange = (parameter: string, value: string) => {
    setFormData(prev => ({
      ...prev,
      retraining_job_attributes: {
        ...prev.retraining_job_attributes,
        tuner_config: {
          ...prev.retraining_job_attributes.tuner_config,
          config: {
            ...prev.retraining_job_attributes.tuner_config.config,
            [parameter]: value
          }
        }
      }
    }));
  };

  const renderHyperparameterControls = () => {
    const baseParameters = Object.entries(tunerJobConstants).filter(
      ([key, value]) => Array.isArray(value.options)
    );

    // Include all base parameters, not just those in config
    const selectedBaseParams = baseParameters.map(([key]) => key);

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
              value={formData.retraining_job_attributes.tuner_config?.config[key] || value.options[0].value}
              onChange={(val) => handleBaseParameterChange(key, val as string)}
            />
          </div>
        ))}

        {selectedBaseParams.map(param => {
          const subParams = Object.entries(tunerJobConstants).filter(
            ([key, value]) => value.depends_on === param
          );
          
          const selectedValue = formData.retraining_job_attributes.tuner_config?.config[param] || 
            tunerJobConstants[param].options[0].value; // Use default if not in config

          return (
            <div key={param} className="space-y-4">
              <h4 className="text-sm font-medium text-gray-900">Parameter Ranges</h4>
              <div className="space-y-4 max-h-[400px] overflow-y-auto pr-2">
                {subParams.map(([subKey, subValue]: any) => {
                  const relevantParams = subValue[selectedValue];
                  if (!relevantParams) return null;

                  return Object.entries(relevantParams).map(([paramKey, paramValue]: any) => {
                    if (paramValue.min !== undefined && paramValue.max !== undefined) {
                      return (
                        <div key={paramKey} className="bg-gray-50 p-4 rounded-lg">
                          <div className="flex items-center justify-between mb-2">
                            <label className="text-sm font-medium text-gray-900">
                              {paramValue.label}
                            </label>
                            <span className="text-xs text-gray-500">{paramValue.description}</span>
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
                                value={formData.retraining_job_attributes.tuner_config?.config[paramKey]?.min ?? paramValue.min}
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
                                value={formData.retraining_job_attributes.tuner_config?.config[paramKey]?.max ?? paramValue.max}
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
                  });
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
      retraining_job_attributes: {
        ...prev.retraining_job_attributes,
        tuner_config: {
          ...prev.retraining_job_attributes.tuner_config,
          config: {
            ...prev.retraining_job_attributes.tuner_config.config,
            [parameter]: {
              ...prev.retraining_job_attributes.tuner_config.config[parameter],
              [type]: value
            }
          }
        }
      }
    }));
  };

  const handleTrainingScheduleChange = (field: string, value: string | number) => {
    setFormData(prev => {
      if (field === 'hour' || field === 'day_of_week' || field === 'day_of_month') {
        return {
          ...prev,
          retraining_job_attributes: {
            ...prev.retraining_job_attributes,
            at: {
              ...prev.retraining_job_attributes.at,
              [field]: value
            }
          }
        };
      }
      return {
        ...prev,
        retraining_job_attributes: {
          ...prev.retraining_job_attributes,
          [field]: value
        }
      };
    });
  };

  const handleEvaluatorChange = (field: string, value: string | number) => {
    setFormData(prev => ({
      ...prev,
      retraining_job_attributes: {
        ...prev.retraining_job_attributes,
        [field]: value
      }
    }));
  };

  const handleSave = () => {
    const { retraining_job_attributes } = formData;
    const at: any = { hour: retraining_job_attributes.at.hour };

    // Only include relevant date attributes based on frequency
    switch (retraining_job_attributes.frequency) {
      case 'day':
        // For daily frequency, only include hour
        break;
      case 'week':
        // For weekly frequency, include hour and day_of_week
        at.day_of_week = retraining_job_attributes.at.day_of_week;
        break;
      case 'month':
        // For monthly frequency, include hour and day_of_month
        at.day_of_month = retraining_job_attributes.at.day_of_month;
        break;
    }

    const updatedData = {
      retraining_job_attributes: {
        ...retraining_job_attributes,
        at
      }
    };

    onSave(updatedData);
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg w-full max-w-6xl max-h-[90vh] overflow-hidden">
        <div className="flex justify-between items-center p-4 border-b">
          <h2 className="text-lg font-semibold">Training Configuration</h2>
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
                    checked={formData.retraining_job_attributes.active}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      retraining_job_attributes: {
                        ...prev.retraining_job_attributes,
                        active: e.target.checked
                      }
                    }))}
                    className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <label htmlFor="scheduleEnabled" className="ml-2 text-sm text-gray-700">
                    Enable scheduled training
                  </label>
                </div>
              </div>

              {!formData.retraining_job_attributes.active && (
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

              {formData.retraining_job_attributes.active && (
                <>
                  <div className="space-y-6">
                    <div className="grid grid-cols-2 gap-4">
                      <div>
                        <label className="block text-sm font-medium text-gray-700">
                          Frequency
                        </label>
                        <SearchableSelect
                          options={retrainingJobConstants.frequency.map((freq: { value: string; label: string; description: string }) => ({
                            value: freq.value,
                            label: freq.label,
                            description: freq.description
                          }))}
                          value={formData.retraining_job_attributes.frequency}
                          onChange={(value) => handleTrainingScheduleChange('frequency', value)}
                        />
                      </div>

                      {formData.retraining_job_attributes.frequency === 'week' && (
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
                            value={formData.retraining_job_attributes.at.day_of_week}
                            onChange={(value) => handleTrainingScheduleChange('day_of_week', value)}
                          />
                        </div>
                      )}

                      {formData.retraining_job_attributes.frequency === 'month' && (
                        <div>
                          <label className="block text-sm font-medium text-gray-700">
                            Day of Month
                          </label>
                          <SearchableSelect
                            options={Array.from({ length: 31 }, (_, i) => ({
                              value: i + 1,
                              label: `Day ${i + 1}`
                            }))}
                            value={formData.retraining_job_attributes.at.day_of_month}
                            onChange={(value) => handleTrainingScheduleChange('day_of_month', value)}
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
                          value={formData.retraining_job_attributes.at.hour}
                          onChange={(value) => handleTrainingScheduleChange('hour', value)}
                        />
                      </div>
                    </div>
                  </div>
                </>
              )}

                {/* Batch Training Options */}
                <div className="space-y-4 pt-4 border-t">
                  <div className="flex items-center justify-between">
                    <div className="flex items-center gap-2">
                      <label htmlFor="batchTrainingEnabled" className="text-sm font-medium text-gray-700 flex items-center gap-2">
                        Enable Batch Training
                        <button
                          type="button"
                          onClick={() => setShowBatchTrainingInfo(!showBatchTrainingInfo)}
                          className="text-gray-400 hover:text-gray-600"
                        >
                          <Info className="w-4 h-4" />
                        </button>
                      </label>
                    </div>
                    <input
                      type="checkbox"
                      id="batchMode"
                      checked={formData.retraining_job_attributes.batch_mode}
                      onChange={(e) => setFormData({ ...formData, retraining_job_attributes: { ...formData.retraining_job_attributes, batch_mode: e.target.checked } })}
                      className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                    />
                  </div>

                  {showBatchTrainingInfo && (
                    <div className="bg-blue-50 rounded-lg p-4 text-sm text-blue-700">
                      <ul className="space-y-2">
                        <li>• When disabled, the model will train on the entire dataset in a single pass.</li>
                        <li>• When enabled, the model will learn from small batches of data iteratively, improving training speed</li>
                      </ul>
                    </div>
                  )}

                  {formData.retraining_job_attributes.batch_mode && (
                    <div className="mt-4">
                      <div className="flex items-center gap-2">
                        <div className="flex-1">
                          <label className="block text-sm font-medium text-gray-700">
                            Batch Size
                          </label>
                          <input
                            type="number"
                            value={formData.retraining_job_attributes.batch_size}
                            onChange={(e) => setFormData({
                              ...formData,
                              retraining_job_attributes: {
                                ...formData.retraining_job_attributes,
                                batch_size: parseInt(e.target.value)
                              }
                            })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          />
                        </div>
                        <div className="flex-1">
                          <label className="block text-sm font-medium text-gray-700">
                            Batch Overlap
                          </label>
                          <input
                            type="number"
                            value={formData.retraining_job_attributes.batch_overlap}
                            onChange={(e) => setFormData({
                              ...formData,
                              retraining_job_attributes: {
                                ...formData.retraining_job_attributes,
                                batch_overlap: parseInt(e.target.value)
                              }
                            })}
                            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm"
                          />
                        </div>
                      </div>
                      <div className="mt-4">
                        <label className="block text-sm font-medium text-gray-700">
                          Batch Key
                        </label>
                        <SearchableSelect
                          value={formData.retraining_job_attributes.batch_key}
                          onChange={(value) => setFormData({
                            ...formData,
                            retraining_job_attributes: {
                              ...formData.retraining_job_attributes,
                              batch_key: value
                            }
                          })}
                          options={initialData.dataset?.columns?.map(column => ({
                            value: column.name,
                            label: column.name
                          })) || []}
                          placeholder="Select a column for batch key"
                        />
                      </div>
                    </div>
                  )}
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
                          options={metrics[initialData.task].map((metric) => ({
                            value: metric.value,
                            label: metric.label,
                            description: metric.description
                          }))}
                          value={formData.retraining_job_attributes.metric}
                          onChange={(value) => handleEvaluatorChange('metric', value)}
                        />
                      </div>

                      <div>
                        <label className="block text-sm font-medium text-gray-700">
                          Threshold
                        </label>
                        <input
                          type="number"
                          value={formData.retraining_job_attributes.threshold}
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
                              {(() => {
                                const selectedMetric = metrics[initialData.task].find(m => m.value === formData.retraining_job_attributes.metric);
                                const direction = selectedMetric?.direction === 'minimize' ? 'below' : 'above';
                                
                                return `The model will be automatically deployed when the ${selectedMetric?.label} is ${direction} ${formData.retraining_job_attributes.threshold}.`;
                              })()}
                            </p>
                          </div>
                        </div>
                      </div>
                  </div>
                </div>
            </div>
          </div>

          {/* Right Column */}
          <div className="space-y-8">
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
                    checked={formData.retraining_job_attributes.tuning_enabled || false}
                    onChange={(e) => setFormData(prev => ({
                      ...prev,
                      retraining_job_attributes: {
                        ...prev.retraining_job_attributes,
                        tuning_enabled: e.target.checked,
                        tuner_config: e.target.checked ? {
                          n_trials: 10,
                          config: defaultNumericParameters
                        } : undefined
                      }
                    }))}
                    className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <label htmlFor="tuningEnabled" className="ml-2 text-sm text-gray-700">
                    Enable tuning
                  </label>
                </div>
              </div>

              {formData.retraining_job_attributes.tuning_enabled && (
                <div className="space-y-6">
                  <div className="grid grid-cols-2 gap-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700">
                        Frequency
                      </label>
                      <SearchableSelect
                        options={[
                          { value: 'always', label: 'Always', description: 'Tune hyperparameters every time' },
                          { value: 'week', label: 'Weekly', description: 'Tune hyperparameters once every week' },
                          { value: 'month', label: 'Monthly', description: 'Tune hyperparameters once every month' }
                        ]}
                        value={formData.retraining_job_attributes.tuning_frequency || 'week'}
                        onChange={(value) => setFormData(prev => ({
                          ...prev,
                          retraining_job_attributes: {
                            ...prev.retraining_job_attributes,
                            tuning_frequency: value as 'week' | 'month' | 'always'
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
                        value={formData.retraining_job_attributes.tuner_config?.n_trials || 10}
                        onChange={(e) => setFormData(prev => ({
                          ...prev,
                          retraining_job_attributes: {
                            ...prev.retraining_job_attributes,
                            tuner_config: {
                              ...prev.retraining_job_attributes.tuner_config,
                              n_trials: parseInt(e.target.value)
                            }
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