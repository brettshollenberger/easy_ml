import React from 'react';
import { ModelForm } from '../components/ModelForm';

export function NewModelPage() {
  return (
    <div className="max-w-2xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-6">
          Create New Model
        </h2>
        <ModelForm onSubmit={(data) => {
          console.log('Creating new model:', data);
        }} />
      </div>
    </div>
  );
}