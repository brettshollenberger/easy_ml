import React, { useState, useRef } from 'react';
import { FileUp, FileJson, Database, Upload, ArrowRight } from 'lucide-react';
import { usePage } from '@inertiajs/react';
import { useInertiaForm } from 'use-inertia-form';
import { SearchableSelect } from '../SearchableSelect';
import type { Dataset } from '../../types/dataset';

interface UploadModelModalProps {
  isOpen: boolean;
  onClose: () => void;
  modelId: number;
  dataset_id?: number;
}

interface UploadForm {
  config: File | null;
  dataset_id: string;
}

interface PageProps {
  rootPath: string;
  datasets: Pick<Dataset, 'id' | 'name' | 'num_rows'>[];
}

export function UploadModelModal({ isOpen, onClose, modelId, dataset_id }: UploadModelModalProps) {
  const { rootPath, datasets } = usePage<PageProps>().props;
  const [selectedOption, setSelectedOption] = useState<'model' | 'both' | null>(dataset_id ? 'model' : null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const { data, setData, post, processing, errors } = useInertiaForm<UploadForm>({
    config: null,
    dataset_id: dataset_id ? dataset_id.toString() : '',
  });

  const handleFileSelect = () => {
    const input = document.createElement('input');
    input.type = 'file';
    input.accept = 'application/json';
    input.onchange = (e) => {
      const file = (e.target as HTMLInputElement).files?.[0];
      if (file) {
        setData('config', file);
      }
    };
    input.click();
  };

  const canUpload = data.config && (dataset_id || (selectedOption && (
    selectedOption === 'both' || (selectedOption === 'model' && data.dataset_id)
  )));

  const handleUpload = () => {
    if (!canUpload) return;

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
          <div className="p-2 bg-blue-50 rounded-lg">
            <FileUp className="w-5 h-5 text-blue-600" />
          </div>
        </div>

        {!dataset_id && (
          <div className="space-y-3">
            <button
              onClick={() => {
                setSelectedOption('model');
                setData('dataset_id', '');
              }}
              className={`w-full px-4 py-3 rounded-lg text-left transition-all duration-200 ${
                selectedOption === 'model'
                  ? 'bg-blue-50 border-2 border-blue-500 ring-2 ring-blue-200'
                  : 'bg-white border-2 border-gray-200 hover:border-blue-200'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <div className="font-medium text-gray-900">Model Only</div>
                  <div className="text-sm text-gray-500">Upload model configuration and select a dataset</div>
                </div>
                <FileJson className={`w-5 h-5 ${selectedOption === 'model' ? 'text-blue-600' : 'text-gray-400'}`} />
              </div>
            </button>

            <button
              onClick={() => {
                setSelectedOption('both');
                setData('dataset_id', '');
              }}
              className={`w-full px-4 py-3 rounded-lg text-left transition-all duration-200 ${
                selectedOption === 'both'
                  ? 'bg-blue-50 border-2 border-blue-500 ring-2 ring-blue-200'
                  : 'bg-white border-2 border-gray-200 hover:border-blue-200'
              }`}
            >
              <div className="flex items-center justify-between">
                <div>
                  <div className="font-medium text-gray-900">Model + Dataset</div>
                  <div className="text-sm text-gray-500">Upload and validate both model and dataset configurations</div>
                </div>
                <Database className={`w-5 h-5 ${selectedOption === 'both' ? 'text-blue-600' : 'text-gray-400'}`} />
              </div>
            </button>
          </div>
        )}

        {selectedOption === 'model' && !dataset_id && (
          <div className="mt-4">
            <label className="block text-sm font-medium text-gray-700 mb-1">
              Select Dataset
            </label>
            <SearchableSelect
              options={datasets.map(dataset => ({
                value: dataset.id,
                label: dataset.name,
                description: dataset.num_rows ? `${dataset.num_rows.toLocaleString()} rows` : undefined
              }))}
              value={data.dataset_id ? parseInt(data.dataset_id) : null}
              onChange={(value) => setData('dataset_id', value ? value.toString() : '')}
              placeholder="Select a dataset"
            />
            {errors.dataset_id && (
              <p className="mt-1 text-sm text-red-600">{errors.dataset_id}</p>
            )}
          </div>
        )}

        {(selectedOption || dataset_id) && (
          <div className="mt-4">
            <button
              onClick={handleFileSelect}
              className={`w-full px-4 py-3 rounded-lg text-left transition-all duration-200 border-2 border-dashed
                ${data.config ? 'border-blue-500 bg-blue-50' : 'border-gray-300 hover:border-blue-500'}`}
            >
              <div className="flex items-center justify-center gap-2 text-sm">
                <Upload className={`w-4 h-4 ${data.config ? 'text-blue-600' : 'text-gray-400'}`} />
                <span className={data.config ? 'text-blue-600' : 'text-gray-500'}>
                  {data.config ? data.config.name : 'Click to select configuration file'}
                </span>
              </div>
            </button>
            {errors.config && (
              <p className="mt-1 text-sm text-red-600">{errors.config}</p>
            )}
          </div>
        )}

        <div className="mt-6 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
          >
            Cancel
          </button>
          <button
            onClick={handleUpload}
            disabled={!canUpload || processing}
            className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed inline-flex items-center gap-2"
          >
            {processing ? 'Uploading...' : 'Upload'}
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}