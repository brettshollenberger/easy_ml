import React from 'react';
import { router, Link, usePage } from "@inertiajs/react";
import { useInertiaForm } from "use-inertia-form";
import { ArrowLeft, Brain } from 'lucide-react';
import { ModelForm } from '../components/ModelForm';
import { Model, Dataset } from '../types';

interface ModelFormData {
  model: Model;
}

interface PageProps {
  model: Model;
  datasets: Dataset[];
  constants: {
    modelTypes: string[];
    tasks: string[];
    objectives: string[];
    metrics: string[];
  };
}

export default function EditModelPage({ model, datasets, constants }: PageProps) {
  return (
    <div className="max-w-3xl mx-auto py-8">
      <div className="bg-white rounded-lg shadow-lg">
        <div className="px-6 py-4 border-b border-gray-200">
          <div className="flex items-center gap-3">
            <Brain className="w-6 h-6 text-blue-600" />
            <h2 className="text-xl font-semibold text-gray-900">Edit Model</h2>
          </div>
        </div>

        <div className="p-6">
          <ModelForm
            initialData={model}
            datasets={datasets}
            constants={constants}
            isEditing={true}
          />
        </div>
      </div>
    </div>
  );
}