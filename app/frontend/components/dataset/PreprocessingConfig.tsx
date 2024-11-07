import React, { useState, useEffect } from 'react';
import { Settings2, AlertTriangle, Wrench, ArrowRight } from 'lucide-react';
import type { Column, ColumnType, PreprocessingConstants } from '../../types';
import type { PreprocessingStrategy } from './ColumnConfigModal';

interface PreprocessingConfigProps {
  column: Column;
  config?: {
    training: PreprocessingStrategy;
    inference?: PreprocessingStrategy;
    useDistinctInference: boolean;
  };
  isTarget: boolean;
  onUpdate: (
    training: PreprocessingStrategy, 
    inference: PreprocessingStrategy | undefined,
    useDistinctInference: boolean
  ) => void;
  constants: PreprocessingConstants;
}

const isNumericType = (type: ColumnType): boolean => 
  type === 'float' || type === 'integer';

export function PreprocessingConfig({ 
  column, 
  config, 
  isTarget, 
  onUpdate,
  constants 
}: PreprocessingConfigProps) {
  console.log(`CONSTANTS`)
  console.log(constants)
  const [selectedType, setSelectedType] = useState<ColumnType>(column.datatype);
  const [useDistinctInference, setUseDistinctInference] = useState(
    config?.useDistinctInference ?? false
  );
  
  const [training, setTraining] = useState<PreprocessingStrategy>(() => ({
    ...config?.training || { 
      method: isTarget ? 'label' : 'none',
      params: isTarget ? { 
        labelMapping: {},
        threshold: isNumericType(column.datatype) ? 0 : undefined
      } : undefined
    }
  }));
  
  const [inference, setInference] = useState<PreprocessingStrategy>(() => ({
    ...config?.inference || { method: 'none' }
  }));

  // Update selectedType when column changes
  useEffect(() => {
    setSelectedType(column.datatype);
  }, [column.datatype]);

  const handleStrategyChange = (
    type: 'training' | 'inference',
    method: PreprocessingStrategy['method']
  ) => {
    const newStrategy = {
      method,
      params: method === 'categorical' ? { 
        oneHotEncode: true,
        minInstancesForCategory: 100
      } : undefined
    };

    if (type === 'training') {
      setTraining(newStrategy);
      onUpdate(newStrategy, useDistinctInference ? inference : undefined, useDistinctInference);
    } else {
      setInference(newStrategy);
      onUpdate(training, newStrategy, useDistinctInference);
    }
  };

  return (
    <div className="space-y-8">
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
              onChange={(e) => setSelectedType(e.target.value as ColumnType)}
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
              {column.statistics?.sample?.slice(0, 3).map((value: any, index: number) => (
                <div key={index} className="text-sm text-gray-600">
                  {String(value)}
                </div>
              ))}
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
                  onChange={(e) => handleStrategyChange('training', e.target.value as PreprocessingStrategy['method'])}
                  className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="none">No preprocessing</option>
                  {constants.preprocessing_strategies[selectedType]?.map(strategy => (
                    <option key={strategy.value} value={strategy.value}>
                      {strategy.label}
                    </option>
                  ))}
                </select>

                {training.method === 'categorical' && (
                  <div className="mt-4 space-y-4">
                    <div>
                      <label className="block text-sm font-medium text-gray-700 mb-1">
                        Minimum Instances for Category
                      </label>
                      <input
                        type="number"
                        value={training.params?.minInstancesForCategory ?? 100}
                        onChange={(e) => {
                          const newTraining = {
                            ...training,
                            params: {
                              ...training.params,
                              minInstancesForCategory: parseInt(e.target.value)
                            }
                          };
                          setTraining(newTraining);
                          onUpdate(newTraining, useDistinctInference ? inference : undefined, useDistinctInference);
                        }}
                        className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                      />
                    </div>
                    <div className="flex items-center gap-2">
                      <input
                        type="checkbox"
                        id="oneHotEncode"
                        checked={training.params?.oneHotEncode ?? true}
                        onChange={(e) => {
                          const newTraining = {
                            ...training,
                            params: {
                              ...training.params,
                              oneHotEncode: e.target.checked
                            }
                          };
                          setTraining(newTraining);
                          onUpdate(newTraining, useDistinctInference ? inference : undefined, useDistinctInference);
                        }}
                        className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                      />
                      <label htmlFor="oneHotEncode" className="text-sm text-gray-700">
                        One-hot encode categories
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
                    onChange={(e) => handleStrategyChange('inference', e.target.value as PreprocessingStrategy['method'])}
                    className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  >
                    <option value="none">No preprocessing</option>
                    {constants.preprocessing_strategies[selectedType]?.map(strategy => (
                      <option key={strategy.value} value={strategy.value}>
                        {strategy.label}
                      </option>
                    ))}
                  </select>
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
                      const newTraining = {
                        ...training,
                        params: {
                          ...training.params,
                          clip: {
                            ...training.params?.clip,
                            min: e.target.value ? Number(e.target.value) : undefined
                          }
                        }
                      };
                      setTraining(newTraining);
                      onUpdate(newTraining, useDistinctInference ? inference : undefined, useDistinctInference);
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
                      const newTraining = {
                        ...training,
                        params: {
                          ...training.params,
                          clip: {
                            ...training.params?.clip,
                            max: e.target.value ? Number(e.target.value) : undefined
                          }
                        }
                      };
                      setTraining(newTraining);
                      onUpdate(newTraining, useDistinctInference ? inference : undefined, useDistinctInference);
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

      {/* Preview Section */}
      <div className="bg-white rounded-lg border border-gray-200 p-6">
        <h3 className="text-lg font-medium text-gray-900 mb-4">
          Data Preview
        </h3>
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-4">
            <div>
              <h4 className="text-sm font-medium text-gray-700 mb-2">Original Data</h4>
              <div className="bg-gray-50 rounded-md p-4 space-y-2">
                {column.statistics?.sample?.slice(0, 3).map((value, index) => (
                  <div key={index} className="text-sm text-gray-600">
                    {String(value)}
                  </div>
                ))}
              </div>
            </div>
            <div>
              <h4 className="text-sm font-medium text-gray-700 mb-2">Processed Data</h4>
              <div className="bg-gray-50 rounded-md p-4 space-y-2">
                {column.statistics?.sample?.slice(0, 3).map((value, index) => (
                  <div key={index} className="text-sm text-gray-600">
                    {training.method === 'none' ? String(value) :
                     training.method === 'mean' ? '123.45' :
                     training.method === 'median' ? '100.00' :
                     training.method === 'most_frequent' ? 'most common value' :
                     training.method === 'constant' ? training.params?.constantValue :
                     String(value)}
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}