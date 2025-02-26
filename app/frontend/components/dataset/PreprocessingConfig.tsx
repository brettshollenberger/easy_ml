import React, { useState, useEffect } from 'react';
import { Settings2, Wrench, ArrowRight, Pencil, Trash2, Database, Calculator, GitBranch, Brain, HardDrive, Maximize2, Minimize2 } from 'lucide-react';
import type { Dataset, Column, ColumnType, PreprocessingConstants, PreprocessingSteps, PreprocessingStep } from '../../types/dataset';
import { Badge } from "@/components/ui/badge";
import { SearchableSelect } from '../SearchableSelect';

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

const createPreprocessingStep = (steps?: PreprocessingStep): PreprocessingStep => ({
  method: steps?.method || 'none',
  params: {
    constant: steps?.params?.constant,
    categorical_min: steps?.params?.categorical_min ?? 100,
    one_hot: steps?.params?.one_hot ?? true,
    ordinal_encoding: steps?.params?.ordinal_encoding ?? false,
    clip: steps?.params?.clip,
    llm: steps?.params?.llm,
    model: steps?.params?.model,
    dimensions: steps?.params?.dimensions,
    preset: steps?.params?.preset,
  },
});

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
  
  const selectedType = column.datatype as ColumnType;
  
  const [training, setTraining] = useState<PreprocessingStep>(() => 
    createPreprocessingStep(column.preprocessing_steps?.training)
  );
  
  const [inference, setInference] = useState<PreprocessingStep>(() => 
    createPreprocessingStep(column.preprocessing_steps?.inference)
  );

  // Update all states when column changes
  useEffect(() => {
    setTraining(createPreprocessingStep(column.preprocessing_steps?.training));
    setInference(createPreprocessingStep(column.preprocessing_steps?.inference));
  }, [column.id]); // Only re-run when column changes

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
        constant: value
      }
    };

    setStrategy(newStrategy);
    if (type === 'training') {
      onUpdate(newStrategy, useDistinctInference ? inference : undefined, useDistinctInference);
    } else {
      onUpdate(training, newStrategy, useDistinctInference);
    }
  };

  const handleEmbeddingParamChange = (
    type: 'training' | 'inference',
    updates: Partial<PreprocessingStep['params']>
  ) => {
    const strategy = type === 'training' ? training : inference;
    const setStrategy = type === 'training' ? setTraining : setInference;
    
    const newStrategy: PreprocessingStep = {
      ...strategy,
      params: {
        ...strategy.params,
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
            value={strategy.params?.constant ?? ''}
            onChange={(e) => handleConstantValueChange(type, e.target.value)}
            className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="Enter a number..."
          />
        ) : (
          <input
            type="text"
            value={strategy.params?.constant ?? ''}
            onChange={(e) => handleConstantValueChange(type, e.target.value)}
            className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            placeholder="Enter a value..."
          />
        )}
      </div>
    );
  };

  const renderEncodingConfig = (type: 'training' | 'inference') => {
    const strategy = type === 'training' ? training : inference;
    if (!strategy || strategy.method === 'embedding') return null;

    return (
      <div className="mt-4 space-y-4 bg-gray-50 rounded-lg p-4">
        <h4 className="text-sm font-medium text-gray-900 mb-2">Encoding</h4>
        <div className="flex items-center gap-2">
          <input
            type="radio"
            id="oneHotEncode"
            name="encoding"
            checked={strategy.params.one_hot}
            onChange={() => handleCategoricalParamChange(type, {
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
            checked={strategy.params.ordinal_encoding}
            onChange={() => handleCategoricalParamChange(type, {
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
    );
  };

  const renderEmbeddingConfig = (type: 'training' | 'inference') => {
    const strategy = type === 'training' ? training : inference;
    if (strategy.method !== 'embedding') return null;

    const embeddingConstants = constants.embedding_constants;
    const providers = embeddingConstants.providers;
    const models = embeddingConstants.models;
    const compressionPresets = Object.entries(embeddingConstants.compression_presets).map(([key, preset]) => ({
      value: key,
      label: key.split('_').map(word => word.charAt(0).toUpperCase() + word.slice(1)).join(' '),
      description: preset.description,
      variance_target: preset.variance_target,
    }));

    const getModelsForProvider = (provider: string) => {
      return models[provider] || [];
    };

    const getCurrentModelDimensions = () => {
      const provider = strategy.params?.llm || 'openai';
      const modelValue = strategy.params?.model || getModelsForProvider(provider)[0]?.value;
      const model = getModelsForProvider(provider).find(m => m.value === modelValue);
      return model?.dimensions || 1536; // Default to 1536 if not found
    };

    const getPresetForVariance = (variance: number) => {
      return compressionPresets.find(preset => 
        Math.abs(preset.variance_target - variance) < 0.05
      )?.value || null;
    };

    const getVarianceForPreset = (presetValue: string) => {
      return compressionPresets.find(preset => 
        preset.value === presetValue
      )?.variance_target || 0.85; // Default to balanced
    };

    const handleDimensionsChange = (dimensions: number) => {
      const variance = dimensions / getCurrentModelDimensions(); // Normalize to 0-1
      const matchingPreset = getPresetForVariance(variance);
      
      handleEmbeddingParamChange(type, { 
        dimensions,
        preset: matchingPreset,
      });
    };

    const handlePresetChange = (presetValue: string) => {
      const variance = getVarianceForPreset(presetValue);
      const dimensions = Math.round(variance * getCurrentModelDimensions());
      
      handleEmbeddingParamChange(type, {
        dimensions,
        preset: presetValue,
      });
    };

    useEffect(() => {
      if (strategy.method === 'embedding' && !strategy.params?.dimensions) {
        handleEmbeddingParamChange(type, {
          ...strategy.params,
          dimensions: getCurrentModelDimensions(),
          preset: 'high_quality',
        });
      }
    }, [strategy.method, strategy.params?.llm, strategy.params?.model]);

    return (
      <div className="space-y-6 mt-8">
        <div className="bg-blue-50 rounded-lg p-4">
          <div className="flex gap-2">
            <Brain className="w-5 h-5 text-blue-500 flex-shrink-0" />
            <div>
              <h4 className="text-sm font-medium text-blue-900">Text Embeddings</h4>
              <p className="text-sm text-blue-700 mt-1">
                Convert text into numerical vectors for machine learning, preserving semantic meaning while optimizing for storage and performance.
              </p>
            </div>
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Embedding Provider
            </label>
            <SearchableSelect
              value={strategy.params?.llm || 'openai'}
              onChange={(value) => {
                const newModels = getModelsForProvider(value);
                const firstModel = newModels[0]?.value;
                const dimensions = newModels[0]?.dimensions || 1536;
                
                handleEmbeddingParamChange(type, {
                  ...strategy.params,
                  llm: value,
                  model: firstModel,
                  dimensions: dimensions,
                  preset: 'high_quality',
                });
              }}
              options={providers}
              placeholder="Select a provider"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Model
            </label>
            <SearchableSelect
              value={strategy.params?.model || getModelsForProvider(strategy.params?.llm || 'openai')[0]?.value}
              onChange={(value) => {
                const model = getModelsForProvider(strategy.params?.llm || 'openai').find(m => m.value === value);
                const dimensions = model?.dimensions || 1536;
                
                handleEmbeddingParamChange(type, {
                  ...strategy.params,
                  model: value,
                  dimensions: dimensions,
                  preset: 'high_quality',
                });
              }}
              options={getModelsForProvider(strategy.params?.llm || 'openai')}
              placeholder="Select a model"
            />
          </div>

          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <h4 className="text-sm font-medium text-gray-900">
                Storage & Quality
              </h4>
              <div className="flex items-center gap-2 text-sm text-gray-500">
                <Minimize2 className="w-4 h-4" />
                <span>Storage</span>
                <span className="mx-2">•</span>
                <span>Quality</span>
                <Maximize2 className="w-4 h-4" />
              </div>
            </div>

            <div className="space-y-6">
              <div>
                <div className="flex items-center justify-between mb-2">
                  <span className="text-sm text-gray-600">Target Dimensions</span>
                  <span className="text-sm font-medium text-gray-900">{strategy.params?.dimensions || getCurrentModelDimensions()}</span>
                </div>
                <input
                  type="range"
                  min="2"
                  max={getCurrentModelDimensions()}
                  value={strategy.params?.dimensions || getCurrentModelDimensions()}
                  onChange={(e) => handleDimensionsChange(parseInt(e.target.value))}
                  className="w-full"
                />
                <div className="flex justify-between text-xs text-gray-500 mt-1">
                  <span>2</span>
                  <span>{getCurrentModelDimensions()}</span>
                </div>
              </div>

              <div className="space-y-3">
                <h5 className="text-sm font-medium text-gray-900">Quality Presets</h5>
                {compressionPresets.map((preset) => (
                  <div
                    key={preset.value}
                    onClick={() => handlePresetChange(preset.value)}
                    className={`p-4 rounded-lg border transition-colors cursor-pointer
                      ${strategy.params?.preset === preset.value
                        ? 'border-blue-500 bg-blue-50'
                        : 'border-gray-200 hover:border-gray-300 bg-white'
                      }`}
                  >
                    <div className="flex items-center justify-between">
                      <div className="flex items-center gap-2">
                        <input
                          type="radio"
                          checked={strategy.params?.preset === preset.value}
                          onChange={() => handlePresetChange(preset.value)}
                          className="rounded-full border-gray-300 text-blue-600 focus:ring-blue-500"
                        />
                        <span className="font-medium text-gray-900">{preset.label}</span>
                      </div>
                    </div>
                    <p className="text-sm text-gray-600 mt-1 ml-6">{preset.description}</p>
                  </div>
                ))}
              </div>

              <div className="space-y-4">
                <div className="bg-gray-50 rounded-lg p-4">
                  <div className="flex items-start gap-2">
                    <HardDrive className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                      <h5 className="text-sm font-medium text-gray-900">Storage Efficiency</h5>
                      <div className="mt-2">
                        <div className="w-full bg-gray-200 rounded-full h-2.5">
                          <div 
                            className="h-full bg-green-600 rounded-full"
                            style={{ width: `${100 - ((strategy.params?.dimensions || 24) / getCurrentModelDimensions()) * 100}%` }}
                          />
                        </div>
                        <p className="text-sm text-gray-600 mt-2">
                          {strategy.params?.dimensions && strategy.params.dimensions <= getCurrentModelDimensions() * 0.25
                            ? "Optimized for storage. Maintains core meaning while significantly reducing storage requirements."
                            : strategy.params?.dimensions && strategy.params.dimensions <= getCurrentModelDimensions() * 0.5
                            ? "Balanced approach. Good compromise between quality and storage efficiency."
                            : "Prioritizes quality. Preserves more nuanced relationships but requires more storage."}
                        </p>
                      </div>
                    </div>
                  </div>
                </div>

                <div className="bg-gray-50 rounded-lg p-4">
                  <div className="flex items-start gap-2">
                    <Brain className="w-5 h-5 text-gray-400 flex-shrink-0 mt-0.5" />
                    <div className="flex-1">
                      <h5 className="text-sm font-medium text-gray-900">Information Preservation</h5>
                      <div className="mt-2">
                        <div className="w-full bg-gray-200 rounded-full h-2.5">
                          <div 
                            className="bg-blue-600 h-2.5 rounded-full transition-all duration-300"
                            style={{ width: `${((strategy.params?.dimensions || 24) / getCurrentModelDimensions()) * 100}%` }}
                          />
                        </div>
                        <p className="text-sm text-gray-600 mt-2">
                          Preserves approximately {Math.round(((strategy.params?.dimensions || 24) / getCurrentModelDimensions()) * 100)}% of the original information
                        </p>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    );
  };

  const [isEditingDescription, setIsEditingDescription] = useState(false);

  const onToggleDropIfNull = (e: React.ChangeEvent<HTMLInputElement>) => {
    const updatedColumns = dataset.columns.map(c => ({
      ...c,
      drop_if_null: c.name === column.name ? e.target.checked : c.drop_if_null
    }));

    setDataset({
      ...dataset,
      columns: updatedColumns
    });
  };

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

  let nullCount = (column.statistics?.processed?.null_count || column.statistics?.raw?.null_count) || 0;
  let numRows = (column.statistics?.processed?.num_rows) || (column.statistics?.raw?.num_rows) || 0;
  const nullPercentage = nullCount && numRows
    ? ((nullCount / numRows) * 100)
    : 0;

  const nullPercentageProcessed = column.statistics?.processed?.null_count && column.statistics?.processed?.num_rows
    ? ((column.statistics.processed.null_count / column.statistics.processed.num_rows) * 100)
    : 0;

  const totalRows = numRows;

  const renderStrategySpecificInfo = (type: 'training' | 'inference') => {
    const strategy = type === 'training' ? training : inference;
    let content;
    if (strategy.method === 'most_frequent' && column.statistics?.raw.most_frequent_value !== undefined) {
      content = `Most Frequent Value: ${column.statistics.raw.most_frequent_value}`
    } else if (strategy.method === 'ffill') {
      const lastValue = column.statistics?.raw.last_value;
      if (lastValue !== undefined) {
        content = `Forward Fill using Last Value: ${lastValue}`;
      } else {
        content = 'Set date column & apply preprocessing to see last value';
      }
    } else if (strategy.method === 'median' && column.statistics?.raw?.median !== undefined) {
      content = `Median: ${column.statistics.raw.median}`
    } else if (strategy.method === 'mean' && column.statistics?.raw?.mean !== undefined) {
      content = `Mean: ${column.statistics.raw.mean}`
    } else {
      return null;
    }
    return (
      <div className="mt-4 bg-yellow-50 rounded-lg p-4">
        <span className="text-sm font-medium text-yellow-700">
          {content}
        </span>
      </div>
    );
  };

  return (
    <div className="space-y-8">
      {/* Column Header Section */}
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <div className="flex items-center justify-between mb-4">
          <div className="flex-1 max-w-[70%]">
            <h2 className="text-2xl font-semibold text-gray-900">{column.name}</h2>
            <div className="mt-1 flex items-start gap-1">
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
                <div className="flex items-start gap-1 max-w-[100%]">
                  <p
                    className="text-sm text-gray-500 cursor-pointer flex-grow line-clamp-3"
                    onClick={handleDescriptionClick}
                  >
                    {column.description || 'No description provided'}
                  </p>
                  <button
                    onClick={handleDescriptionClick}
                    className="p-1 text-gray-400 hover:text-gray-600 rounded-md hover:bg-gray-100 flex-shrink-0"
                  >
                    <Pencil className="w-4 h-4" />
                  </button>
                </div>
              )}
            </div>
          </div>
          <div className="flex items-center gap-4 flex-shrink-0">
            <div className="relative flex items-center gap-2">
              <div className="absolute right-0 -top-8 flex items-center gap-2">
                {column.required && (
                  <Badge variant="secondary" className="bg-blue-100 text-blue-800">
                    Required
                  </Badge>
                )}
                {column.is_computed && (
                  <Badge variant="secondary" className="bg-purple-100 text-purple-800">
                    <Calculator className="w-3 h-3 mr-1" />
                    Computed
                  </Badge>
                )}
              </div>
              {column.is_target ? (
                <span className="inline-flex items-center px-3 py-1 rounded-full text-sm font-medium bg-purple-100 text-purple-800">
                  Target Column
                </span>
              ) : (
                <div className="flex items-center gap-2">
                  <label className="flex items-center gap-2 text-sm">
                    <input
                      type="checkbox"
                      checked={column.drop_if_null}
                      onChange={onToggleDropIfNull}
                      className="rounded border-gray-300 text-red-600 focus:ring-red-500"
                    />
                    <span className="flex items-center gap-1 text-gray-700">
                      <Trash2 className="w-4 h-4 text-gray-400" />
                      Drop if null
                    </span>
                  </label>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Null Value Statistics */}
        <div className="mt-6 grid grid-cols-2 gap-6">
          <div className="bg-gray-50 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-3">
              <Database className="w-4 h-4 text-gray-500" />
              <h3 className="text-sm font-medium text-gray-900">Raw Data Statistics</h3>
            </div>
            <div className="space-y-2">
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Null Values:</span>
                <span className="font-medium text-gray-900">{column.statistics?.raw?.null_count.toLocaleString()}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Total Rows:</span>
                <span className="font-medium text-gray-900">{totalRows.toLocaleString()}</span>
              </div>
              <div className="flex justify-between text-sm">
                <span className="text-gray-600">Null Percentage:</span>
                <span className="font-medium text-gray-900">{nullPercentage.toFixed(2)}%</span>
              </div>
              <div className="mt-2">
                <div className="w-full bg-gray-200 rounded-full h-2.5">
                  <div 
                    className="h-full bg-blue-600 rounded-full"
                    style={{ width: `${nullPercentage}%` }}
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="bg-gray-50 rounded-lg p-4">
            <div className="flex items-center gap-2 mb-3">
              <Wrench className="w-4 h-4 text-gray-500" />
              <h3 className="text-sm font-medium text-gray-900">Processed Data Statistics</h3>
            </div>
            {dataset?.preprocessing_steps?.training ? (
              <div className="space-y-2">
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Null Values:</span>
                  <span className="font-medium text-gray-900">{column.statistics?.processed?.null_count?.toLocaleString()}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Total Rows:</span>
                  <span className="font-medium text-gray-900">{column.statistics?.processed?.num_rows?.toLocaleString()}</span>
                </div>
                <div className="flex justify-between text-sm">
                  <span className="text-gray-600">Null Percentage:</span>
                  <span className="font-medium text-gray-900">{nullPercentageProcessed.toFixed(2)}%</span>
                </div>
                <div className="mt-2">
                  <div className="w-full bg-gray-200 rounded-full h-2.5">
                    <div 
                      className="h-full bg-blue-600 rounded-full"
                      style={{ width: `${nullPercentageProcessed}%` }}
                    />
                  </div>
                </div>
              </div>
            ) : (
              <div className="text-sm text-gray-500 text-center py-2">
                No preprocessing configured
              </div>
            )}
          </div>
        </div>

        <div className="grid grid-cols-3 gap-4 mt-6">
          <div className="bg-gray-50 rounded-lg p-4">
            <span className="text-sm text-gray-500">Type</span>
            <p className="text-lg font-medium text-gray-900 mt-1">{column.datatype}</p>
          </div>
          <div className="bg-gray-50 rounded-lg p-4">
            <span className="text-sm text-gray-500">Unique Values</span>
            <p className="text-lg font-medium text-gray-900 mt-1">
              {column.statistics?.processed?.unique_count?.toLocaleString() ?? 'N/A'}
            </p>
          </div>
          <div className="bg-gray-50 rounded-lg p-4">
            <span className="text-sm text-gray-500">Null Values</span>
            <p className="text-lg font-medium text-gray-900 mt-1">
              {column.statistics?.processed?.null_count?.toLocaleString() ?? '0'}
            </p>
          </div>
        </div>

        {column.statistics?.processed.null_count ? (
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

        {column.statistics?.raw?.sample_data && (
          <div className="mt-6">
            <h4 className="text-sm font-medium text-gray-700 mb-2">Sample Values</h4>
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="flex flex-wrap gap-2">
                {column.statistics?.raw?.sample_data && column.statistics.raw.sample_data.map((value, index) => (
                  <span key={index} className="px-2 py-1 bg-gray-100 rounded text-sm text-gray-700">
                    {String(value)}
                  </span>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>

      {/* Column Lineage Section */}
      {column.lineage && column.lineage.length > 0 && (
        <div className="bg-white rounded-lg border border-gray-200 p-6">
          <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
            <GitBranch className="w-5 h-5 text-gray-500" />
            Column Lineage
          </h3>
          <div className="space-y-4">
            {column.lineage.map((step, index) => (
              <div key={index} className="flex items-start gap-3">
                <div className={`w-8 h-8 rounded-full flex items-center justify-center flex-shrink-0 ${
                  step.key === 'raw_dataset' 
                    ? 'bg-gray-100' 
                    : step.key === 'computed_by_feature'
                    ? 'bg-purple-100'
                    : 'bg-blue-100'
                }`}>
                  {step.key === 'raw_dataset' ? (
                    <Database className="w-4 h-4 text-gray-600" />
                  ) : step.key === 'computed_by_feature' ? (
                    <Calculator className="w-4 h-4 text-purple-600" />
                  ) : (
                    <Settings2 className="w-4 h-4 text-blue-600" />
                  )}
                </div>
                <div className="flex-1">
                  <div className="flex items-center justify-between">
                    <p className="text-sm font-medium text-gray-900">
                      {step.description}
                    </p>
                    {step.timestamp && (
                      <span className="text-xs text-gray-500">
                        {new Date(step.timestamp).toLocaleString()}
                      </span>
                    )}
                  </div>
                  {index < column.lineage.length - 1 && (
                    <div className="ml-4 mt-2 mb-2 w-0.5 h-4 bg-gray-200" />
                  )}
                </div>
              </div>
            ))}
          </div>
        </div>
      )}

      {/* Data Type Section */}
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4 flex items-center gap-2">
          <Settings2 className="w-5 h-5 text-gray-500" />
          Data Type
        </h3>
        
        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Column Type
            </label>
            <select
              value={selectedType}
              disabled
              className="w-full rounded-md border-gray-300 bg-gray-50 shadow-sm text-gray-700 cursor-not-allowed"
            >
              {constants.column_types.map(type => (
                <option key={type.value} value={type.value}>
                  {type.label}
                </option>
              ))}
            </select>
            <p className="mt-1 text-sm text-gray-500">
              Column type cannot be changed after creation
            </p>
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
                {renderEncodingConfig('training')}
                {renderEmbeddingConfig('training')}
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
                  {renderEncodingConfig('inference')}
                  {renderEmbeddingConfig('inference')}
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