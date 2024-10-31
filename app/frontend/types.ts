import type { Model, RetrainingJob, RetrainingRun } from './types';

export type ModelStatus = 'completed' | 'failed';
export type DeploymentStatus = 'inference' | 'retired';
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

// Rest of the existing types...