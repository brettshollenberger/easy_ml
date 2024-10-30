export type ModelStatus = 'pending' | 'training' | 'ready' | 'error';
export type JobStatus = 'pending' | 'running' | 'completed' | 'failed';
export type Frequency = 'hourly' | 'daily' | 'weekly' | 'monthly';
export type ThresholdDirection = 'minimize' | 'maximize';

export interface Dataset {
  id: number;
  name: string;
  description: string;
  columns: Column[];
  sampleData: Record<string, any>[];
  rowCount: number;
  updatedAt: string;
}

export interface Column {
  name: string;
  type: 'numeric' | 'categorical' | 'datetime' | 'text';
  description?: string;
  statistics?: {
    mean?: number;
    median?: number;
    min?: number;
    max?: number;
    uniqueCount?: number;
    nullCount?: number;
  };
}

export interface Model {
  id: number;
  name: string;
  modelType: string;
  status: ModelStatus;
  datasetId: number;
  configuration: Record<string, unknown>;
  version: string;
  rootDir: string;
  file: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface RetrainingJob {
  id: number;
  model: string;
  frequency: Frequency;
  at: number;
  evaluator: Record<string, unknown>;
  tunerConfig: Record<string, unknown>;
  tuningFrequency: Frequency;
  lastTuningAt: string | null;
  active: boolean;
  status: JobStatus;
  lastRunAt: string | null;
  lockedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface RetrainingRun {
  id: number;
  modelId: number;
  retrainingJobId: number;
  tunerJobId: number | null;
  status: JobStatus;
  metricValue: number | null;
  threshold: number | null;
  thresholdDirection: ThresholdDirection;
  shouldPromote: boolean;
  startedAt: string | null;
  completedAt: string | null;
  errorMessage: string | null;
  metadata: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface TunerJob {
  id: number;
  config: Record<string, unknown>;
  bestTunerRunId: number | null;
  modelId: number;
  status: JobStatus;
  direction: ThresholdDirection;
  startedAt: string | null;
  completedAt: string | null;
  metadata: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface TunerRun {
  id: number;
  tunerJobId: number;
  hyperparameters: Record<string, unknown>;
  value: number | null;
  trialNumber: number;
  status: JobStatus;
  createdAt: string;
  updatedAt: string;
}