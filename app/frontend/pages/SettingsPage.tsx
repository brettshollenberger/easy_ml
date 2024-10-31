import React, { useState } from 'react';
import { Settings2, Save, AlertCircle, Key, Database, Globe2 } from 'lucide-react';

interface Settings {
  timezone: string;
  s3: {
    bucket: string;
    region: string;
    accessKeyId: string;
    secretAccessKey: string;
  };
}

const TIMEZONES = [
  { value: 'America/New_York', label: 'Eastern Time' },
  { value: 'America/Chicago', label: 'Central Time' },
  { value: 'America/Denver', label: 'Mountain Time' },
  { value: 'America/Los_Angeles', label: 'Pacific Time' }
];

export function SettingsPage() {
  const [settings, setSettings] = useState<Settings>({
    timezone: 'America/New_York',
    s3: {
      bucket: '',
      region: 'us-east-1',
      accessKeyId: '',
      secretAccessKey: ''
    }
  });

  const [showSecretKey, setShowSecretKey] = useState(false);
  const [saved, setSaved] = useState(false);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    setSaved(true);
    setTimeout(() => setSaved(false), 3000);
  };

  return (
    <div className="max-w-4xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <Settings2 className="w-6 h-6 text-blue-600" />
            <h2 className="text-xl font-semibold text-gray-900">Settings</h2>
          </div>
        </div>

        <form onSubmit={handleSubmit} className="p-6 space-y-8">
          {/* General Settings */}
          <div className="space-y-4">
            <div className="flex items-center gap-2 mb-4">
              <Globe2 className="w-5 h-5 text-gray-500" />
              <h3 className="text-lg font-medium text-gray-900">General Settings</h3>
            </div>

            <div>
              <label htmlFor="timezone" className="block text-sm font-medium text-gray-700 mb-1">
                Timezone
              </label>
              <select
                id="timezone"
                value={settings.timezone}
                onChange={(e) => setSettings({ ...settings, timezone: e.target.value })}
                className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
              >
                {TIMEZONES.map((tz) => (
                  <option key={tz.value} value={tz.value}>
                    {tz.label}
                  </option>
                ))}
              </select>
              <p className="mt-1 text-sm text-gray-500">
                All dates and times will be displayed in this timezone
              </p>
            </div>
          </div>

          {/* S3 Configuration */}
          <div className="space-y-4">
            <div className="flex items-center gap-2 mb-4">
              <Database className="w-5 h-5 text-gray-500" />
              <h3 className="text-lg font-medium text-gray-900">S3 Configuration</h3>
            </div>

            <div className="grid grid-cols-2 gap-6">
              <div>
                <label htmlFor="bucket" className="block text-sm font-medium text-gray-700 mb-1">
                  Default S3 Bucket
                </label>
                <input
                  type="text"
                  id="bucket"
                  value={settings.s3.bucket}
                  onChange={(e) => setSettings({
                    ...settings,
                    s3: { ...settings.s3, bucket: e.target.value }
                  })}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                  placeholder="my-bucket"
                />
              </div>

              <div>
                <label htmlFor="region" className="block text-sm font-medium text-gray-700 mb-1">
                  AWS Region
                </label>
                <select
                  id="region"
                  value={settings.s3.region}
                  onChange={(e) => setSettings({
                    ...settings,
                    s3: { ...settings.s3, region: e.target.value }
                  })}
                  className="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                >
                  <option value="us-east-1">US East (N. Virginia)</option>
                  <option value="us-east-2">US East (Ohio)</option>
                  <option value="us-west-1">US West (N. California)</option>
                  <option value="us-west-2">US West (Oregon)</option>
                </select>
              </div>
            </div>

            <div className="bg-blue-50 rounded-lg p-4">
              <div className="flex gap-2">
                <AlertCircle className="w-5 h-5 text-blue-500 mt-0.5" />
                <div>
                  <h4 className="text-sm font-medium text-blue-900">AWS Credentials</h4>
                  <p className="mt-1 text-sm text-blue-700">
                    These credentials will be used as default for all S3 operations. You can override them per datasource.
                  </p>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-6">
              <div>
                <label htmlFor="accessKeyId" className="block text-sm font-medium text-gray-700 mb-1">
                  Access Key ID
                </label>
                <div className="relative">
                  <Key className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type="text"
                    id="accessKeyId"
                    value={settings.s3.accessKeyId}
                    onChange={(e) => setSettings({
                      ...settings,
                      s3: { ...settings.s3, accessKeyId: e.target.value }
                    })}
                    className="mt-1 block w-full pl-9 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    placeholder="AKIA..."
                  />
                </div>
              </div>

              <div>
                <label htmlFor="secretAccessKey" className="block text-sm font-medium text-gray-700 mb-1">
                  Secret Access Key
                </label>
                <div className="relative">
                  <Key className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
                  <input
                    type={showSecretKey ? 'text' : 'password'}
                    id="secretAccessKey"
                    value={settings.s3.secretAccessKey}
                    onChange={(e) => setSettings({
                      ...settings,
                      s3: { ...settings.s3, secretAccessKey: e.target.value }
                    })}
                    className="mt-1 block w-full pl-9 pr-24 rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500"
                    placeholder="Your secret key"
                  />
                  <button
                    type="button"
                    onClick={() => setShowSecretKey(!showSecretKey)}
                    className="absolute right-2 top-1/2 transform -translate-y-1/2 text-sm text-gray-500 hover:text-gray-700"
                  >
                    {showSecretKey ? 'Hide' : 'Show'}
                  </button>
                </div>
              </div>
            </div>
          </div>

          <div className="pt-6 border-t flex items-center justify-between">
            {saved && (
              <div className="flex items-center gap-2 text-green-600">
                <Save className="w-4 h-4" />
                <span className="text-sm font-medium">Settings saved successfully</span>
              </div>
            )}
            <div className="flex gap-3">
              <button
                type="submit"
                className="px-4 py-2 bg-blue-600 text-white text-sm font-medium rounded-md hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
              >
                Save Settings
              </button>
            </div>
          </div>
        </form>
      </div>
    </div>
  );
}