import React from 'react';
import { Filter, Database, Wrench, Eye, EyeOff, AlertTriangle } from 'lucide-react';
import type { Column } from '../../types';

interface ColumnFiltersProps {
  types: string[];
  activeFilters: {
    view: 'all' | 'training' | 'hidden' | 'preprocessed' | 'nulls';
    types: string[];
  };
  onFilterChange: (filters: {
    view: 'all' | 'training' | 'hidden' | 'preprocessed' | 'nulls';
    types: string[];
  }) => void;
  columnStats: {
    total: number;
    filtered: number;
    training: number;
    hidden: number;
    withPreprocessing: number;
    withNulls: number;
  };
  columns: Column[];
  config: any; // Using ColumnConfiguration type from parent
}

export function ColumnFilters({
  types,
  activeFilters,
  onFilterChange,
  columnStats,
  columns,
  config
}: ColumnFiltersProps) {
  const toggleType = (type: string) => {
    onFilterChange({
      ...activeFilters,
      types: activeFilters.types.includes(type)
        ? activeFilters.types.filter(t => t !== type)
        : [...activeFilters.types, type]
    });
  };

  const getViewStats = (view: typeof activeFilters.view) => {
    switch (view) {
      case 'training':
        return `${columnStats.training} columns`;
      case 'hidden':
        return `${columnStats.hidden} columns`;
      case 'preprocessed':
        return `${columnStats.withPreprocessing} columns`;
      case 'nulls':
        return `${columnStats.withNulls} columns`;
      default:
        return `${columnStats.total} columns`;
    }
  };

  const calculateNullPercentage = (column: Column) => {
    if (!column.statistics?.nullCount || !column.statistics?.rowCount) return 0;
    return (column.statistics.nullCount / column.statistics.rowCount) * 100;
  };

  return (
    <div className="p-4 border-b space-y-4">
      <div className="flex items-center justify-between">
        <h3 className="text-sm font-medium text-gray-900 flex items-center gap-2">
          <Filter className="w-4 h-4" />
          Column Views
        </h3>
        <div className="text-sm text-gray-500">
          Showing {columnStats.filtered} of {columnStats.total} columns
        </div>
      </div>

      <div className="space-y-4">
        {/* View Selector */}
        <div className="flex flex-wrap gap-2">
          <button
            onClick={() => onFilterChange({ ...activeFilters, view: 'all' })}
            className={`inline-flex items-center gap-1 px-3 py-1.5 rounded-md text-sm font-medium ${
              activeFilters.view === 'all'
                ? 'bg-gray-100 text-gray-900'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <Database className="w-4 h-4" />
            All
            <span className="text-xs text-gray-500 ml-1">
              ({getViewStats('all')})
            </span>
          </button>
          <button
            onClick={() => onFilterChange({ ...activeFilters, view: 'training' })}
            className={`inline-flex items-center gap-1 px-3 py-1.5 rounded-md text-sm font-medium ${
              activeFilters.view === 'training'
                ? 'bg-green-100 text-green-900'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <Eye className="w-4 h-4" />
            Training
            <span className="text-xs text-gray-500 ml-1">
              ({getViewStats('training')})
            </span>
          </button>
          <button
            onClick={() => onFilterChange({ ...activeFilters, view: 'hidden' })}
            className={`inline-flex items-center gap-1 px-3 py-1.5 rounded-md text-sm font-medium ${
              activeFilters.view === 'hidden'
                ? 'bg-gray-100 text-gray-900'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <EyeOff className="w-4 h-4" />
            Hidden
            <span className="text-xs text-gray-500 ml-1">
              ({getViewStats('hidden')})
            </span>
          </button>
          <button
            onClick={() => onFilterChange({ ...activeFilters, view: 'preprocessed' })}
            className={`inline-flex items-center gap-1 px-3 py-1.5 rounded-md text-sm font-medium ${
              activeFilters.view === 'preprocessed'
                ? 'bg-blue-100 text-blue-900'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <Wrench className="w-4 h-4" />
            Preprocessed
            <span className="text-xs text-gray-500 ml-1">
              ({getViewStats('preprocessed')})
            </span>
          </button>
          <button
            onClick={() => onFilterChange({ ...activeFilters, view: 'nulls' })}
            className={`inline-flex items-center gap-1 px-3 py-1.5 rounded-md text-sm font-medium ${
              activeFilters.view === 'nulls'
                ? 'bg-yellow-100 text-yellow-900'
                : 'text-gray-600 hover:bg-gray-50'
            }`}
          >
            <AlertTriangle className="w-4 h-4" />
            Has Nulls
            <span className="text-xs text-gray-500 ml-1">
              ({getViewStats('nulls')})
            </span>
          </button>
        </div>

        {/* Column Types */}
        <div>
          <label className="text-xs font-medium text-gray-700 mb-2 block">
            Column Types
          </label>
          <div className="flex flex-wrap gap-2">
            {types.map(type => (
              <button
                key={type}
                onClick={() => toggleType(type)}
                className={`px-2 py-1 rounded-md text-xs font-medium ${
                  activeFilters.types.includes(type)
                    ? 'bg-blue-100 text-blue-700'
                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                }`}
              >
                {type}
              </button>
            ))}
          </div>
        </div>

        {/* View-specific information */}
        {activeFilters.view === 'preprocessed' && (
          <div className="bg-blue-50 rounded-lg p-3">
            <h4 className="text-sm font-medium text-blue-900 mb-2">Preprocessing Overview</h4>
            <div className="space-y-2">
              {columns
                .filter(col => config.preprocessing[col.name])
                .map(col => (
                  <div key={col.name} className="flex items-center justify-between text-sm">
                    <span className="text-blue-800">{col.name}</span>
                    <span className="text-blue-600">
                      {config.preprocessing[col.name].training.method}
                    </span>
                  </div>
                ))}
            </div>
          </div>
        )}

        {activeFilters.view === 'nulls' && (
          <div className="bg-yellow-50 rounded-lg p-3">
            <h4 className="text-sm font-medium text-yellow-900 mb-2">Null Value Distribution</h4>
            <div className="space-y-2">
              {columns
                .filter(col => col.statistics?.nullCount && col.statistics.nullCount > 0)
                .sort((a, b) => calculateNullPercentage(b) - calculateNullPercentage(a))
                .map(col => (
                  <div key={col.name} className="flex items-center gap-2">
                    <span className="text-yellow-800 text-sm min-w-[120px]">{col.name}</span>
                    <div className="flex-1 h-2 bg-yellow-100 rounded-full overflow-hidden">
                      <div
                        className="h-full bg-yellow-400 rounded-full"
                        style={{ width: `${calculateNullPercentage(col)}%` }}
                      />
                    </div>
                    <span className="text-yellow-800 text-xs">
                      {calculateNullPercentage(col).toFixed(1)}% null
                    </span>
                  </div>
                ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
}