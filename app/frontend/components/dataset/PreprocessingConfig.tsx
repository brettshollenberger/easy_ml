import React, { useState, useEffect } from 'react';
import { Settings2, Wrench, ArrowRight, Pencil } from 'lucide-react';
import type { Dataset, Column, ColumnType, PreprocessingConstants, PreprocessingSteps, PreprocessingStep } from '../../types/dataset';
import { Badge } from "@/components/ui/badge";
interface PreprocessingConfigProps {
  column: Column;
  dataset: Dataset;
  setColumnType: (columnName: string, columnType: string) => void;
  setDataset: (dataset: Dataset) => void;
  constants: PreprocessingConstants;
  onUpdate: (
    training: PreprocessingStep,
    inference: PreprocessingStep | undefined,
    useDistinctInference: boolean
  ) => void;
}

const isNumericType = (type: ColumnType): boolean => 
  type === 'float' || type === 'integer';

export function PreprocessingConfig({ 
  column,
  dataset,
  setColumnType,
  setDataset,
  constants,
  onUpdate 
}: PreprocessingConfigProps) {
  const [useDistinctInference, setUseDistinctInference] = useState(
    Boolean(column.preprocessing_steps?.inference?.method && 
            column.preprocessing_steps.inference.method !== 'none')
  );
  
  const [selectedType, setSelectedType] = useState<ColumnType>(column.datatype as ColumnType);
  
  const [training, setTraining] = useState<PreprocessingStep>(() => ({
    method: column.preprocessing_steps?.training?.method || 'none',
    params: {
      categorical_min: column.preprocessing_steps?.training?.params?.categorical_min ?? 100,
      one_hot: column.preprocessing_steps?.training?.params?.one_hot ?? true,
      ordinal_encoding: column.preprocessing_steps?.training?.params?.ordinal_encoding ?? false,
      clip: column.preprocessing_steps?.training?.params?.clip
    }
  }));
  
  const [inference, setInference] = useState<PreprocessingStep>(() => ({
    method: column.preprocessing_steps?.inference?.method || 'none',
    params: {
      categorical_min: column.preprocessing_steps?.inference?.params?.categorical_min ?? 100,
      one_hot: column.preprocessing_steps?.inference?.params?.one_hot ?? true,
      ordinal_encoding: column.preprocessing_steps?.inference?.params?.ordinal_encoding ?? false,
      clip: column.preprocessing_steps?.inference?.params?.clip
    }
  }));

  // Update selectedType when column changes
  useEffect(() => {
    setSelectedType(column.datatype as ColumnType);
  }, [column.datatype]);

  const handleColumnTypeChange = (newType: ColumnType) => {
    setSelectedType(newType);
    setColumnType(column.name, newType);

    // Apply default preprocessing strategy based on the new column type
    let defaultParams: PreprocessingStep['params'] = {};
    let defaultMethod: PreprocessingStep['method'] = 'none';

    if (newType === 'categorical') {
        defaultParams = {
            categorical_min: 100,
            one_hot: true,
        };
        defaultMethod = 'categorical';
    } else if (isNumericType(newType)) {
        defaultMethod = 'none'; // or any other default method for numeric types
    }

    const newTrainingStrategy: PreprocessingStep = {
        method: defaultMethod,
        params: defaultParams
    };

    setTraining(newTrainingStrategy);
    onUpdate(newTrainingStrategy, useDistinctInference ? inference : undefined, useDistinctInference);
  };

  const handleStrategyChange = (
    type: 'training' | 'inference',
    method: PreprocessingStep['method']
  ) => {
    let defaultParams: PreprocessingStep['params'] = {};

    if (selectedType === 'categorical') {
      if (method === 'categorical') {
        defaultParams = {
          ...defaultParams,
          categorical_min: 100,
          one_hot: true
        };
      } else if (method != 'none') {
        defaultParams = {
          ...defaultParams,
          one_hot: true
        };
      }
    }

    if (column.is_target) {
      defaultParams = {
        ...defaultParams,
        ordinal_encoding: true
      };
    }

    const newStrategy: PreprocessingStep = {
      method,
      params: defaultParams
    };

    if (type === 'training') {
      setTraining(newStrategy);
      onUpdate(newStrategy, useDistinctInference ? inference : undefined, useDistinctInference);
    } else {
      setInference(newStrategy);
      onUpdate(training, newStrategy, useDistinctInference);
    }
  };

  // Update the categorical params section:
  const handleCategoricalParamChange = (
    type: 'training' | 'inference',
    updates: Partial<PreprocessingStep['params']>
  ) => {
    const strategy = type === 'training' ? training : inference;
    const setStrategy = type === 'training' ? setTraining : setInference;
    
    const newStrategy: PreprocessingStep = {
      ...strategy,
      params: {
        categorical_min: strategy.params.categorical_min,
        one_hot: strategy.params.one_hot,
        ordinal_encoding: strategy.params.ordinal_encoding,
        ...updates
      }
    };

    setStrategy(newStrategy);
    if (type === 'training') {
      onUpdate(newStrategy, useDistinctInference ? inference : undefined, useDistinctInference);
    } else {
      onUpdate(training, newStrategy, useDistinctInference);
    }
  };

  // Update the numeric clipping section:
  const handleClipChange = (
    type: 'training' | 'inference',
    clipUpdates: Partial<{ min?: number; max?: number }>
  ) => {
    const strategy = type === 'training' ? training : inference;
    const setStrategy = type === 'training' ? setTraining : setInference;
    
    const newStrategy: PreprocessingStep = {
      ...strategy,
      params: {
        ...strategy.params,
        clip: {
          ...strategy.params.clip,
          ...clipUpdates
        }
      }
    };

    setStrategy(newStrategy);
    if (type === 'training') {
      onUpdate(newStrategy, useDistinctInference ? inference : undefined, useDistinctInference);
    } else {
      onUpdate(training, newStrategy, useDistinctInference);
    }
  };

  const handleConstantValueChange = (
    type: 'training' | 'inference',
    value: string
  ) => {
    const strategy = type === 'training' ? training : inference;
    const setStrategy = type === 'training' ? setTraining : setInference;

    const newStrategy: PreprocessingStep = {
      ...strategy,
      params: {
        ...strategy.params,
        constantValue: value
      }
    };

    setStrategy(newStrategy);
    if (type === 'training') {
      onUpdate(newStrategy, useDistinctInference ? inference : undefined, useDistinctInference);
    } else {
      onUpdate(training, newStrategy, useDistinctInference);
    }
  };

  const renderConstantValueInput = (type: 'training' | 'inference') => {
    const strategy = type === 'training' ? training : inference;
    if (strategy.method !== 'constant') return null;

    return (
      <div className="mt-4">
        <label className="block text-sm font-medium text-gray-700 mb-1">
          Constant Value
        </label>
        {isNumericType(selectedType) ? (
          <input
            type="number"
            value={strategy.params?.constantValue ?? ''}
            onChange={(e) => handleConstantValueChange(type, e.target.value)}
            className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="Enter a number..."
          />
        ) : (
          <input
            type="text"
            value={strategy.params?.constantValue ?? ''}
            onChange={(e) => handleConstantValueChange(type, e.target.value)}
            className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="Enter a value..."
          />
        )}
      </div>
    );
  };

  const [isEditingDescription, setIsEditingDescription] = useState(false);

  const handleDescriptionChange = (e: React.ChangeEvent<HTMLTextAreaElement>) => {
    const updatedColumns = dataset.columns.map(c => ({
      ...c,
      description: c.name === column.name ? e.target.value : c.description
    }));

    setDataset({
      ...dataset,
      columns: updatedColumns
    });
  };

  const handleDescriptionSave = () => {
    setIsEditingDescription(false);
  };

  const handleDescriptionKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      setIsEditingDescription(false);
    } else if (e.key === 'Escape') {
      setIsEditingDescription(false);
    }
  };

  const handleDescriptionClick = () => {
    setIsEditingDescription(true);
  };

  const nullPercentage = column.statistics?.null_count && column.statistics?.num_rows
    ? Math.round((column.statistics.null_count / column.statistics.num_rows) * 100)
    : 0;

  const renderStrategySpecificInfo = (type: 'training' | 'inference') => {
    const strategy = type === 'training' ? training : inference;
    if (strategy.method === 'most_frequent' && column.statistics?.most_frequent_value) {
      return (
        <div className="mt-4 bg-blue-50 rounded-lg p-4">
          <span className="text-sm font-medium text-blue-700">
            Most Frequent Value: {column.statistics.most_frequent_value}
          </span>
        </div>
      );
    } else if (strategy.method === 'forward_fill' && column.statistics?.last_value) {
      return (
        <div className="mt-4 bg-yellow-50 rounded-lg p-4">
          <span className="text-sm font-medium text-yellow-700">
            Last Value: {column.statistics.last_value}
          </span>
        </div>
      );
    }
    return null;
  };

  return (
    <div className="space-y-8">
      {/* Column Header Section */}
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <div className="flex-1">
            <h2 className="text-2xl font-semibold text-gray-900">{column.name}</h2>
            <div className="mt-1 flex items-start gap-2">
              {isEditingDescription ? (
                <div className="flex-1">
                  <textarea
                    value={column.description || ''}
                    onChange={handleDescriptionChange}
                    onBlur={handleDescriptionSave}
                    onKeyDown={handleDescriptionKeyDown}
                    className="w-full px-2 py-1 text-sm text-gray-900 border border-blue-500 rounded-md focus:outline-none focus:ring-2 focus:ring-blue-500"
                    rows={2}
                    autoFocus
                    placeholder="Enter column description..."
                  />
                  <p className="mt-1 text-xs text-gray-500">
                    Press Enter to save, Escape to cancel
                  </p>
                </div>
              ) : (
                <>
                  <p
                    className="text-sm text-gray-500 flex-1 cursor-pointer"
                    onClick={handleDescriptionClick}
                  >
                    {column.description || 'No description provided'}
                  </p>
                  <button
                    onClick={handleDescriptionClick}
                    className="p-1 text-gray-400 hover:text-gray-600 rounded-md hover:bg-gray-100"
                  >
                    <Pencil className="w-4 h-4" />
                  </button>
                </>
              )}
            </div>
          </div>
          {column.is_target && (
            <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800">
              Target Column
            </span>
          )}
        </div>

        <div className="grid grid-cols-3 gap-4 mt-6">
          <div className="bg-gray-50 rounded-lg p-4">
            <span className="text-sm text-gray-500">Type</span>
            <p className="text-lg font-medium text-gray-900 mt-1">{column.datatype}</p>
          </div>
          <div className="bg-gray-50 rounded-lg p-4">
            <span className="text-sm text-gray-500">Unique Values</span>
            <p className="text-lg font-medium text-gray-900 mt-1">
              {column.statistics?.unique_count?.toLocaleString() ?? 'N/A'}
            </p>
          </div>
          <div className="bg-gray-50 rounded-lg p-4">
            <span className="text-sm text-gray-500">Null Values</span>
            <p className="text-lg font-medium text-gray-900 mt-1">
              {column.statistics?.null_count?.toLocaleString() ?? '0'}
            </p>
          </div>
        </div>

        {column.statistics?.null_count ? (
          <div className="mt-6">
            <div className="flex items-center justify-between mb-2">
              <span className="text-sm font-medium text-gray-700">Null Distribution</span>
              <span className="text-sm text-gray-500">
                {nullPercentage}% of values are null
              </span>
            </div>
            <div className="relative h-2 bg-gray-100 rounded-full overflow-hidden">
              <div
                className="absolute top-0 left-0 h-full bg-yellow-400 rounded-full"
                style={{ width: `${nullPercentage}%` }}
              />
            </div>
          </div>
        ) : (
          <div className="mt-6 bg-green-50 rounded-lg p-4">
            <div className="flex items-center gap-2">
              <div className="w-2 h-2 bg-green-400 rounded-full" />
              <span className="text-sm text-green-700">This column has no null values</span>
            </div>
          </div>
        )}

        {column.statistics?.sample_data && (
          <div className="mt-6">
            <h4 className="text-sm font-medium text-gray-700 mb-2">Sample Values</h4>
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="flex flex-wrap gap-2">
                {column.statistics.sample_data.map((value, index) => (
                  <span key={index} className="px-2 py-1 bg-gray-100 rounded text-sm text-gray-700">
                    {String(value)}
                  </span>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Preprocessing Strategy Section */}


      {/* Data Type Section */}
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
          <Settings2 className="w-5 h-5 text-gray-500" />
          Data Type Configuration
        </h3>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Column Type
            </label>
            <select
              value={selectedType}
              onChange={(e) => handleColumnTypeChange(e.target.value as ColumnType)}
              className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              {constants.column_types.map(type => (
                <option key={type.value} value={type.value}>
                  {type.label}
                </option>
              ))}
            </select>
          </div>

          <div className="bg-gray-50 rounded-md p-4">
            <h4 className="text-sm font-medium text-gray-900 mb-2">Sample Data</h4>
            <div className="space-y-2">
              {Array.isArray(column.sample_values) ? column.sample_values.slice(0, 3).map((value: any, index: number) => (
                <span key={index} className="m-1 flex-items items-center">
                  <Badge>
                    {String(value)}
                  </Badge>
                </span>
              )) : []}
            </div>
          </div>
        </div>
      </div>

      {/* Preprocessing Strategy Section */}
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
          <Wrench className="w-5 h-5 text-gray-500" />
          Preprocessing Strategy
        </h3>

        <div className="space-y-6">
          <div>
            <div className="flex items-center justify-between mb-4">
              <label className="block text-sm font-medium text-gray-700">
                Training Strategy
              </label>
              <div className="flex items-center gap-2">
                <input
                  type="checkbox"
                  id="useDistinctInference"
                  checked={useDistinctInference}
                  onChange={(e) => {
                    setUseDistinctInference(e.target.checked);
                    onUpdate(
                      training,
                      e.target.checked ? inference : undefined,
                      e.target.checked
                    );
                  }}
                  className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <label htmlFor="useDistinctInference" className="text-sm text-gray-700">
                  Use different strategy for inference
                </label>
              </div>
            </div>

            <div className={useDistinctInference ? "grid grid-cols-2 gap-6" : ""}>
              <div>
                <select
                  value={training.method}
                  onChange={(e) => handleStrategyChange('training', e.target.value as PreprocessingStep['method'])}
                  className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="none">No preprocessing</option>
                  {constants.preprocessing_strategies[selectedType]?.map((strategy: { value: string; label: string; }) => (
                    <option key={strategy.value} value={strategy.value}>
                      {strategy.label}
                    </option>
                  ))}
                </select>

                {renderStrategySpecificInfo('training')}
                {renderConstantValueInput('training')}
               {(column.datatype === 'categorical' && training.method === 'categorical') && (
                  <div className="mt-4 space-y-4 bg-gray-50 rounded-lg p-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Minimum Category Instances
                      </label>
                      <input
                        type="number"
                        min="1"
                        value={training.params.categorical_min}
                        onChange={(e) => handleCategoricalParamChange('training', {
                          categorical_min: parseInt(e.target.value)
                        })}
                        className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                      />
                      <p className="mt-1 text-sm text-gray-500">
                        Categories with fewer instances will be grouped as "OTHER"
                      </p>
                    </div>
                  </div>
                )}
                {(column.datatype === 'categorical' && training.method !== 'none') && (
                  <div className="mt-4 space-y-4 bg-gray-50 rounded-lg p-4">
                    <h4 className="text-sm font-medium text-gray-900 mb-2">Encoding</h4>
                    <div className="flex items-center gap-2">
                      <input
                        type="radio"
                        id="oneHotEncode"
                        name="encoding"
                        checked={training.params.one_hot}
                        onChange={() => handleCategoricalParamChange('training', {
                          one_hot: true,
                          ordinal_encoding: false
                        })}
                        className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <label htmlFor="oneHotEncode" className="text-sm text-gray-700">
                        One-hot encode categories
                      </label>
                    </div>
                    <div className="flex items-center gap-2">
                      <input
                        type="radio"
                        id="ordinalEncode"
                        name="encoding"
                        checked={training.params.ordinal_encoding}
                        onChange={() => handleCategoricalParamChange('training', {
                          one_hot: false,
                          ordinal_encoding: true
                        })}
                        className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <label htmlFor="ordinalEncode" className="text-sm text-gray-700">
                        Ordinal encode categories
                      </label>
                    </div>
                  </div>
                )}
              </div>

              {useDistinctInference && (
                <div>
                  <div className="flex items-center gap-2 mb-2">
                    <ArrowRight className="w-4 h-4 text-gray-400" />
                    <span className="text-sm font-medium text-gray-700">
                      Inference Strategy
                    </span>
                  </div>
                  <select
                    value={inference.method}
                    onChange={(e) => handleStrategyChange('inference', e.target.value as PreprocessingStep['method'])}
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  >
                    <option value="none">No preprocessing</option>
                    {constants.preprocessing_strategies[selectedType]?.map((strategy: { value: string; label: string; }) => (
                      <option key={strategy.value} value={strategy.value}>
                        {strategy.label}
                      </option>
                    ))}
                  </select>

                  {renderConstantValueInput('inference')}
                </div>
              )}
            </div>
          </div>

          {isNumericType(selectedType) && training.method !== 'none' && (
            <div className="border-t pt-4">
              <h4 className="text-sm font-medium text-gray-900 mb-2">Clip Values</h4>
              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Min Value
                  </label>
                  <input
                    type="number"
                    value={training.params?.clip?.min ?? ''}
                    onChange={(e) => {
                      handleClipChange('training', {
                        min: e.target.value ? Number(e.target.value) : undefined
                      });
                    }}
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    placeholder="No minimum"
                  />
                </div>
                <div>
                  <label className="block text-sm font-medium text-gray-700 mb-1">
                    Max Value
                  </label>
                  <input
                    type="number"
                    value={training.params?.clip?.max ?? ''}
                    onChange={(e) => {
                      handleClipChange('training', {
                        max: e.target.value ? Number(e.target.value) : undefined
                      });
                    }}
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    placeholder="No maximum"
                  />
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

    </div>
  );
}