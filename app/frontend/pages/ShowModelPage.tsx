import React from 'react';
import { ModelDetails } from '../components/ModelDetails';
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

export default function ShowModelPage({ model, rootPath }: PageProps) {
//   const selectedModel = models.find((m) => m.id === selectedModelId);
//   const modelRuns = models.find((m) => m.id === selectedModelId)?.retrainingRuns || [];
//   const modelJob = models.find((m) => m.id === selectedModelId)?.retrainingJob || null;

  return (
    <div className="max-w-3xl mx-auto py-8">
      <div className="bg-white rounded-lg shadow-lg">
        <ModelDetails model={model} />
      </div>
    </div>
  );
}