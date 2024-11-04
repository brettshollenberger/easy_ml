import React from 'react';
import { ArrowLeft } from 'lucide-react';
import { router, usePage } from '@inertiajs/react';
import { useInertiaForm } from 'use-inertia-form';

interface DatasourceForm {
  datasource: {
    name: string;
    s3_bucket: string;
    s3_prefix: string;
    s3_region: string;
  }
}

interface Props {
  datasource: {
    id: number;
    name: string;
    s3_bucket: string;
    s3_prefix: string;
    s3_region: string;
  }
}

export default function EditDatasourcePage({ datasource }: Props) {
  const { rootPath } = usePage().props;
  
  const { data, setData, patch, processing, errors } = useInertiaForm<DatasourceForm>({
    datasource: {
      name: datasource.name,
      s3_bucket: datasource.s3_bucket,
      s3_prefix: datasource.s3_prefix,
      s3_region: datasource.s3_region
    }
  });

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    patch(`${rootPath}/datasources/${datasource.id}`);
  };

  return (
    <div className="max-w-2xl mx-auto">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-6">
          Edit Datasource
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
            {errors['datasource.name'] && (
              <p className="mt-1 text-sm text-red-600">{errors['datasource.name']}</p>
            )}
          </div>

          <div>
            <label
              htmlFor="bucket"
              className="block text-sm font-medium text-gray-700"
            >
              S3 Bucket
            </label>
            <input
              type="text"
              id="bucket"
              value={data.datasource.s3_bucket}
              onChange={(e) => setData('datasource.s3_bucket', e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              required
            />
            {errors['datasource.s3_bucket'] && (
              <p className="mt-1 text-sm text-red-600">{errors['datasource.s3_bucket']}</p>
            )}
          </div>

          <div>
            <label
              htmlFor="prefix"
              className="block text-sm font-medium text-gray-700"
            >
              S3 Prefix
            </label>
            <input
              type="text"
              id="prefix"
              value={data.datasource.s3_prefix}
              onChange={(e) => setData('datasource.s3_prefix', e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              placeholder="data/raw/"
              required
            />
            {errors['datasource.s3_prefix'] && (
              <p className="mt-1 text-sm text-red-600">{errors['datasource.s3_prefix']}</p>
            )}
          </div>

          <div>
            <label
              htmlFor="region"
              className="block text-sm font-medium text-gray-700"
            >
              Region
            </label>
            <select
              id="region"
              value={data.datasource.s3_region}
              onChange={(e) => setData('datasource.s3_region', e.target.value)}
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="us-east-1">US East (N. Virginia)</option>
              <option value="us-east-2">US East (Ohio)</option>
              <option value="us-west-1">US West (N. California)</option>
              <option value="us-west-2">US West (Oregon)</option>
            </select>
            {errors['datasource.s3_region'] && (
              <p className="mt-1 text-sm text-red-600">{errors['datasource.s3_region']}</p>
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
              {processing ? 'Saving...' : 'Save Changes'}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}