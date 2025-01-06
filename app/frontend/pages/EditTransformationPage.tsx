import React from 'react';
import { Code2 } from 'lucide-react';
import { mockDatasets, mockFeatureGroups } from '../mockData';
import { FeatureForm } from '../components/features/FeatureForm';

export default function EditFeaturePage() {
  const navigate = useNavigate();
  const { id } = useParams();
  
  const feature = mockFeatureGroups
    .flatMap(g => g.features)
    .find(t => t.id === Number(id));

  if (!feature) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl font-semibold text-gray-900">Feature not found</h2>
      </div>
    );
  }

  const handleSubmit = (data: any) => {
    console.log('Updating feature:', data);
    navigate('/features');
  };

  return (
    <div className="max-w-4xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <Code2 className="w-6 h-6 text-blue-600" />
            <h2 className="text-xl font-semibold text-gray-900">Edit Feature</h2>
          </div>
        </div>

        <FeatureForm
          datasets={mockDatasets}
          groups={mockFeatureGroups}
          initialData={{
            name: feature.name,
            description: feature.description,
            groupId: feature.groupId,
            testDatasetId: feature.testDatasetId,
            inputColumns: feature.inputColumns,
            outputColumns: feature.outputColumns,
            code: feature.code
          }}
          onSubmit={handleSubmit}
          onCancel={() => navigate('/features')}
        />
      </div>
    </div>
  );
}