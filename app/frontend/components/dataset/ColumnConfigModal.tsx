import React, { useState, useMemo } from 'react';
import { X, Settings2, AlertCircle, Target, EyeOff, Search } from 'lucide-react';
import { PreprocessingConfig } from './PreprocessingConfig';
import { ColumnList } from './ColumnList';
import { ColumnFilters } from './ColumnFilters';
import type { Column } from '../../types';

interface ColumnConfigModalProps {
  isOpen: boolean;
  onClose: () => void;
  columns: Column[];
  onSave: (config: ColumnConfiguration) => void;
  existingConfig?: ColumnConfiguration;
}

export interface ColumnConfiguration {
  trainingColumns: string[];
  targetColumn?: string;
  dropIfNull: string[];
  preprocessing: {
    [columnName: string]: {
      training: PreprocessingStrategy;
      inference?: PreprocessingStrategy;
      useDistinctInference: boolean;
    };
  };
}

export type PreprocessingStrategy = {
  method: 'mean' | 'median' | 'forward_fill' | 'most_frequent' | 'categorical' | 'constant' | 'today' | 'label';
  params?: {
    constantValue?: string | number;
    minInstancesForCategory?: number;
    oneHotEncode?: boolean;
    clip?: {
      min?: number;
      max?: number;
    };
    labelMapping?: {
      [key: string]: number;
    };
  };
  statistics?: {
    meanValue?: number;
    medianValue?: number;
    mostFrequentValue?: string | number;
    categories?: string[];
    otherExamples?: string[];
    lastKnownValue?: string | number;
    uniqueValues?: string[];
    nullCount?: number;
    affectedRows?: { id: number; values: Record<string, any> }[];
  };
};

export function ColumnConfigModal({ 
  isOpen, 
  onClose, 
  columns, 
  onSave,
  constants,
  existingConfig 
}: ColumnConfigModalProps) {
  const [config, setConfig] = useState<ColumnConfiguration>(existingConfig || {
    trainingColumns: columns.map(c => c.name),
    dropIfNull: [],
    preprocessing: {}
  });

  const [selectedColumn, setSelectedColumn] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilters, setActiveFilters] = useState<{
    view: 'all' | 'training' | 'hidden' | 'preprocessed' | 'nulls';
    types: string[];
  }>({
    view: 'all',
    types: []
  });

  const filteredColumns = useMemo(() => {
    return columns.filter(column => {
      const matchesSearch = column.name.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesType = activeFilters.types.length === 0 || activeFilters.types.includes(column.type);
      
      // View-specific filtering
      const matchesView = (() => {
        switch (activeFilters.view) {
          case 'training':
            return config.trainingColumns.includes(column.name) && !config.dropIfNull.includes(column.name);
          case 'hidden':
            return config.dropIfNull.includes(column.name);
          case 'preprocessed':
            return !!config.preprocessing[column.name];
          case 'nulls':
            return (column.statistics?.nullCount || 0) > 0;
          default:
            return true;
        }
      })();
      
      return matchesSearch && matchesType && matchesView;
    });
  }, [columns, searchQuery, activeFilters, config]);

  const columnStats = useMemo(() => ({
    total: columns.length,
    filtered: filteredColumns.length,
    training: config.trainingColumns.filter(c => !config.dropIfNull.includes(c)).length,
    hidden: config.dropIfNull.length,
    withPreprocessing: Object.keys(config.preprocessing).length,
    withNulls: columns.filter(c => (c.statistics?.nullCount || 0) > 0).length
  }), [columns, filteredColumns, config]);

  const columnTypes = useMemo(() => 
    Array.from(new Set(columns.map(c => c.type))),
    [columns]
  );

  const handleColumnSelect = (columnName: string) => {
    setSelectedColumn(columnName);
  };

  const toggleTrainingColumn = (columnName: string) => {
    if (columnName === config.targetColumn) return;

    setConfig(prev => ({
      ...prev,
      trainingColumns: prev.trainingColumns.includes(columnName)
        ? prev.trainingColumns.filter(c => c !== columnName)
        : [...prev.trainingColumns, columnName]
    }));
  };

  const toggleHiddenColumn = (columnName: string) => {
    setConfig(prev => ({
      ...prev,
      dropIfNull: prev.dropIfNull.includes(columnName)
        ? prev.dropIfNull.filter(c => c !== columnName)
        : [...prev.dropIfNull, columnName]
    }));
  };

  const setTargetColumn = (columnName: string | undefined) => {
    setConfig(prev => {
      const trainingColumns = columnName 
        ? [...new Set([...prev.trainingColumns, columnName])]
        : prev.trainingColumns;

      return {
        ...prev,
        targetColumn: columnName,
        trainingColumns,
        preprocessing: {
          ...prev.preprocessing,
          ...(columnName && {
            [columnName]: {
              training: {
                method: 'label',
                params: {
                  labelMapping: {},
                },
                statistics: {
                  uniqueValues: columns.find(c => c.name === columnName)?.statistics?.uniqueCount 
                    ? Array(columns.find(c => c.name === columnName)?.statistics?.uniqueCount).fill('').map((_, i) => `Value ${i + 1}`)
                    : []
                }
              },
              useDistinctInference: false
            }
          })
        }
      };
    });
  };

  const handlePreprocessingUpdate = (
    columnName: string,
    training: PreprocessingStrategy,
    inference: PreprocessingStrategy | undefined,
    useDistinctInference: boolean
  ) => {
    setConfig(prev => ({
      ...prev,
      preprocessing: {
        ...prev.preprocessing,
        [columnName]: {
          training,
          inference,
          useDistinctInference
        }
      }
    }));
  };

  if (!isOpen) return null;

  const selectedColumnData = selectedColumn ? columns.find(c => c.name === selectedColumn) : null;
  const selectedColumnConfig = selectedColumn ? config.preprocessing[selectedColumn] : undefined;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg w-full max-w-6xl max-h-[90vh] overflow-hidden">
        <div className="flex justify-between items-center p-4 border-b">
          <h2 className="text-lg font-semibold">Column Configuration</h2>
          <div className="flex items-center gap-4">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search columns..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9 pr-4 py-2 w-64 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
            <button
              onClick={onClose}
              className="text-gray-500 hover:text-gray-700"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="grid grid-cols-7 h-[calc(90vh-4rem)]">
          <div className="col-span-3 border-r overflow-hidden flex flex-col">
            <div className="p-4 border-b">
              <label className="block text-sm font-medium text-gray-700 mb-2">
                Target Column
              </label>
              <select
                value={config.targetColumn || ''}
                onChange={(e) => setTargetColumn(e.target.value || undefined)}
                className="w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              >
                <option value="">Select target column...</option>
                {columns.map(column => (
                  <option key={column.name} value={column.name}>
                    {column.name}
                  </option>
                ))}
              </select>
            </div>

            <ColumnFilters
              types={columnTypes}
              activeFilters={activeFilters}
              onFilterChange={setActiveFilters}
              columnStats={columnStats}
              columns={columns}
              config={config}
            />

            <div className="flex-1 overflow-y-auto p-4">
              <ColumnList
                columns={filteredColumns}
                config={config}
                selectedColumn={selectedColumn}
                onColumnSelect={handleColumnSelect}
                onToggleTraining={toggleTrainingColumn}
                onToggleHidden={toggleHiddenColumn}
              />
            </div>
          </div>

          <div className="col-span-4 overflow-y-auto p-4">
            {selectedColumnData ? (
              <PreprocessingConfig
                column={selectedColumnData}
                config={selectedColumnConfig}
                isTarget={selectedColumn === config.targetColumn}
                onUpdate={(training, inference, useDistinctInference) => 
                  handlePreprocessingUpdate(selectedColumn, training, inference, useDistinctInference)
                }
              />
            ) : (
              <div className="h-full flex items-center justify-center text-gray-500">
                Select a column to configure preprocessing
              </div>
            )}
          </div>
        </div>

        <div className="border-t p-4 flex justify-between items-center">
          <div className="text-sm text-gray-600">
            {config.trainingColumns.length} columns selected for training
          </div>
          <div className="flex gap-3">
            <button
              onClick={onClose}
              className="px-4 py-2 text-gray-700 hover:text-gray-900"
            >
              Cancel
            </button>
            <button
              onClick={() => {
                onSave(config);
                onClose();
              }}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
            >
              Save Configuration
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}