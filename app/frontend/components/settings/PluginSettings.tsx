import React, { useState } from 'react';
import { Puzzle, Key, ExternalLink } from 'lucide-react';

interface PluginSettingsProps {
  settings: {
    wandb_api_key: string;
  };
  setData: (data: any) => void;
}

export function PluginSettings({ settings, setData }: PluginSettingsProps) {
  const [showApiKey, setShowApiKey] = useState(false);

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2 mb-4">
        <Puzzle className="w-5 h-5 text-gray-500" />
        <h3 className="text-lg font-medium text-gray-900">Plugins</h3>
      </div>

      <div className="space-y-6">
        <div className="border border-gray-200 rounded-lg p-4">
          <div className="flex items-start justify-between">
            <div className="flex items-start gap-3">
              <img 
                src="https://raw.githubusercontent.com/wandb/assets/main/wandb-dots-logo.svg" 
                alt="Weights & Biases" 
                className="w-8 h-8"
              />
              <div>
                <h4 className="text-base font-medium text-gray-900">Weights & Biases</h4>
                <p className="text-sm text-gray-500 mt-1">
                  Track and visualize machine learning experiments
                </p>
              </div>
            </div>
            <a
              href="https://wandb.ai/settings"
              target="_blank"
              rel="noopener noreferrer"
              className="text-blue-600 hover:text-blue-700 inline-flex items-center gap-1 text-sm"
            >
              Get API Key
              <ExternalLink className="w-4 h-4" />
            </a>
          </div>

          <div className="mt-4">
            <label htmlFor="wandb_api_key" className="block text-sm font-medium text-gray-700">
              API Key
            </label>
            <div className="mt-1 relative rounded-md shadow-sm">
              <div className="absolute inset-y-0 left-0 pl-3 flex items-center pointer-events-none">
                <Key className="h-5 w-5 text-gray-400" />
              </div>
              <input
                type={showApiKey ? "text" : "password"}
                name="wandb_api_key"
                id="wandb_api_key"
                value={settings.wandb_api_key}
                onChange={(e) => setData({ settings: { ...settings, wandb_api_key: e.target.value } })}
                className="focus:ring-blue-500 focus:border-blue-500 block w-full pl-10 sm:text-sm border-gray-300 rounded-md"
                placeholder="Enter your Weights & Biases API key"
              />
              <button
                type="button"
                onClick={() => setShowApiKey(!showApiKey)}
                className="absolute inset-y-0 right-0 pr-3 flex items-center"
              >
                <Key className={`h-5 w-5 ${showApiKey ? 'text-gray-400' : 'text-gray-600'}`} />
              </button>
            </div>
            <p className="mt-1 text-xs text-gray-500">
              Your API key will be used to log metrics, artifacts, and experiment results
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}