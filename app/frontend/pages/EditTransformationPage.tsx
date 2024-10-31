import React from 'react';
// import { useNavigate, useParams } from 'react-router-dom';
import { Code2 } from 'lucide-react';
import { mockDatasets, mockTransformationGroups } from '../mockData';
import { TransformationForm } from '../components/transformations/TransformationForm';

export function EditTransformationPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  
  const transformation = mockTransformationGroups
    .flatMap(g => g.transformations)
    .find(t => t.id === Number(id));

  if (!transformation) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl font-semibold text-gray-900">Transformation not found</h2>
      </div>
    );
  }

  const handleSubmit = (data: any) => {
    console.log('Updating transformation:', data);
    navigate('/transformations');
  };

  return (
    <div className="max-w-4xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <Code2 className="w-6 h-6 text-blue-600" />
            <h2 className="text-xl font-semibold text-gray-900">Edit Transformation</h2>
          </div>
        </div>

        <TransformationForm
          datasets={mockDatasets}
          groups={mockTransformationGroups}
          initialData={{
            name: transformation.name,
            description: transformation.description,
            groupId: transformation.groupId,
            testDatasetId: transformation.testDatasetId,
            inputColumns: transformation.inputColumns,
            outputColumns: transformation.outputColumns,
            code: transformation.code
          }}
          onSubmit={handleSubmit}
          onCancel={() => navigate('/transformations')}
        />
      </div>
    </div>
  );
}