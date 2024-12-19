import React from 'react';
import { FileCheck } from 'lucide-react';
import { SearchableSelect } from '../../SearchableSelect';

interface FileConfig {
  path: string;
  type: 'train' | 'test' | 'valid';
}

interface PredefinedSplitConfig {
  splitter_type: 'predefined';
  train_files: string[];
  test_files: string[];
  valid_files: string[];
}

interface PredefinedSplitterProps {
  attributes: PredefinedSplitConfig;
  available_files: string[];
  onChange: (attributes: PredefinedSplitConfig) => void;
}

export function PredefinedSplitter({ attributes, available_files, onChange }: PredefinedSplitterProps) {
  const [selectedFiles, setSelectedFiles] = React.useState<FileConfig[]>([]);

  // Convert attributes to FileConfig array for UI
  React.useEffect(() => {
    const files: FileConfig[] = [
      ...attributes.train_files.map(path => ({ path, type: 'train' as const })),
      ...attributes.test_files.map(path => ({ path, type: 'test' as const })),
      ...attributes.valid_files.map(path => ({ path, type: 'valid' as const }))
    ];
    setSelectedFiles(files);
  }, [attributes.train_files, attributes.test_files, attributes.valid_files]);

  const addFile = (path: string) => {
    const newFiles = [...selectedFiles, { path, type: 'train' }];
    setSelectedFiles(newFiles);
    updateAttributes(newFiles);
  };

  const updateFileType = (index: number, type: 'train' | 'test' | 'valid') => {
    const newFiles = selectedFiles.map((file, i) =>
      i === index ? { ...file, type } : file
    );
    setSelectedFiles(newFiles);
    updateAttributes(newFiles);
  };

  const removeFile = (index: number) => {
    const newFiles = selectedFiles.filter((_, i) => i !== index);
    setSelectedFiles(newFiles);
    updateAttributes(newFiles);
  };

  const updateAttributes = (files: FileConfig[]) => {
    onChange({
      splitter_type: 'predefined',
      train_files: files.filter(f => f.type === 'train').map(f => f.path),
      test_files: files.filter(f => f.type === 'test').map(f => f.path),
      valid_files: files.filter(f => f.type === 'valid').map(f => f.path)
    });
  };

  const unusedFiles = available_files.filter(
    path => !selectedFiles.find(f => f.path === path)
  );

  return (
    <div className="space-y-4">
      {/* File Selection */}
      <div>
        <label className="block text-sm font-medium text-gray-700">Add File</label>
        <SearchableSelect
          options={unusedFiles.map(path => ({
            value: path,
            label: path.split('/').pop() || path,
            description: path
          }))}
          value={null}
          onChange={(value) => addFile(value as string)}
          placeholder="Select a file..."
        />
      </div>

      {/* Selected files */}
      {selectedFiles.length > 0 ? (
        <div className="space-y-2">
          {selectedFiles.map((file, index) => (
            <div
              key={file.path}
              className="flex items-center justify-between p-3 bg-gray-50 rounded-lg"
            >
              <div className="flex items-center gap-2 min-w-0">
                <FileCheck className="w-4 h-4 text-gray-400 flex-shrink-0" />
                <span className="text-sm text-gray-900 truncate">
                  {file.path.split('/').pop()}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <select
                  value={file.type}
                  onChange={(e) => updateFileType(index, e.target.value as 'train' | 'test' | 'valid')}
                  className="text-sm rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="train">Training Set</option>
                  <option value="test">Test Set</option>
                  <option value="valid">Validation Set</option>
                </select>
                <button
                  onClick={() => removeFile(index)}
                  className="text-sm text-red-600 hover:text-red-700"
                >
                  Remove
                </button>
              </div>
            </div>
          ))}
        </div>
      ) : (
        <div className="text-center py-4 bg-gray-50 rounded-lg border-2 border-dashed border-gray-200">
          <p className="text-sm text-gray-500">
            Select files to create your train/test/validation splits
          </p>
        </div>
      )}

      {/* Validation messages */}
      {selectedFiles.length > 0 && (
        <div className="space-y-1 text-sm">
          {!selectedFiles.some(f => f.type === 'train') && (
            <p className="text-yellow-600">
              • You need at least one training set file
            </p>
          )}
          {!selectedFiles.some(f => f.type === 'test') && (
            <p className="text-yellow-600">
              • You need at least one test set file
            </p>
          )}
        </div>
      )}

    </div>
  );
}