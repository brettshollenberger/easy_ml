import React from 'react';
// import { useNavigate, useParams } from 'react-router-dom';
import { ArrowLeft, Brain } from 'lucide-react';
import { ModelForm } from '../components/ModelForm';
import { mockModels } from '../mockData';

export default function EditModelPage() {
  const navigate = useNavigate();
  const { id } = useParams();
  const model = mockModels.find(m => m.id === Number(id));

  if (!model) {
    return (
      <div className="text-center py-12">
        <h2 className="text-xl font-semibold text-gray-900">Model not found</h2>
      </div>
    );
  }

  return (
    <div className="max-w-3xl mx-auto">
      <button
        onClick={() => navigate('/')}
        className="flex items-center text-gray-600 hover:text-gray-800 mb-6"
      >
        <ArrowLeft className="w-4 h-4 mr-2" />
        Back to Models
      </button>

      <div className="bg-white rounded-lg shadow-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <Brain className="w-6 h-6 text-blue-600" />
            <h2 className="text-xl font-semibold text-gray-900">Edit Model</h2>
          </div>
        </div>

        <div className="p-6">
          <ModelForm
            initialData={{
              name: model.name,
              modelType: model.modelType,
              datasetId: model.datasetId,
              task: 'classification',
              objective: (model.configuration as any).objective || 'binary:logistic',
              metrics: (model.configuration as any).metrics || ['accuracy', 'f1']
            }}
            onSubmit={(data) => {
              console.log('Updating model:', data);
              navigate('/');
            }}
            isEditing={true}
          />
        </div>
      </div>
    </div>
  );
}