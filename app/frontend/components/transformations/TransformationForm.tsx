import React, { useState, useEffect } from 'react';
import { AlertCircle } from 'lucide-react';
import type { Dataset, TransformationGroup } from '../../types';
import { CodeEditor } from './CodeEditor';
import { DataPreview } from './DataPreview';

interface TransformationFormProps {
  datasets: Dataset[];
  groups: TransformationGroup[];
  initialData?: {
    name: string;
    description: string;
    groupId: number;
    testDatasetId: number;
    inputColumns: string[];
    outputColumns: string[];
    code: string;
  };
  onSubmit: (data: any) => void;
  onCancel: () => void;
}

export function TransformationForm({
  datasets,
  groups,
  initialData,
  onSubmit,
  onCancel
}: TransformationFormProps) {
  const [formData, setFormData] = useState({
    name: initialData?.name || '',
    description: initialData?.description || '',
    groupId: initialData?.groupId || '',
    testDatasetId: initialData?.testDatasetId || '',
    inputColumns: initialData?.inputColumns || [],
    outputColumns: initialData?.outputColumns || [],
    code: initialData?.code || ''
  });

  const [selectedDataset, setSelectedDataset] = useState<Dataset | null>(
    initialData?.testDatasetId
      ? datasets.find(d => d.id === initialData.testDatasetId) || null
      : null
  );

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  const handleDatasetChange = (datasetId: string) => {
    const dataset = datasets.find(d => d.id === Number(datasetId)) || null;
    setSelectedDataset(dataset);
    setFormData(prev => ({
      ...prev,
      testDatasetId: datasetId,
      inputColumns: [],
      outputColumns: []
    }));
  };

  const toggleColumn = (columnName: string, type: 'input' | 'output') => {
    setFormData(prev => ({
      ...prev,
      [type === 'input' ? 'inputColumns' : 'outputColumns']: 
        prev[type === 'input' ? 'inputColumns' : 'outputColumns'].includes(columnName)
          ? prev[type === 'input' ? 'inputColumns' : 'outputColumns'].filter(c => c !== columnName)
          : [...prev[type === 'input' ? 'inputColumns' : 'outputColumns'], columnName]
    }));
  };

  return (
    <form onSubmit={handleSubmit} className="p-6 space-y-8">
      <div className="grid grid-cols-2 gap-6">
        <div>
          <label htmlFor="name" className="block text-sm font-medium text-gray-700">
            Name
          </label>
          <input
            type="text"
            id="name"
            value={formData.name}
            onChange={(e) => setFormData({ ...formData, name: e.target.value })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            required
          />
        </div>

        <div>
          <label htmlFor="group" className="block text-sm font-medium text-gray-700">
            Group
          </label>
          <select
            id="group"
            value={formData.groupId}
            onChange={(e) => setFormData({ ...formData, groupId: e.target.value })}
            className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            required
          >
            <option value="">Select a group...</option>
            {groups.map((group) => (
              <option key={group.id} value={group.id}>
                {group.name}
              </option>
            ))}
          </select>
        </div>
      </div>

      <div>
        <label htmlFor="description" className="block text-sm font-medium text-gray-700">
          Description
        </label>
        <textarea
          id="description"
          value={formData.description}
          onChange={(e) => setFormData({ ...formData, description: e.target.value })}
          rows={3}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
        />
      </div>

      <div>
        <label htmlFor="dataset" className="block text-sm font-medium text-gray-700">
          Test Dataset
        </label>
        <select
          id="dataset"
          value={formData.testDatasetId}
          onChange={(e) => handleDatasetChange(e.target.value)}
          className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
          required
        >
          <option value="">Select a dataset...</option>
          {datasets.map((dataset) => (
            <option key={dataset.id} value={dataset.id}>
              {dataset.name}
            </option>
          ))}
        </select>
      </div>

      {selectedDataset && (
        <div className="grid grid-cols-2 gap-6">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Input Columns
            </label>
            <div className="space-y-2">
              {selectedDataset.columns.map((column) => (
                <label
                  key={column.name}
                  className="flex items-center gap-2 p-2 rounded-md hover:bg-gray-50"
                >
                  <input
                    type="checkbox"
                    checked={formData.inputColumns.includes(column.name)}
                    onChange={() => toggleColumn(column.name, 'input')}
                    className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <span className="text-sm text-gray-900">{column.name}</span>
                  <span className="text-xs text-gray-500">({column.type})</span>
                </label>
              ))}
            </div>
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Output Columns
            </label>
            <div className="space-y-2">
              {selectedDataset.columns.map((column) => (
                <label
                  key={column.name}
                  className="flex items-center gap-2 p-2 rounded-md hover:bg-gray-50"
                >
                  <input
                    type="checkbox"
                    checked={formData.outputColumns.includes(column.name)}
                    onChange={() => toggleColumn(column.name, 'output')}
                    className="rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                  />
                  <span className="text-sm text-gray-900">{column.name}</span>
                  <span className="text-xs text-gray-500">({column.type})</span>
                </label>
              ))}
            </div>
          </div>
        </div>
      )}

      <div>
        <label className="block text-sm font-medium text-gray-700 mb-2">
          Transformation Code
        </label>
        <div className="bg-gray-50 rounded-lg p-4">
          <CodeEditor
            value={formData.code}
            onChange={(code) => setFormData({ ...formData, code })}
            language="ruby"
          />
        </div>
      </div>

      {selectedDataset && formData.code && (
        <div>
          <h3 className="text-sm font-medium text-gray-900 mb-2">Preview</h3>
          <DataPreview
            dataset={selectedDataset}
            code={formData.code}
            inputColumns={formData.inputColumns}
            outputColumns={formData.outputColumns}
          />
        </div>
      )}

      <div className="flex justify-end gap-3 pt-6 border-t">
        <button
          type="button"
          onClick={onCancel}
          className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
        >
          Cancel
        </button>
        <button
          type="submit"
          className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          {initialData ? 'Save Changes' : 'Create Transformation'}
        </button>
      </div>
    </form>
  );
}