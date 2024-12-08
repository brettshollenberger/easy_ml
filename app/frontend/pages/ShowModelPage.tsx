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
  return (
    <div className="max-w-3xl mx-auto py-8">
      <ModelDetails model={model} />
    </div>
  );
}