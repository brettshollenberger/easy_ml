import React, { useState } from "react";
import {
  GripVertical,
  X,
  Plus,
  ArrowDown,
  ArrowUp,
  Settings2,
} from "lucide-react";
import { SearchableSelect } from "../SearchableSelect";
import { FeatureConfigPopover } from "./FeatureConfigPopover";
import { Feature } from "../../types/dataset";

interface FeaturePickerProps {
  options: Feature[];
  initialFeatures?: Feature[];
  onFeaturesChange: (features: Feature[]) => void;
}

export function FeaturePicker({
  options,
  initialFeatures = [],
  onFeaturesChange,
}: FeaturePickerProps) {
  const [selectedFeatures, setSelectedFeatures] =
    useState<Feature[]>(initialFeatures);
  const [draggedIndex, setDraggedIndex] = useState<number | null>(null);

  console.log(selectedFeatures);
  const availableFeatures = options.filter(
    (feature) => !selectedFeatures.find((t) => t.name === feature.name)
  );

  const updateFeatures = (newFeatures: Feature[]) => {
    const featuresWithPosition = newFeatures.map((feature, index) => ({
      ...feature,
      feature_position: index,
    }));

    setSelectedFeatures(featuresWithPosition);
    onFeaturesChange(featuresWithPosition);
  };

  const handleAddFeature = (transformName: string) => {
    const feature = options.find((t) => t.name === transformName);
    if (feature) {
      const newFeature = {
        ...feature,
        feature_position: selectedFeatures.length,
      };
      updateFeatures([...selectedFeatures, newFeature]);
    }
  };

  const handleRemove = (index: number) => {
    const newFeatures = [...selectedFeatures];
    newFeatures.splice(index, 1);
    updateFeatures(newFeatures);
  };

  const handleMoveUp = (index: number) => {
    if (index === 0) return;
    const newFeatures = [...selectedFeatures];
    [newFeatures[index - 1], newFeatures[index]] = [
      newFeatures[index],
      newFeatures[index - 1],
    ];
    updateFeatures(newFeatures);
  };

  const handleMoveDown = (index: number) => {
    if (index === selectedFeatures.length - 1) return;
    const newFeatures = [...selectedFeatures];
    [newFeatures[index], newFeatures[index + 1]] = [
      newFeatures[index + 1],
      newFeatures[index],
    ];
    updateFeatures(newFeatures);
  };

  const handleDragStart = (e: React.DragEvent, index: number) => {
    setDraggedIndex(index);
  };

  const handleDragOver = (e: React.DragEvent, index: number) => {
    e.preventDefault();
    if (draggedIndex === null || draggedIndex === index) return;

    const newFeatures = [...selectedFeatures];
    const [draggedFeature] = newFeatures.splice(draggedIndex, 1);
    newFeatures.splice(index, 0, draggedFeature);
    updateFeatures(newFeatures);
    setDraggedIndex(index);
  };

  const handleDragEnd = () => {
    setDraggedIndex(null);
  };

  return (
    <div className="space-y-4">
      {/* Add Feature */}
      <div className="flex items-center gap-4">
        <div className="flex-1">
          <SearchableSelect
            options={availableFeatures.map((feature) => ({
              value: feature.name,
              label: feature.name,
              description: feature.description,
            }))}
            value=""
            onChange={(value) => handleAddFeature(value as string)}
            placeholder="Add a transform..."
          />
        </div>
        <FeatureConfigPopover />
      </div>

      {/* Selected Features */}
      <div className="space-y-2">
        {selectedFeatures.map((feature, index) => (
          <div
            key={feature.name}
            draggable
            onDragStart={(e) => handleDragStart(e, index)}
            onDragOver={(e) => handleDragOver(e, index)}
            onDragEnd={handleDragEnd}
            className={`flex items-center gap-3 p-3 bg-white border rounded-lg ${
              draggedIndex === index
                ? "border-blue-500 shadow-lg"
                : "border-gray-200"
            } ${draggedIndex !== null ? "cursor-grabbing" : ""}`}
          >
            <button
              type="button"
              className="p-1 text-gray-400 hover:text-gray-600 cursor-grab active:cursor-grabbing"
            >
              <GripVertical className="w-4 h-4" />
            </button>

            <div className="flex-1 min-w-0">
              <div className="flex items-center gap-2">
                <span className="font-medium text-gray-900">
                  {feature.name}
                </span>
                <span
                  className={`text-xs px-2 py-0.5 rounded-full ${
                    feature.feature_type === "calculation"
                      ? "bg-blue-100 text-blue-800"
                      : feature.feature_type === "lookup"
                      ? "bg-purple-100 text-purple-800"
                      : "bg-green-100 text-green-800"
                  }`}
                >
                  {"feature"}
                </span>
              </div>
              <p className="text-sm text-gray-500 truncate">
                {feature.description}
              </p>
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
                disabled={index === selectedFeatures.length - 1}
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

        {selectedFeatures.length === 0 && (
          <div className="text-center py-8 bg-gray-50 border-2 border-dashed border-gray-200 rounded-lg">
            <Plus className="w-8 h-8 text-gray-400 mx-auto mb-2" />
            <p className="text-sm text-gray-500">
              Add features to enrich your dataset
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
