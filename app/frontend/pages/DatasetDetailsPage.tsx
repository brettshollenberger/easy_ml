import React, { useState, useCallback } from 'react';
import { usePage, router } from '@inertiajs/react';
import { Settings } from 'lucide-react';
import { isEqual } from 'lodash';
import { DatasetPreview } from '../components/DatasetPreview';
import { ColumnConfigModal } from '../components/dataset/ColumnConfigModal';
import type { Dataset, Column } from '../types/dataset';
import type { PreprocessingConstants } from '../types';

interface Props {
  dataset: Dataset;
  constants: PreprocessingConstants;
}

export default function DatasetDetailsPage({ dataset, constants }: Props) {
  const [showColumnConfig, setShowColumnConfig] = useState(false);
  const [currentDataset, setCurrentDataset] = useState<Dataset>(dataset);
  const { rootPath } = usePage().props;

  const onSave = useCallback((updatedDataset: Dataset) => {
    // Find dataset-level changes
    const datasetChanges = Object.entries(updatedDataset).reduce((acc, [key, value]) => {
      if (key !== 'columns' && key !== 'features' && !isEqual(currentDataset[key as keyof Dataset], value)) {
        acc[key as keyof Dataset] = value;
      }
      return acc;
    }, {} as Partial<Dataset>);

    // Find column changes
    const columnChanges = updatedDataset.columns.reduce((acc, newColumn) => {
      const oldColumn = currentDataset.columns.find(c => c.id === newColumn.id);
      
      if (!oldColumn || !isEqual(oldColumn, newColumn)) {
        const changedFields = Object.entries(newColumn).reduce((fields, [key, value]) => {
          if (!oldColumn || !isEqual(oldColumn[key as keyof Column], value)) {
            fields[key] = value;
          }
          return fields;
        }, {} as Record<string, any>);

        if (Object.keys(changedFields).length > 0) {
          acc[newColumn.id] = {
            ...changedFields,
            id: newColumn.id
          };
        }
      }
      return acc;
    }, {} as Record<number, Record<string, any>>);

    // Format features for nested attributes
    const transformChanges = updatedDataset.features?.map((feature, index) => ({
      id: feature.id,
      name: feature.name,
      feature_class: feature.feature_class,
      feature_position: index,
      _destroy: feature._destroy
    }));

    // Only make the API call if there are actual changes
    if (Object.keys(datasetChanges).length > 0 || 
        Object.keys(columnChanges).length > 0 || 
        !isEqual(currentDataset.features, updatedDataset.features)) {
      router.patch(`${rootPath}/datasets/${dataset.id}`, {
        dataset: {
          ...datasetChanges,
          columns_attributes: columnChanges,
          features_attributes: transformChanges
        }
      }, {
        preserveState: true,
        preserveScroll: true
      });
    }

    // Update local state
    setCurrentDataset(updatedDataset);
  }, [currentDataset, dataset.id, rootPath]);

  return (
    <div className="p-8 space-y-6">
      <div className="flex justify-end">
        <button
          onClick={() => setShowColumnConfig(true)}
          className="flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 rounded-md text-sm font-medium text-gray-700 hover:bg-gray-50"
        >
          <Settings className="w-4 h-4" />
          Configure Columns
        </button>
      </div>

      <DatasetPreview dataset={currentDataset} />

      <ColumnConfigModal
        isOpen={showColumnConfig}
        onClose={() => setShowColumnConfig(false)}
        initialDataset={currentDataset}
        constants={constants}
        onSave={onSave}
      />
    </div>
  );
}