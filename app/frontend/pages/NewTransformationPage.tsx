import React, { useState } from 'react';
import { Code2 } from 'lucide-react';
import { mockDatasets, mockFeatureGroups } from '../mockData';
import { FeatureForm } from '../components/features/FeatureForm';

export default function NewFeaturePage() {
  const navigate = useNavigate();
  const [formData, setFormData] = useState({
    name: '',
    description: '',
    groupId: '',
    testDatasetId: '',
    inputColumns: [] as string[],
    outputColumns: [] as string[],
    code: ''
  });

  const handleSubmit = (data: typeof formData) => {
    console.log('Creating new feature:', data);
    navigate('/features');
  };

  return (
    <div className="max-w-4xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <Code2 className="w-6 h-6 text-blue-600" />
            <h2 className="text-xl font-semibold text-gray-900">New Feature</h2>
          </div>
        </div>

        <FeatureForm
          datasets={mockDatasets}
          groups={mockFeatureGroups}
          onSubmit={handleSubmit}
          onCancel={() => navigate('/features')}
        />
      </div>
    </div>
  );
}