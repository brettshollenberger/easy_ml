import React from 'react';
import { ModelForm } from '../components/ModelForm';

interface Props {
  datasets: Array<{
    id: number;
    name: string;
    rowCount: number;
  }>;
  constants: {
    TASKS: Array<{
      value: string;
      label: string;
      description: string;
    }>;
    OBJECTIVES: Record<string, Array<{
      value: string;
      label: string;
      description: string;
    }>>;
    METRICS: Record<string, Array<{
      value: string;
      label: string;
      direction: string;
    }>>;
  };
}

export default function NewModelPage({ datasets, constants }: Props) {
  return (
    <div className="max-w-4xl mx-auto py-6 px-4 sm:px-6 lg:px-8">
      <h1 className="text-2xl font-semibold text-gray-900 mb-6">Create New Model</h1>
      <ModelForm 
        datasets={datasets}
        constants={constants}
      />
    </div>
  );
}