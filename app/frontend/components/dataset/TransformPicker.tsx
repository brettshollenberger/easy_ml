import React, { useState } from 'react';
import { GripVertical, X, Plus, ArrowDown, ArrowUp, Settings2 } from 'lucide-react';
import { SearchableSelect } from '../SearchableSelect';

interface Transform {
  id: string;
  name: string;
  description: string;
  type: 'calculation' | 'lookup' | 'conversion';
  config?: Record<string, any>;
}

const AVAILABLE_TRANSFORMS: Transform[] = [
  {
    id: 'days_in_business',
    name: 'Days in Business',
    description: 'Calculate the number of days between signup date and current date',
    type: 'calculation'
  },
  {
    id: 'did_convert',
    name: 'Did Convert',
    description: 'Boolean flag indicating if the user converted',
    type: 'conversion'
  },
  {
    id: 'zip_code_data',
    name: 'ZIP Code Demographics',
    description: 'Enrich with demographic data based on ZIP code',
    type: 'lookup',
    config: {
      fields: ['median_income', 'population', 'avg_age']
    }
  },
  {
    id: 'lifetime_value',
    name: 'Customer Lifetime Value',
    description: 'Calculate total revenue from all customer transactions',
    type: 'calculation'
  },
  {
    id: 'churn_risk',
    name: 'Churn Risk Score',
    description: 'Calculate churn probability based on activity patterns',
    type: 'calculation'
  },
  {
    id: 'industry_segment',
    name: 'Industry Segment',
    description: 'Map company to standardized industry segments',
    type: 'lookup',
    config: {
      source: 'industry_mapping'
    }
  }
];

interface TransformPickerProps {
  selectedTransforms: Transform[];
  onTransformsChange: (transforms: Transform[]) => void;
}

export function TransformPicker({ selectedTransforms, onTransformsChange }: TransformPickerProps) {
  const [draggedIndex, setDraggedIndex] = useState<number | null>(null);

  const availableTransforms = AVAILABLE_TRANSFORMS.filter(
    transform => !selectedTransforms.find(t => t.id === transform.id)
  );

  const handleAdd = (transformId: string) => {
    const transform = AVAILABLE_TRANSFORMS.find(t => t.id === transformId);
    if (transform) {
      onTransformsChange([...selectedTransforms, transform]);
    }
  };

  const handleRemove = (index: number) => {
    const newTransforms = [...selectedTransforms];
    newTransforms.splice(index, 1);
    onTransformsChange(newTransforms);
  };

  const handleMoveUp = (index: number) => {
    if (index === 0) return;
    const newTransforms = [...selectedTransforms];
    [newTransforms[index - 1], newTransforms[index]] = [newTransforms[index], newTransforms[index - 1]];
    onTransformsChange(newTransforms);
  };

  const handleMoveDown = (index: number) => {
    if (index === selectedTransforms.length - 1) return;
    const newTransforms = [...selectedTransforms];
    [newTransforms[index], newTransforms[index + 1]] = [newTransforms[index + 1], newTransforms[index]];
    onTransformsChange(newTransforms);
  };

  const handleDragStart = (index: number) => {
    setDraggedIndex(index);
  };

  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault();
    if (draggedIndex === null || draggedIndex === index) return;

    const newTransforms = [...selectedTransforms];
    const [draggedTransform] = newTransforms.splice(draggedIndex, 1);
    newTransforms.splice(index, 0, draggedTransform);
    onTransformsChange(newTransforms);
    setDraggedIndex(index);
  };

  return (
    <div className="space-y-4">
      {/* Add Transform */}
      <div className="flex items-center gap-4">
        <div className="flex-1">
          <SearchableSelect
            options={availableTransforms.map(transform => ({
              value: transform.id,
              label: transform.name,
              description: transform.description
            }))}
            value={null}
            onChange={(value) => handleAdd(value as string)}
            placeholder="Add a transform..."
          />
        </div>
        <button
          type="button"
          className="p-2 text-gray-400 hover:text-gray-600"
          title="Configure transforms"
        >
          <Settings2 className="w-5 h-5" />
        </button>
      </div>

      {/* Selected Transforms */}
      <div className="space-y-2">
        {selectedTransforms.map((transform, index) => (
          <div
            key={transform.id}
            draggable
            onDragStart={() => handleDragStart(index)}
            onDragOver={(e) => handleDragOver(e, index)}
            onDragEnd={() => setDraggedIndex(null)}
            className={`flex items-center gap-3 p-3 bg-white border rounded-lg ${
              draggedIndex === index ? 'border-blue-500 shadow-lg' : 'border-gray-200'
            }`}
          >
            <button
              type="button"
              className="p-1 text-gray-400 hover:text-gray-600 cursor-grab active:cursor-grabbing"
            >
              <GripVertical className="w-4 h-4" />
            </button>

            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="font-medium text-gray-900">{transform.name}</span>
                <span className={`text-xs px-2 py-0.5 rounded-full ${
                  transform.type === 'calculation' ? 'bg-blue-100 text-blue-800' :
                  transform.type === 'lookup' ? 'bg-purple-100 text-purple-800' :
                  'bg-green-100 text-green-800'
                }`}>
                  {transform.type}
                </span>
              </div>
              <p className="text-sm text-gray-500 truncate">{transform.description}</p>
            </div>

            <div className="flex items-center gap-1">
              <button
                type="button"
                onClick={() => handleMoveUp(index)}
                disabled={index === 0}
                className="p-1 text-gray-400 hover:text-gray-600 disabled:opacity-50"
                title="Move up"
              >
                <ArrowUp className="w-4 h-4" />
              </button>
              <button
                type="button"
                onClick={() => handleMoveDown(index)}
                disabled={index === selectedTransforms.length - 1}
                className="p-1 text-gray-400 hover:text-gray-600 disabled:opacity-50"
                title="Move down"
              >
                <ArrowDown className="w-4 h-4" />
              </button>
              <button
                type="button"
                onClick={() => handleRemove(index)}
                className="p-1 text-gray-400 hover:text-red-600"
                title="Remove transform"
              >
                <X className="w-4 h-4" />
              </button>
            </div>
          </div>
        ))}

        {selectedTransforms.length === 0 && (
          <div className="text-center py-8 bg-gray-50 border-2 border-dashed border-gray-200 rounded-lg">
            <Plus className="w-8 h-8 text-gray-400 mx-auto mb-2" />
            <p className="text-sm text-gray-500">
              Add transforms to enrich your dataset
            </p>
          </div>
        )}
      </div>
    </div>
  );
}