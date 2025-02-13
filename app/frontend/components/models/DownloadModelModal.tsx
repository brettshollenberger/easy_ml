import React, { useState } from 'react';
import { FileDown, FileJson, Database, ArrowRight } from 'lucide-react';
import { router, usePage } from '@inertiajs/react';

interface DownloadModelModalProps {
  isOpen: boolean;
  onClose: () => void;
  modelId: number;
}

export function DownloadModelModal({ isOpen, onClose, modelId }: DownloadModelModalProps) {
  const { rootPath } = usePage().props;
  const [selectedOption, setSelectedOption] = useState<'model' | 'both' | null>(null);

  if (!isOpen) return null;

  const handleDownload = async () => {
    if (!selectedOption) return;
    
    const includeDataset = selectedOption === 'both';
    window.location.href = `${rootPath}/models/${modelId}/download?include_dataset=${includeDataset}`;
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/60 backdrop-blur-sm flex items-center justify-center z-50">
      <div className="bg-white rounded-xl p-6 w-full max-w-md shadow-2xl">
        <div className="flex items-center justify-between mb-6">
          <h3 className="text-lg font-semibold text-gray-900">Download Configuration</h3>
          <div className="p-2 bg-blue-50 rounded-lg">
            <FileDown className="w-5 h-5 text-blue-600" />
          </div>
        </div>

        <div className="space-y-3">
          <button
            onClick={() => setSelectedOption('model')}
            className={`w-full px-4 py-3 rounded-lg text-left transition-all duration-200 ${
              selectedOption === 'model'
                ? 'bg-blue-50 border-2 border-blue-500 ring-2 ring-blue-200'
                : 'bg-white border-2 border-gray-200 hover:border-blue-200'
            }`}
          >
            <div className="flex items-center justify-between">
              <div>
                <div className="font-medium text-gray-900">Model Only</div>
                <div className="text-sm text-gray-500">Download model configuration without dataset details</div>
              </div>
              <FileJson className={`w-5 h-5 ${selectedOption === 'model' ? 'text-blue-600' : 'text-gray-400'}`} />
            </div>
          </button>

          <button
            onClick={() => setSelectedOption('both')}
            className={`w-full px-4 py-3 rounded-lg text-left transition-all duration-200 ${
              selectedOption === 'both'
                ? 'bg-blue-50 border-2 border-blue-500 ring-2 ring-blue-200'
                : 'bg-white border-2 border-gray-200 hover:border-blue-200'
            }`}
          >
            <div className="flex items-center justify-between">
              <div>
                <div className="font-medium text-gray-900">Model + Dataset</div>
                <div className="text-sm text-gray-500">Download complete configuration including dataset details</div>
              </div>
              <Database className={`w-5 h-5 ${selectedOption === 'both' ? 'text-blue-600' : 'text-gray-400'}`} />
            </div>
          </button>
        </div>

        <div className="mt-6 flex justify-end gap-3">
          <button
            onClick={onClose}
            className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
          >
            Cancel
          </button>
          <button
            onClick={handleDownload}
            disabled={!selectedOption}
            className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-lg hover:bg-blue-700 disabled:bg-gray-300 disabled:cursor-not-allowed inline-flex items-center gap-2"
          >
            Download
            <ArrowRight className="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  );
}