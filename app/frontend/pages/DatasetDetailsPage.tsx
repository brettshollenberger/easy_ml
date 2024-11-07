import React, { useState } from 'react';
import { usePage } from '@inertiajs/react';
import { Settings } from 'lucide-react';
import { DatasetPreview } from '../components/DatasetPreview';
import { ColumnConfigModal } from '../components/dataset/ColumnConfigModal';
import type { Dataset } from '../types/dataset';

interface Props {
  dataset: Dataset;
}

export default function DatasetDetailsPage({ dataset }: Props) {
  const [showColumnConfig, setShowColumnConfig] = useState(false);
  const { rootPath } = usePage().props;

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

      <DatasetPreview dataset={dataset} />

      <ColumnConfigModal
        isOpen={showColumnConfig}
        onClose={() => setShowColumnConfig(false)}
        columns={dataset.columns}
        onSave={(config) => {
          console.log('Saving column configuration:', config);
          setShowColumnConfig(false);
        }}
      />
    </div>
  );
}