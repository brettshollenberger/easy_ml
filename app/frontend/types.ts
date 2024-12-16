import { Dataset } from './dataset';

export type ModelStatus = 'success' | 'failed';
export type DeploymentStatus = 'training' | 'inference' | 'retired';
export type JobStatus = 'running' | 'success' | 'failed' | 'deployed';
export type Frequency = 'hourly' | 'daily' | 'weekly' | 'monthly';
export type ThresholdDirection = 'minimize' | 'maximize';

export interface Featureation {
  id: number;
  name: string;
  description: string;
  groupId: number;
  testDatasetId: number;
  inputColumns: string[];
  outputColumns: string[];
  code: string;
  createdAt: string;
  updatedAt: string;
}

export interface FeatureationGroup {
  id: number;
  name: string;
  description: string;
  features: Featureation[];
  createdAt: string;
  updatedAt: string;
}

interface ModelVersion {
  id: number;
  version: string;
  status: ModelStatus;
  deployment_status: DeploymentStatus;
  configuration: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface Model {
  id: number;
  name: string;
  model_type: string;
  formatted_model_type: string;
  task: string;
  objective: string;
  metrics: Record<string, unknown>;
  status: ModelStatus;
  deployment_status: DeploymentStatus;
  dataset_id: number;
  dataset: Dataset;
  version: string;
  configuration: Record<string, unknown>;
  created_at: string;
  updated_at: string;
  retraining_runs: RetrainingRun[];
  last_run_at: string | null;
  last_run: RetrainingRun | null;
  retraining_job: RetrainingJob | null;
  formatted_frequency: string | null;
  is_training: boolean;
  metrics_url: string | null;
}

export interface Prediction {
  id: number;
  modelId: number;
  timestamp: string;
  input: Record<string, any>;
  output: any;
  groundTruth?: any;
  latencyMs: number;
}

export interface RetrainingJob {
  id: number;
  model: string;
  frequency: Frequency;
  formatted_frequency: string;
  at: number;
  evaluator: Record<string, unknown>;
  tuner_config: Record<string, unknown>;
  tuning_frequency: Frequency;
  last_tuning_at: string | null;
  active: boolean;
  status: JobStatus;
  last_run_at: string | null;
  locked_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface RetrainingRun {
  id: number;
  model_id: number;
  retraining_job_id: number;
  tuner_job_id: number | null;
  status: JobStatus;
  metric_value: number | null;
  threshold: number | null;
  threshold_direction: ThresholdDirection;
  deployable: boolean;
  started_at: string | null;
  is_deploying: boolean;
  completed_at: string | null;
  error_message: string | null;
  metadata: Record<string, unknown>;
  created_at: string;
  updated_at: string;
  stacktrace: string | null;
  metrics: Record<string, number>;
  metrics_url: string | null;
}