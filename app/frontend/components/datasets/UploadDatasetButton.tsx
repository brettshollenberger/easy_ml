import React, { useRef } from 'react';
import { Upload } from 'lucide-react';
import { router, usePage } from '@inertiajs/react';

export function UploadDatasetButton() {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const { rootPath } = usePage().props;

  const handleUpload = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    const formData = new FormData();
    formData.append('config', file);

    fetch(`${rootPath}/datasets/upload`, {
      method: 'POST',
      body: formData,
      credentials: 'same-origin',
      headers: {
        'X-CSRF-Token': document.querySelector<HTMLMetaElement>('meta[name="csrf-token"]')?.content || '',
      },
    }).then(response => {
      if (response.ok) {
        window.location.reload();
      } else {
        console.error('Upload failed');
      }
    });
  };

  return (
    <>
      <button
        onClick={() => fileInputRef.current?.click()}
        className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-gray-300 text-sm font-medium rounded-md text-gray-700 hover:bg-gray-50"
        title="Import dataset"
      >
        <Upload className="w-4 h-4" />
        Import
      </button>
      <input
        type="file"
        ref={fileInputRef}
        onChange={handleUpload}
        accept=".json"
        className="hidden"
      />
    </>
  );
}
