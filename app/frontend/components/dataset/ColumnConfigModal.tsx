import React, { useState, useMemo, useCallback, useEffect } from 'react';
import { X, Settings2, AlertCircle, Target, EyeOff, Search } from 'lucide-react';
import { PreprocessingConfig } from './PreprocessingConfig';
import { ColumnList } from './ColumnList';
import { ColumnFilters } from './ColumnFilters';
import { AutosaveIndicator } from './AutosaveIndicator';
import { SearchableSelect } from '../SearchableSelect';
import { useAutosave } from '../../hooks/useAutosave';
import { Dataset, Column } from "../../types/dataset";
import { PreprocessingStrategy } from "../../types";
interface ColumnConfig {
  targetColumn?: string;
}

interface ColumnConfigModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialDataset: Dataset;
  onSave: (updates: { columnId: number; updates: Partial<Column> }[]) => void;
  constants: any;
}

export function ColumnConfigModal({ 
  isOpen, 
  onClose, 
  initialDataset, 
  onSave,
  constants
}: ColumnConfigModalProps) {
  const [dataset, setDataset] = useState<Dataset>(initialDataset);

  const [config, setConfig] = useState<ColumnConfig>({ targetColumn: dataset.target });
  const [selectedColumn, setSelectedColumn] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [activeFilters, setActiveFilters] = useState<{
    view: 'all' | 'training' | 'hidden' | 'preprocessed' | 'nulls';
    types: string[];
  }>({
    view: 'all',
    types: []
  });

  const handleSave = useCallback(async (data: Dataset) => {
    await onSave(data);
  }, [onSave]);

  const { saving, saved, error } = useAutosave(dataset, handleSave, 2000);

  const filteredColumns = useMemo(() => {
    return dataset.columns.filter(column => {
      const matchesSearch = column.name.toLowerCase().includes(searchQuery.toLowerCase());
      const matchesType = activeFilters.types.length === 0 || activeFilters.types.includes(column.datatype);
      
      const matchesView = (() => {
        switch (activeFilters.view) {
          case 'training':
            return !column.hidden && !column.drop_if_null;
          case 'hidden':
            return column.hidden;
          case 'preprocessed':
            return column.preprocessing_steps != null;
          case 'nulls':
            return (column.statistics?.null_count || 0) > 0;
          default:
            return true;
        }
      })();
      
      return matchesSearch && matchesType && matchesView;
    });
  }, [dataset.columns, searchQuery, activeFilters]);

  const columnStats = useMemo(() => ({
    total: dataset.columns.length,
    filtered: filteredColumns.length,
    training: dataset.columns.filter(c => !c.hidden && !c.drop_if_null).length,
    hidden: dataset.columns.filter(c => c.hidden).length,
    withPreprocessing: dataset.columns.filter(c => c.preprocessing_steps != null).length,
    withNulls: dataset.columns.filter(c => (c.statistics?.null_count || 0) > 0).length
  }), [dataset.columns, filteredColumns]);

  const columnTypes = useMemo(() => 
    Array.from(new Set(dataset.columns.map(c => c.datatype))),
    [dataset.columns]
  );

  const handleColumnSelect = (columnName: string) => {
    setSelectedColumn(columnName);
  };

  const toggleTrainingColumn = (columnName: string) => {
    const column = dataset.columns.find(c => c.name === columnName);
    if (!column) return;

    onSave([{
      columnId: column.id,
      updates: { hidden: !column.hidden }
    }]);
  };

  const toggleHiddenColumn = (columnName: string) => {
    console.log(columnName)
    const updatedColumns = dataset.columns.map(c => ({
      ...c,
      hidden: c.name === columnName ? !c.hidden : c.hidden,
    }));

    setDataset({
      ...dataset,
      columns: updatedColumns,
    });
  };

  const setTargetColumn = (columnName: string) => {
    const name = String(columnName);
    setConfig({targetColumn: columnName})
    const updatedColumns = dataset.columns.map(c => ({
      ...c,
      is_target: c.name === name,
    }));

    setDataset({
      ...dataset,
      columns: updatedColumns,
    });
  };

  const handlePreprocessingUpdate = (
    columnName: string,
    training: PreprocessingStrategy,
    inference: PreprocessingStrategy | undefined,
    useDistinctInference: boolean
  ) => {
    const column = dataset.columns.find(c => c.name === columnName);
    if (!column) return;

    onSave([{
      columnId: column.id,
      updates: {
        preprocessing_steps: {
          training,
          inference,
          useDistinctInference
        }
      }
    }]);
  };

  if (!isOpen) return null;

  const selectedColumnData = selectedColumn ? dataset.columns.find(c => c.name === selectedColumn) : null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg w-full max-w-6xl max-h-[90vh] overflow-hidden">
        <div className="flex justify-between items-center p-4 border-b">
          <h2 className="text-lg font-semibold">Column Configuration</h2>
          <div className="flex items-center gap-4">
            <div className="min-w-[0px]">
              <AutosaveIndicator saving={saving} saved={saved} error={error} />
            </div>
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
              <label className="block text-sm font-medium text-gray-700">
                Target Column
              </label>
              <SearchableSelect
                options={dataset.columns.map(column => (
                  {
                    value: column.name,
                    label: column.name
                  }
                ))}
                value={config.targetColumn || ''}
                onChange={(value) => value && setTargetColumn(value)}
              />
            </div>
            <ColumnFilters
              types={columnTypes}
              activeFilters={activeFilters}
              onFilterChange={setActiveFilters}
              columnStats={columnStats}
              columns={dataset.columns}
            />

            <div className="flex-1 overflow-y-auto p-4">
              <ColumnList
                columns={filteredColumns}
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
                constants={constants}
                isTarget={selectedColumnData.is_target || false}
                onUpdate={(training, inference, useDistinctInference) => 
                  handlePreprocessingUpdate(selectedColumnData.name, training, inference, useDistinctInference)
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
            {dataset.columns.filter(c => !c.hidden).length} columns selected for training
          </div>
          <div className="flex gap-3">
            <button
              onClick={onClose}
              className="px-4 py-2 text-gray-700 hover:text-gray-900"
            >
              Cancel
            </button>
            <button
              onClick={onClose}
              className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
            >
              Close
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}