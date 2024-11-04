import React, { useState } from 'react';
// import { useParams } from 'react-router-dom';
import { Settings } from 'lucide-react';
import { DatasetPreview } from '../components/DatasetPreview';
import { ColumnConfigModal } from '../components/dataset/ColumnConfigModal';
import { mockDatasets } from '../mockData';

export default function DatasetDetailsPage() {
  const { id } = useParams();
  const dataset = datasets.find(d => d.id === Number(id));
  const [showColumnConfig, setShowColumnConfig] = useState(false);

  if (!dataset) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl font-semibold text-gray-900">Dataset not found</h2>
      </div>
    );
  }

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