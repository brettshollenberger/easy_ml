import React, { useState } from 'react';
import { GripVertical, X, Plus, ArrowDown, ArrowUp, Settings2 } from 'lucide-react';
import { SearchableSelect } from '../SearchableSelect';
import { TransformConfigPopover } from './TransformConfigPopover';
import { Transform } from "../../types/dataset";

interface TransformPickerProps {
  options: Transform[];
  initialTransforms?: Transform[];
  onTransformsChange: (transforms: Transform[]) => void;
}

export function TransformPicker({ options, initialTransforms = [], onTransformsChange }: TransformPickerProps) {
  const [selectedTransforms, setSelectedTransforms] = useState<Transform[]>(initialTransforms);
  const [draggedIndex, setDraggedIndex] = useState<number | null>(null);

  console.log(selectedTransforms)
  const availableTransforms = options.filter(
    transform => !selectedTransforms.find(t => t.name === transform.name)
  );

  const updateTransforms = (newTransforms: Transform[]) => {
    const transformsWithPosition = newTransforms.map((transform, index) => ({
      ...transform,
      transform_position: index
    }));
    
    setSelectedTransforms(transformsWithPosition);
    onTransformsChange(transformsWithPosition);
  };

  const handleAddTransform = (transformName: string) => {
    const transform = options.find(t => t.name === transformName);
    if (transform) {
      const newTransform = {
        ...transform,
        transform_position: selectedTransforms.length
      };
      updateTransforms([...selectedTransforms, newTransform]);
    }
  };

  const handleRemove = (index: number) => {
    const newTransforms = [...selectedTransforms];
    newTransforms.splice(index, 1);
    updateTransforms(newTransforms);
  };

  const handleMoveUp = (index: number) => {
    if (index === 0) return;
    const newTransforms = [...selectedTransforms];
    [newTransforms[index - 1], newTransforms[index]] = [newTransforms[index], newTransforms[index - 1]];
    updateTransforms(newTransforms);
  };

  const handleMoveDown = (index: number) => {
    if (index === selectedTransforms.length - 1) return;
    const newTransforms = [...selectedTransforms];
    [newTransforms[index], newTransforms[index + 1]] = [newTransforms[index + 1], newTransforms[index]];
    updateTransforms(newTransforms);
  };

  const handleDragStart = (e: React.DragEvent, index: number) => {
    setDraggedIndex(index);
  };

  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault();
    if (draggedIndex === null || draggedIndex === index) return;

    const newTransforms = [...selectedTransforms];
    const [draggedTransform] = newTransforms.splice(draggedIndex, 1);
    newTransforms.splice(index, 0, draggedTransform);
    updateTransforms(newTransforms);
    setDraggedIndex(index);
  };

  const handleDragEnd = () => {
    setDraggedIndex(null);
  };

  return (
    <div className="space-y-4">
      {/* Add Transform */}
      <div className="flex items-center gap-4">
        <div className="flex-1">
          <SearchableSelect
            options={availableTransforms.map(transform => ({
              value: transform.name,
              label: transform.name,
              description: transform.description
            }))}
            value=""
            onChange={(value) => handleAddTransform(value as string)}
            placeholder="Add a transform..."
          />
        </div>
        <TransformConfigPopover />
      </div>

      {/* Selected Transforms */}
      <div className="space-y-2">
        {selectedTransforms.map((transform, index) => (
          <div
            key={transform.name}
            draggable
            onDragStart={(e) => handleDragStart(e, index)}
            onDragOver={(e) => handleDragOver(e, index)}
            onDragEnd={handleDragEnd}
            className={`flex items-center gap-3 p-3 bg-white border rounded-lg ${
              draggedIndex === index ? 'border-blue-500 shadow-lg' : 'border-gray-200'
            } ${draggedIndex !== null ? 'cursor-grabbing' : ''}`}
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
                  transform.transform_type === 'calculation' ? 'bg-blue-100 text-blue-800' :
                  transform.transform_type === 'lookup' ? 'bg-purple-100 text-purple-800' :
                  'bg-green-100 text-green-800'
                }`}>
                  {'transform'}
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