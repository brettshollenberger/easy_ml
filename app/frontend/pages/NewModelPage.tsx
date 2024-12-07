import React from 'react';
import { ModelForm } from '../components/ModelForm';

interface Props {
  datasets: Array<{
    id: number;
    name: string;
    rowCount: number;
  }>;
  constants: {
    tasks: Array<{
      value: string;
      label: string;
      description: string;
    }>;
    objectives: Record<string, Array<{
      value: string;
      label: string;
      description: string;
    }>>;
    metrics: Record<string, Array<{
      value: string;
      label: string;
      direction: string;
    }>>;
  };
  errors: Record<string, string[]>;
}

export default function NewModelPage({ datasets, constants, errors }: Props) {
  return (
    <div className="max-w-2xl mx-auto p-8">
      <div className="bg-white rounded-lg shadow-lg p-6">
        <h2 className="text-xl font-semibold text-gray-900 mb-6">
          Create New Model
        </h2>
        <ModelForm 
          datasets={datasets}
          constants={constants}
          errors={errors}
        />
      </div>
    </div>
  );
}