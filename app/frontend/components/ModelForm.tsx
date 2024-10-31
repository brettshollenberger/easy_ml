import React, { useState, useEffect } from 'react';
// import { useNavigate } from 'react-router-dom';
import { Calendar, Lock } from 'lucide-react';
import { SearchableSelect } from './SearchableSelect';
import { ScheduleModal } from './ScheduleModal';

interface ModelFormProps {
  initialData?: {
    name: string;
    modelType: string;
    datasetId: number;
    task: string;
    objective?: string;
    metrics?: string[];
  };
  onSubmit: (data: any) => void;
  isEditing?: boolean;
}

const TASKS = [
  { 
    value: 'classification',
    label: 'Classification',
    description: 'Predict categorical outcomes or class labels'
  },
  { 
    value: 'regression',
    label: 'Regression',
    description: 'Predict continuous numerical values'
  }
];

const OBJECTIVES = {
  classification: [
    { value: 'binary:logistic', label: 'Binary Logistic', description: 'For binary classification' },
    { value: 'binary:hinge', label: 'Binary Hinge', description: 'For binary classification with hinge loss' },
    { value: 'multi:softmax', label: 'Multiclass Softmax', description: 'For multiclass classification' },
    { value: 'multi:softprob', label: 'Multiclass Probability', description: 'For multiclass classification with probability output' }
  ],
  regression: [
    { value: 'reg:squarederror', label: 'Squared Error', description: 'For regression with squared loss' },
    { value: 'reg:logistic', label: 'Logistic', description: 'For regression with logistic loss' }
  ]
};

const METRICS = {
  classification: [
    { value: 'accuracy', label: 'Accuracy', direction: 'maximize' },
    { value: 'precision', label: 'Precision', direction: 'maximize' },
    { value: 'recall', label: 'Recall', direction: 'maximize' },
    { value: 'f1', label: 'F1 Score', direction: 'maximize' }
  ],
  regression: [
    { value: 'rmse', label: 'Root Mean Squared Error', direction: 'minimize' },
    { value: 'mae', label: 'Mean Absolute Error', direction: 'minimize' },
    { value: 'mse', label: 'Mean Squared Error', direction: 'minimize' },
    { value: 'r2', label: 'R² Score', direction: 'maximize' }
  ]
};

export function ModelForm({ initialData, onSubmit, isEditing }: ModelFormProps) {
  const navigate = useNavigate();
  const [showScheduleModal, setShowScheduleModal] = useState(false);
  const [formData, setFormData] = useState({
    name: initialData?.name || '',
    modelType: initialData?.modelType || 'xgboost',
    datasetId: initialData?.datasetId || '',
    task: initialData?.task || 'classification',
    objective: initialData?.objective || 'binary:logistic',
    metrics: initialData?.metrics || ['accuracy']
  });

  // Update objective and metrics when task changes
  useEffect(() => {
    if (formData.task === 'classification') {
      setFormData(prev => ({
        ...prev,
        objective: 'binary:logistic',
        metrics: ['accuracy']
      }));
    } else {
      setFormData(prev => ({
        ...prev,
        objective: 'reg:squarederror',
        metrics: ['rmse']
      }));
    }
  }, [formData.task]);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    onSubmit(formData);
  };

  const selectedDataset = datasets.find(d => d.id === formData.datasetId);

  return (
    <form onSubmit={handleSubmit} className="space-y-8">
      <div className="flex justify-between items-center border-b pb-4">
        <h3 className="text-lg font-medium text-gray-900">Model Configuration</h3>
        <button
          type="button"
          onClick={() => setShowScheduleModal(true)}
          className="inline-flex items-center gap-2 px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          <Calendar className="w-4 h-4" />
          Configure Schedule
        </button>
      </div>

      <div className="space-y-6">
        <div className="grid grid-cols-2 gap-6">
          <div>
            <label htmlFor="name" className="block text-sm font-medium text-gray-700 mb-1">
              Model Name
            </label>
            <input
              type="text"
              id="name"
              value={formData.name}
              onChange={(e) => setFormData({ ...formData, name: e.target.value })}
              className="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              required
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Model Type
            </label>
            <SearchableSelect
              options={[{ value: 'xgboost', label: 'XGBoost', description: 'Gradient boosting framework' }]}
              value={formData.modelType}
              onChange={(value) => setFormData({ ...formData, modelType: value as string })}
              placeholder="Select model type"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Dataset
            </label>
            {isEditing ? (
              <div className="flex items-center gap-2 p-2 bg-gray-50 rounded-md border border-gray-200">
                <Lock className="w-4 h-4 text-gray-400" />
                <span className="text-gray-700">{selectedDataset?.name}</span>
              </div>
            ) : (
              <SearchableSelect
                options={datasets.map(dataset => ({
                  value: dataset.id,
                  label: dataset.name,
                  description: `${dataset.rowCount.toLocaleString()} rows`
                }))}
                value={formData.datasetId}
                onChange={(value) => setFormData({ ...formData, datasetId: value as number })}
                placeholder="Select dataset"
              />
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Task
            </label>
            <SearchableSelect
              options={TASKS}
              value={formData.task}
              onChange={(value) => setFormData({ ...formData, task: value as string })}
              placeholder="Select task"
            />
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Objective
            </label>
            <SearchableSelect
              options={OBJECTIVES[formData.task as keyof typeof OBJECTIVES]}
              value={formData.objective}
              onChange={(value) => setFormData({ ...formData, objective: value as string })}
              placeholder="Select objective"
            />
          </div>
        </div>

        <div>
          <label className="block text-sm font-medium text-gray-700 mb-2">
            Metrics
          </label>
          <div className="grid grid-cols-2 gap-4">
            {METRICS[formData.task as keyof typeof METRICS].map(metric => (
              <label
                key={metric.value}
                className="relative flex items-center px-4 py-3 bg-white border rounded-lg hover:bg-gray-50 cursor-pointer"
              >
                <input
                  type="checkbox"
                  checked={formData.metrics.includes(metric.value)}
                  onChange={(e) => {
                    const metrics = e.target.checked
                      ? [...formData.metrics, metric.value]
                      : formData.metrics.filter(m => m !== metric.value);
                    setFormData({ ...formData, metrics });
                  }}
                  className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                />
                <div className="ml-3">
                  <span className="block text-sm font-medium text-gray-900">
                    {metric.label}
                  </span>
                  <span className="block text-xs text-gray-500">
                    {metric.direction === 'maximize' ? 'Higher is better' : 'Lower is better'}
                  </span>
                </div>
              </label>
            ))}
          </div>
        </div>
      </div>

      <div className="flex justify-end gap-3 pt-4 border-t">
        <button
          type="button"
          onClick={() => navigate('/models')}
          className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
        >
          Cancel
        </button>
        <button
          type="submit"
          className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
        >
          {isEditing ? 'Save Changes' : 'Create Model'}
        </button>
      </div>

      <ScheduleModal
        isOpen={showScheduleModal}
        onClose={() => setShowScheduleModal(false)}
        onSave={(scheduleData) => {
          setFormData(prev => ({
            ...prev,
            ...scheduleData
          }));
          setShowScheduleModal(false);
        }}
        initialData={{
          task: formData.task,
          metrics: formData.metrics
        }}
      />
    </form>
  );
}