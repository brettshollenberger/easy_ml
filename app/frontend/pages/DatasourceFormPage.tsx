import React from 'react';
import { router, usePage } from '@inertiajs/react';
import { useInertiaForm } from 'use-inertia-form';
import { SearchableSelect } from '../components/SearchableSelect';
import type { Datasource, DatasourceFormProps } from '../types/datasource';

export default function DatasourceFormPage({ datasource, constants }: DatasourceFormProps) {
  const { rootPath } = usePage().props;
  const isEditing = !!datasource;

  const { data, setData, processing, errors } = useInertiaForm<{ datasource: Datasource }>({
    datasource: {
      name: datasource?.name ?? '',
      datasource_type: datasource?.datasource_type ?? 's3',
      s3_bucket: datasource?.s3_bucket ?? '',
      s3_prefix: datasource?.s3_prefix ?? '',
      s3_region: datasource?.s3_region ?? 'us-east-1',
    }
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (isEditing) {
      router.patch(`${rootPath}/datasources/${datasource.id}`, data);
    } else {
      router.post(`${rootPath}/datasources`, data);
    }
  };

  return (
    <div className="max-w-2xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-6">
          {isEditing ? 'Edit Datasource' : 'New Datasource'}
        </h2>

        <form onSubmit={handleSubmit} className="space-y-6">
          <div>
            <label
              htmlFor="name"
              className="block text-sm font-medium text-gray-700"
            >
              Name
            </label>
            <input
              type="text"
              id="name"
              value={data.datasource.name}
              onChange={(e) => setData('datasource.name', e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              required
            />
            {errors.datasource?.name && (
              <p className="mt-1 text-sm text-red-600">{errors.datasource.name}</p>
            )}
          </div>

          {!isEditing && (
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Type
              </label>
              <SearchableSelect
                options={constants.DATASOURCE_TYPES}
                value={data.datasource.datasource_type}
                onChange={(value) => setData('datasource.datasource_type', value)}
                placeholder="Select datasource type"
              />
            </div>
          )}

          <div>
            <label
              htmlFor="s3_bucket"
              className="block text-sm font-medium text-gray-700"
            >
              S3 Bucket
            </label>
            <input
              type="text"
              id="s3_bucket"
              value={data.datasource.s3_bucket}
              onChange={(e) => setData('datasource.s3_bucket', e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              required
            />
            {errors.datasource?.s3_bucket && (
              <p className="mt-1 text-sm text-red-600">{errors.datasource.s3_bucket}</p>
            )}
          </div>

          <div>
            <label
              htmlFor="s3_prefix"
              className="block text-sm font-medium text-gray-700"
            >
              S3 Prefix
            </label>
            <input
              type="text"
              id="s3_prefix"
              value={data.datasource.s3_prefix}
              onChange={(e) => setData('datasource.s3_prefix', e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              placeholder="data/raw/"
              required
            />
            {errors.datasource?.s3_prefix && (
              <p className="mt-1 text-sm text-red-600">{errors.datasource.s3_prefix}</p>
            )}
          </div>

          <div>
            <label className="block text-sm font-medium text-gray-700 mb-1">
              S3 Region
            </label>
            <SearchableSelect
              options={constants.s3.S3_REGIONS}
              value={data.datasource.s3_region}
              onChange={(value) => setData('datasource.s3_region', value)}
              placeholder="Select s3 region"
            />
            {errors.datasource?.s3_region && (
              <p className="mt-1 text-sm text-red-600">{errors.datasource.s3_region}</p>
            )}
          </div>

          <div className="flex justify-end gap-3">
            <button
              type="button"
              onClick={() => router.visit(`${rootPath}/datasources`)}
              className="px-4 py-2 text-sm font-medium text-gray-700 hover:text-gray-900"
            >
              Cancel
            </button>
            <button
              type="submit"
              disabled={processing}
              className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              {processing ? 'Saving...' : isEditing ? 'Save Changes' : 'Create Datasource'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
} 