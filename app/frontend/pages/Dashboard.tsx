import React, { useState } from 'react';
import { Brain } from 'lucide-react';
import { ModelCard } from '../components/ModelCard';
import { ModelDetails } from '../components/ModelDetails';
import { mockModels, mockRetrainingJobs, mockRetrainingRuns } from '../mockData';

function Dashboard() {
  const [selectedModelId, setSelectedModelId] = useState<number | null>(null);

  const selectedModel = mockModels.find((m) => m.id === selectedModelId);
  const modelRuns = mockRetrainingRuns.filter((r) => r.modelId === selectedModelId);
  const modelJob = mockRetrainingJobs.find((j) => j.model === selectedModel?.name);

  debugger;
  return (
    <div className="min-h-screen bg-gray-50">
      <header className="bg-white shadow-sm">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
          <div className="flex items-center gap-2">
            <Brain className="w-8 h-8 text-blue-600" />
            <h1 className="text-2xl font-bold text-gray-900">ML Ops Dashboard</h1>
          </div>
        </div>
      </header>

      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        {selectedModel ? (
          <ModelDetails
            model={selectedModel}
            runs={modelRuns}
            job={modelJob}
            onBack={() => setSelectedModelId(null)}
          />
        ) : (
          <div className="space-y-6">
            <div className="flex justify-between items-center">
              <h2 className="text-xl font-semibold text-gray-900">Models</h2>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              {mockModels.map((model) => (
                <ModelCard
                  key={model.id}
                  model={model}
                  job={mockRetrainingJobs.find((j) => j.model === model.name)}
                  lastRun={mockRetrainingRuns.find((r) => r.modelId === model.id)}
                  onViewDetails={setSelectedModelId}
                />
              ))}
            </div>
          </div>
        )}
      </main>
    </div>
  );
}

export default Dashboard;