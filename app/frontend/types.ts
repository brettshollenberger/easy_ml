export type ModelStatus = 'completed' | 'failed';
export type DeploymentStatus = 'inference' | 'retired';
export type JobStatus = 'pending' | 'running' | 'completed' | 'failed';
export type Frequency = 'hourly' | 'daily' | 'weekly' | 'monthly';
export type ThresholdDirection = 'minimize' | 'maximize';

export interface Transformation {
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

export interface TransformationGroup {
  id: number;
  name: string;
  description: string;
  transformations: Transformation[];
  createdAt: string;
  updatedAt: string;
}

interface ModelVersion {
  id: number;
  version: string;
  status: ModelStatus;
  deploymentStatus: DeploymentStatus;
  promoted: boolean;
  configuration: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface Model {
  id: number;
  name: string;
  modelType: string;
  status: ModelStatus;
  deploymentStatus: DeploymentStatus;
  promoted: boolean;
  datasetId: number;
  configuration: Record<string, unknown>;
  version: string;
  rootDir: string;
  file: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
  versions?: ModelVersion[];
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

export type ColumnType = 
  | 'float' 
  | 'integer' 
  | 'boolean' 
  | 'datetime' 
  | 'string' 
  | 'categorical';

export interface Column {
  name: string;
  datatype: ColumnType;
  drop_if_null: boolean;
  hidden: boolean;
  sample_values: any[];
  statistics?: {
    count?: number;
    max?: number;
    min?: number;
    mean?: number;
    median?: number;
    std?: number;
    sample?: any[];
    unique_count?: number;
    null_count?: number;
  };
}

export interface PreprocessingConstants {
  column_types: Array<{ value: ColumnType; label: string }>;
  preprocessing_strategies: {
    float: Array<{ value: string; label: string }>;
    integer: Array<{ value: string; label: string }>;
    boolean: Array<{ value: string; label: string }>;
    datetime: Array<{ value: string; label: string }>;
    string: Array<{ value: string; label: string }>;
    categorical: Array<{ value: string; label: string }>;
  };
}

export type PreprocessingStrategy = {
  method: 'none' | 'mean' | 'median' | 'most_frequent' | 'constant' | 'categorical' | 'label' | 'today';
  params?: {
    // ... existing params ...
  };
};