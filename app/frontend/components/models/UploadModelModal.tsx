import React, { useRef } from 'react';
import { Upload, ArrowRight } from 'lucide-react';
import { usePage } from '@inertiajs/react';
import { useInertiaForm } from 'use-inertia-form';

interface UploadModelModalProps {
  isOpen: boolean;
  onClose: () => void;
  modelId: number;
}

interface UploadForm {
  config: File | null;
  dataset_id: string;
}

export function UploadModelModal({ isOpen, onClose, modelId }: UploadModelModalProps) {
  const { rootPath, datasets } = usePage<{ datasets: Array<{ id: number; name: string }> }>().props;
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data, setData, post, processing, errors } = useInertiaForm<UploadForm>({
    config: null,
    dataset_id: '',
  });

  const handleFileChange = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (file) {
      setData('config', file);
    }
  };

  const handleUpload = () => {
    if (!data.config) return;

    post(`${rootPath}/models/${modelId}/upload`, {
      preserveScroll: true,
      onSuccess: () => {
        onClose();
      },
    });
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-2xl">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-gray-900">Upload Configuration</h3>
          <div className="p-2 bg-green-50 rounded-lg">
            <Upload className="w-5 h-5 text-green-600" />
          </div>
        </div>

        <div className="space-y-4">
          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Configuration File
            </label>
            <div className="mt-1 flex items-center">
              <input
                type="file"
                ref={fileInputRef}
                onChange={handleFileChange}
                accept=".json"
                className="block w-full text-sm text-gray-500
                  file:mr-4 file:py-2 file:px-4
                  file:rounded-md file:border-0
                  file:text-sm file:font-semibold
                  file:bg-green-50 file:text-green-700
                  hover:file:bg-green-100"
              />
            </div>
            {errors.config && (
              <p className="mt-1 text-sm text-red-600">{errors.config}</p>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-2">
              Select Dataset (for model-only imports)
            </label>
            <select
              value={data.dataset_id}
              onChange={(e) => setData('dataset_id', e.target.value)}
              className="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-green-500 focus:border-green-500 sm:text-sm rounded-md"
            >
              <option value="">Select a dataset</option>
              {datasets.map((dataset) => (
                <option key={dataset.id} value={dataset.id.toString()}>
                  {dataset.name}
                </option>
              ))}
            </select>
            {errors.dataset_id && (
              <p className="mt-1 text-sm text-red-600">{errors.dataset_id}</p>
            )}
          </div>
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
          >
            Cancel
          </button>
          <button
            onClick={handleUpload}
            disabled={!data.config || processing}
            className="px-4 py-2 bg-green-600 text-white text-sm font-medium rounded-lg hover:bg-green-700 disabled:bg-gray-300 disabled:cursor-not-allowed inline-flex items-center gap-2"
          >
            {processing ? 'Uploading...' : 'Upload'}
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}