import React, { useState } from 'react';
import { Database, Search } from 'lucide-react';
import Fuse from 'fuse.js';

const mockDatasources = [
  {
    id: 1,
    name: 'Customer Data Lake',
    bucket: 'customer-data-lake',
  },
  {
    id: 2,
    name: 'Product Analytics',
    bucket: 'analytics-warehouse',
  },
];

const mockColumns = [
  { name: 'user_id', type: 'string', sample: ['usr_123', 'usr_456', 'usr_789'] },
  { name: 'email', type: 'string', sample: ['user@example.com', 'test@test.com'] },
  { name: 'signup_date', type: 'datetime', sample: ['2024-01-15', '2024-02-01'] },
  { name: 'last_login', type: 'datetime', sample: ['2024-03-01', '2024-03-10'] },
  { name: 'created_at', type: 'datetime', sample: ['2024-01-01', '2024-02-15'] },
  { name: 'total_purchases', type: 'numeric', sample: [5, 12, 3] },
  { name: 'lifetime_value', type: 'numeric', sample: [1250.50, 450.75] },
];

interface SplitConfig {
  dateColumn: string;
  monthsTest: number;
  monthsValid: number;
}

export function NewDatasetPage() {
  const [step, setStep] = useState(1);
  const [searchQuery, setSearchQuery] = useState('');
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    datasourceId: '',
    columns: [] as { name: string; selected: boolean }[],
    splitConfig: {
      dateColumn: '',
      monthsTest: 2,
      monthsValid: 1,
    } as SplitConfig,
  });

  const fuse = new Fuse(mockColumns.filter(col => col.type === 'datetime'), {
    keys: ['name'],
    threshold: 0.3,
  });

  const filteredColumns = searchQuery
    ? fuse.search(searchQuery).map(result => result.item)
    : mockColumns.filter(col => col.type === 'datetime');

  const handleDatasourceSelect = () => {
    setFormData({
      ...formData,
      columns: mockColumns.map((col) => ({ name: col.name, selected: true })),
    });
    setStep(2);
  };

  const handleSplitConfig = () => {
    setStep(3);
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    console.log('Creating dataset:', formData);
  };

  return (
    <div className="max-w-2xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-6">
          Create New Dataset
        </h2>

        <div className="mb-8">
          <div className="flex items-center">
            <div
              className={`flex items-center justify-center w-8 h-8 rounded-full ${
                step >= 1 ? 'bg-blue-600' : 'bg-gray-200'
              } text-white font-medium text-sm`}
            >
              1
            </div>
            <div
              className={`flex-1 h-0.5 mx-2 ${
                step >= 2 ? 'bg-blue-600' : 'bg-gray-200'
              }`}
            />
            <div
              className={`flex items-center justify-center w-8 h-8 rounded-full ${
                step >= 2 ? 'bg-blue-600' : 'bg-gray-200'
              } text-white font-medium text-sm`}
            >
              2
            </div>
            <div
              className={`flex-1 h-0.5 mx-2 ${
                step >= 3 ? 'bg-blue-600' : 'bg-gray-200'
              }`}
            />
            <div
              className={`flex items-center justify-center w-8 h-8 rounded-full ${
                step >= 3 ? 'bg-blue-600' : 'bg-gray-200'
              } text-white font-medium text-sm`}
            >
              3
            </div>
          </div>
          <div className="flex justify-between mt-2">
            <span className="text-sm font-medium text-gray-600">
              Basic Info
            </span>
            <span className="text-sm font-medium text-gray-600">
              Select Columns
            </span>
            <span className="text-sm font-medium text-gray-600">
              Configure Split
            </span>
          </div>
        </div>

        {step === 1 ? (
          <div className="space-y-6">
            <div>
              <label
                htmlFor="name"
                className="block text-sm font-medium text-gray-700"
              >
                Dataset Name
              </label>
              <input
                type="text"
                id="name"
                value={formData.name}
                onChange={(e) =>
                  setFormData({ ...formData, name: e.target.value })
                }
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
              />
            </div>

            <div>
              <label
                htmlFor="description"
                className="block text-sm font-medium text-gray-700"
              >
                Description
              </label>
              <textarea
                id="description"
                value={formData.description}
                onChange={(e) =>
                  setFormData({ ...formData, description: e.target.value })
                }
                rows={3}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              />
            </div>

            <div>
              <label
                htmlFor="datasource"
                className="block text-sm font-medium text-gray-700"
              >
                Datasource
              </label>
              <select
                id="datasource"
                value={formData.datasourceId}
                onChange={(e) =>
                  setFormData({ ...formData, datasourceId: e.target.value })
                }
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                required
              >
                <option value="">Select a datasource</option>
                {mockDatasources.map((source) => (
                  <option key={source.id} value={source.id}>
                    {source.name}
                  </option>
                ))}
              </select>
            </div>

            <div className="flex justify-end">
              <button
                type="button"
                onClick={handleDatasourceSelect}
                disabled={!formData.datasourceId || !formData.name}
                className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-300 disabled:cursor-not-allowed"
              >
                Next
              </button>
            </div>
          </div>
        ) : step === 2 ? (
          <div className="space-y-6">
            <div className="space-y-4">
              <div className="flex items-center justify-between pb-4 border-b border-gray-200">
                <span className="text-sm font-medium text-gray-700">
                  Column Name
                </span>
                <span className="text-sm font-medium text-gray-700">Include</span>
              </div>
              {formData.columns.map((column, index) => (
                <div
                  key={column.name}
                  className="flex items-center justify-between"
                >
                  <span className="text-sm text-gray-900">{column.name}</span>
                  <input
                    type="checkbox"
                    checked={column.selected}
                    onChange={(e) => {
                      const newColumns = [...formData.columns];
                      newColumns[index].selected = e.target.checked;
                      setFormData({ ...formData, columns: newColumns });
                    }}
                    className="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
                  />
                </div>
              ))}
            </div>

            <div className="flex justify-between">
              <button
                type="button"
                onClick={() => setStep(1)}
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                Back
              </button>
              <button
                type="button"
                onClick={handleSplitConfig}
                className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Next
              </button>
            </div>
          </div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-6">
            <div className="space-y-4">
              <div className="relative">
                <label
                  htmlFor="dateColumn"
                  className="block text-sm font-medium text-gray-700 mb-1"
                >
                  Date Column for Splitting
                </label>
                <div className="relative">
                  <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search date columns..."
                    className="pl-10 pr-4 py-2 w-full border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
                  />
                </div>
                {searchQuery && (
                  <div className="absolute z-10 w-full mt-1 bg-white shadow-lg rounded-md border border-gray-200">
                    {filteredColumns.map((column) => (
                      <button
                        key={column.name}
                        type="button"
                        onClick={() => {
                          setFormData({
                            ...formData,
                            splitConfig: {
                              ...formData.splitConfig,
                              dateColumn: column.name,
                            },
                          });
                          setSearchQuery('');
                        }}
                        className="w-full px-4 py-2 text-left hover:bg-gray-50 flex items-center gap-2"
                      >
                        <Database className="w-4 h-4 text-gray-400" />
                        <div>
                          <div className="text-sm font-medium">{column.name}</div>
                          <div className="text-xs text-gray-500">
                            Sample: {column.sample.slice(0, 2).join(', ')}
                          </div>
                        </div>
                      </button>
                    ))}
                  </div>
                )}
              </div>

              {formData.splitConfig.dateColumn && (
                <div className="bg-blue-50 rounded-md p-4 flex items-center gap-2">
                  <Database className="w-5 h-5 text-blue-500" />
                  <span className="text-sm text-blue-700">
                    Using {formData.splitConfig.dateColumn} for date-based splitting
                  </span>
                </div>
              )}

              <div className="grid grid-cols-2 gap-4">
                <div>
                  <label
                    htmlFor="monthsTest"
                    className="block text-sm font-medium text-gray-700"
                  >
                    Test Set (months)
                  </label>
                  <input
                    type="number"
                    id="monthsTest"
                    min="1"
                    max="12"
                    value={formData.splitConfig.monthsTest}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        splitConfig: {
                          ...formData.splitConfig,
                          monthsTest: parseInt(e.target.value) || 0,
                        },
                      })
                    }
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>
                <div>
                  <label
                    htmlFor="monthsValid"
                    className="block text-sm font-medium text-gray-700"
                  >
                    Validation Set (months)
                  </label>
                  <input
                    type="number"
                    id="monthsValid"
                    min="1"
                    max="12"
                    value={formData.splitConfig.monthsValid}
                    onChange={(e) =>
                      setFormData({
                        ...formData,
                        splitConfig: {
                          ...formData.splitConfig,
                          monthsValid: parseInt(e.target.value) || 0,
                        },
                      })
                    }
                    className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  />
                </div>
              </div>
            </div>

            <div className="flex justify-between">
              <button
                type="button"
                onClick={() => setStep(2)}
                className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
              >
                Back
              </button>
              <button
                type="submit"
                disabled={!formData.splitConfig.dateColumn}
                className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:bg-gray-300 disabled:cursor-not-allowed"
              >
                Create Dataset
              </button>
            </div>
          </form>
        )}
      </div>
    </div>
  );
}