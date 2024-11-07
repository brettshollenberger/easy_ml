import type { Datasource } from './datasource';

export type DatasetWorkflowStatus = 'analyzing' | 'ready' | 'failed' | 'locked';
export type DatasetStatus = 'training' | 'inference' | 'retired';
export interface Column {
  name: string;
  type: 'float' | 'integer' | 'boolean' | 'categorical' | 'datetime' | 'text' | 'string';
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

export interface Dataset {
  dataset: {
    id: number;
    name: string;
    description: string;
    status: DatasetStatus;
    workflow_status: DatasetWorkflowStatus;
    target?: string;
    num_rows?: number;
    drop_cols?: string[];
    datasource_id: number;
    columns: Array<Column>;
    sample_data: Record<string, any>[];
    preprocessing_steps: {
      training: Record<string, any>;
    };
    splitter: {
      date: {
        date_col: string;
        months_test: number;
        months_valid: number;
      };
    };
  };
}

export interface Props {
  constants: {
    COLUMN_TYPES: Array<{ value: string; label: string }>;
  };
  datasources: Datasource[];
} 