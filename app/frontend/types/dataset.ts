import type { Datasource } from './datasource';

export type DatasetWorkflowStatus = 'analyzing' | 'ready' | 'failed' | 'locked';
export type DatasetStatus = 'training' | 'inference' | 'retired';
export interface Column {
  id: number;
  name: string;
  type: 'float' | 'integer' | 'boolean' | 'categorical' | 'datetime' | 'text' | 'string';
  description?: string;
  dataset_id: number;
  datatype: string;
  polars_datatype: string;
  preprocessing_steps?: {};
  is_target: boolean;
  hidden: boolean;
  drop_if_null: boolean;
  sample_values: {};
  statistics?: {
    mean?: number;
    median?: number;
    min?: number;
    max?: number;
    null_count?: number;
  };
}

export interface Dataset {
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
}

export interface DatasetForm {
  dataset: Dataset;
}

export interface Props {
  constants: {
    COLUMN_TYPES: Array<{ value: string; label: string }>;
  };
  datasources: Datasource[];
} 