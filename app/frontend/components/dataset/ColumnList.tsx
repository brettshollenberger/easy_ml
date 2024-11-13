import React from 'react';
import { Settings2, AlertCircle, Target, EyeOff, Eye } from 'lucide-react';
import type { Column } from '../../types';
import { usePage } from "@inertiajs/react";

interface ColumnListProps {
  columns: Column[];
  selectedColumn: string | null;
  onColumnSelect: (columnName: string) => void;
  onToggleHidden: (columnName: string) => void;
}

export function ColumnList({
  columns,
  selectedColumn,
  onColumnSelect,
  onToggleHidden
}: ColumnListProps) {
  const { rootPath } = usePage().props;

  return (
    <div className="space-y-2">
      {columns.map(column => (
        <div
          key={column.name}
          className={`p-3 rounded-lg border ${
            selectedColumn === column.name
              ? 'border-blue-500 bg-blue-50'
              : column.is_target
              ? 'border-purple-500 bg-purple-50'
              : column.hidden
              ? 'border-gray-200 bg-gray-50'
              : 'border-gray-200 hover:border-gray-300'
          } transition-colors duration-150`}
        >
          <div className="flex items-center justify-between mb-2">
            <div className="flex items-center gap-2">
              {column.is_target && (
                <Target className="w-4 h-4 text-purple-500" />
              )}
              <span className={`font-medium ${column.hidden ? 'text-gray-500' : 'text-gray-900'}`}>
                {column.name}
              </span>
              <span className="text-xs px-2 py-0.5 bg-gray-100 text-gray-600 rounded-full">
                {column.datatype}
              </span>
            </div>
            <div className="flex items-center gap-2">
              {!column.is_target && (
                <button
                  onClick={() => onToggleHidden(column.name)}
                  className={`p-1 rounded hover:bg-gray-100 ${
                    column.hidden
                      ? 'text-gray-500'
                      : 'text-gray-400 hover:text-gray-600'
                  }`}
                  title={column.hidden ? 'Show column' : 'Hide column'}
                >
                  {column.hidden ? (
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
            <div className="flex flex-wrap gap-2">
              {column.preprocessing_steps && 
               column.preprocessing_steps.training?.method !== 'none' && (
                <div className="flex items-center gap-1 text-blue-600">
                  <AlertCircle className="w-3 h-3" />
                  <span className="text-xs">Preprocessing configured</span>
                </div>
              )}
              {column.hidden && (
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