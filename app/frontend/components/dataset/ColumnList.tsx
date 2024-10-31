import React from 'react';
import { Settings2, AlertCircle, Target, EyeOff, Eye } from 'lucide-react';
import type { Column } from '../../types';
import type { ColumnConfiguration } from './ColumnConfigModal';

interface ColumnListProps {
  columns: Column[];
  config: ColumnConfiguration;
  selectedColumn: string | null;
  onColumnSelect: (columnName: string) => void;
  onToggleTraining: (columnName: string) => void;
  onToggleHidden: (columnName: string) => void;
}

export function ColumnList({
  columns,
  config,
  selectedColumn,
  onColumnSelect,
  onToggleTraining,
  onToggleHidden
}: ColumnListProps) {
  return (
    <div className="space-y-2">
      {columns.map(column => (
        <div
          key={column.name}
          className={`p-3 rounded-lg border ${
            selectedColumn === column.name
              ? 'border-blue-500 bg-blue-50'
              : column.name === config.targetColumn
              ? 'border-purple-500 bg-purple-50'
              : config.dropIfNull.includes(column.name)
              ? 'border-gray-200 bg-gray-50'
              : 'border-gray-200 hover:border-gray-300'
          } transition-colors duration-150`}
        >
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2">
              {column.name === config.targetColumn && (
                <Target className="w-4 h-4 text-purple-500" />
              )}
              <span className={`font-medium ${config.dropIfNull.includes(column.name) ? 'text-gray-500' : 'text-gray-900'}`}>
                {column.name}
              </span>
              <span className="text-xs px-2 py-0.5 bg-gray-100 text-gray-600 rounded-full">
                {column.type}
              </span>
            </div>
            <div className="flex items-center gap-2">
              {column.name !== config.targetColumn && (
                <button
                  onClick={() => onToggleHidden(column.name)}
                  className={`p-1 rounded hover:bg-gray-100 ${
                    config.dropIfNull.includes(column.name)
                      ? 'text-gray-500'
                      : 'text-gray-400 hover:text-gray-600'
                  }`}
                  title={config.dropIfNull.includes(column.name) ? 'Show column' : 'Hide column'}
                >
                  {config.dropIfNull.includes(column.name) ? (
                    <EyeOff className="w-4 h-4" />
                  ) : (
                    <Eye className="w-4 h-4" />
                  )}
                </button>
              )}
              <button
                onClick={() => onColumnSelect(column.name)}
                className="p-1 rounded text-gray-400 hover:text-gray-600 hover:bg-gray-100"
                title="Configure preprocessing"
              >
                <Settings2 className="w-4 h-4" />
              </button>
            </div>
          </div>
          <div className="text-sm text-gray-500">
            {column.description && (
              <p className={`mb-1 line-clamp-1 ${config.dropIfNull.includes(column.name) ? 'text-gray-400' : ''}`}>
                {column.description}
              </p>
            )}
            <div className="flex flex-wrap gap-2">
              {config.preprocessing[column.name] && (
                <div className="flex items-center gap-1 text-blue-600">
                  <AlertCircle className="w-3 h-3" />
                  <span className="text-xs">Preprocessing configured</span>
                </div>
              )}
              {config.dropIfNull.includes(column.name) && column.statistics?.nullCount && (
                <div className="flex items-center gap-1 text-gray-400">
                  <EyeOff className="w-3 h-3" />
                  <span className="text-xs">Hidden from training</span>
                </div>
              )}
            </div>
          </div>
        </div>
      ))}
    </div>
  );
}