import React from 'react';
import { usePage } from '@inertiajs/react'
import { useInertiaForm } from 'use-inertia-form';

interface Datasource {
  datasource: {
    name: string,
    s3_bucket: string,
    s3_prefix: string,
    s3_region: string,
  }
}

export default function NewDatasourcePage() {
  const { data, setData, post, processing, errors } = useInertiaForm<Datasource>({
    datasource: {
      name: '',
      s3_bucket: '',
      s3_prefix: '',
      s3_region: 'us-east-1',
    }
  })

  const { rootPath } = usePage().props;

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    post(`${rootPath}/datasources`)
  };

  return (
    <div className="max-w-2xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-6">
          New S3 Datasource
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
              onChange={(e) =>
                setData('datasource.name', e.target.value)
              }
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              required
            />
          </div>

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
              onChange={(e) =>
                setData('datasource.s3_bucket', e.target.value)
              }
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              required
            />
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
              onChange={(e) =>
                setData('datasource.s3_prefix', e.target.value)
              }
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              placeholder="data/raw/"
              required
            />
          </div>

          <div>
            <label
              htmlFor="s3_region"
              className="block text-sm font-medium text-gray-700"
            >
              Region
            </label>
            <select
              id="s3_region"
              value={data.datasource.s3_region}
              onChange={(e) =>
                setData('datasource.s3_region', e.target.value)
              }
              className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
            >
              <option value="us-east-1">US East (N. Virginia)</option>
              <option value="us-east-2">US East (Ohio)</option>
              <option value="us-west-1">US West (N. California)</option>
              <option value="us-west-2">US West (Oregon)</option>
              <option value="eu-west-1">EU (Ireland)</option>
              <option value="eu-central-1">EU (Frankfurt)</option>
              <option value="ap-southeast-1">Asia Pacific (Singapore)</option>
              <option value="ap-southeast-2">Asia Pacific (Sydney)</option>
            </select>
          </div>

          <div className="flex justify-end">
            <button
              type="submit"
              className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
            >
              Create Datasource
            </button>
          </div>
        </form>
      </div>
    </div>
  );
}