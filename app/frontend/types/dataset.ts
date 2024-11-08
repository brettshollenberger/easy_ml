import type { Datasource } from './datasource';

export type DatasetWorkflowStatus = 'analyzing' | 'ready' | 'failed' | 'locked';
export type DatasetStatus = 'training' | 'inference' | 'retired';
export type ColumnType = 'float' | 'integer' | 'boolean' | 'categorical' | 'datetime' | 'text' | 'string';

export type PreprocessingSteps = {
  training?: PreprocessingStep;
  inference?: PreprocessingStep;
}

export type PreprocessingStep = {
  method: 'none' | 'mean' | 'median' | 'forward_fill' | 'most_frequent' | 'categorical' | 'constant' | 'today' | 'label';
  params: {
    categorical_min?: number;
    clip?: {
      min?: number;
      max?: number;
    };
    one_hot?: boolean;
    encode_labels?: boolean;
  };
};

export interface Statistics {
  mean?: number;
  median?: number;
  min?: number;
  max?: number;
  null_count?: number;
  unique_count?: number;
  last_value?: string;
  most_frequent_value?: string;
  counts: object;
}
export interface Column {
  id: number;
  name: string;
  type: ColumnType;
  description?: string;
  dataset_id: number;
  datatype: string;
  polars_datatype: string;
  is_target: boolean;
  hidden: boolean;
  drop_if_null: boolean;
  sample_values: {};
  statistics?: Statistics;
  preprocessing_steps?: PreprocessingSteps;
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