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
  const { rootPath } = usePage().props;
  const { data, setData, put, processing, errors } = useInertiaForm<ModelFormData>({
    model: {
      id: model.id,
      name: model.name,
      modelType: model.model_type,
      datasetId: model.dataset.id,
      task: model.task as string || 'classification',
      objective: model.objective as string || 'binary:logistic',
      metrics: model.metrics as string[] || ['accuracy'],
      configuration: model.configuration || {},
      retraining_job_attributes: model.retraining_job ? {
        frequency: model.retraining_job.frequency,
        at: model.retraining_job.at,
        active: model.retraining_job.active,
        tuner_config: {
          n_trials: model.retraining_job.tuner_config?.n_trials,
          objective: model.retraining_job.tuner_config?.objective,
          config: model.retraining_job.tuner_config?.config
        }
      } : undefined
    }
  });

  const handleSubmit = (formData: any) => {
    put(`${rootPath}/models/${model.id}`, {
      onSuccess: () => {
        router.visit(`${rootPath}/models`);
      },
    });
  };

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
            initialData={data.model}
            datasets={datasets}
            constants={constants}
            errors={errors}
            processing={processing}
            onChange={(field, value) => setData(`model.${field}`, value)}
            onSubmit={handleSubmit}
          />
        </div>
      </div>
    </div>
  );
}