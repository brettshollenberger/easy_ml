import type { Datasource } from "./datasource";

export type DatasetWorkflowStatus = "analyzing" | "ready" | "failed" | "locked";
export type DatasetStatus = "training" | "inference" | "retired";
export type ColumnType =
  | "float"
  | "integer"
  | "boolean"
  | "categorical"
  | "datetime"
  | "text"
  | "string";

export type PreprocessingSteps = {
  training?: PreprocessingStep;
  inference?: PreprocessingStep;
};

export type Feature = {
  id?: number;
  name: string;
  feature_class: string;
  feature_method: string;
  feature_position: number;
  dataset_id?: number;
  description?: string;
  feature_type?: "calculation" | "lookup" | "other";
  _destroy?: boolean;
};

export type PreprocessingStep = {
  method:
    | "none"
    | "mean"
    | "median"
    | "ffill"
    | "most_frequent"
    | "categorical"
    | "constant"
    | "today";
  params: {
    value?: number;
    constant?: string;
    categorical_min?: number;
    clip?: {
      min?: number;
      max?: number;
    };
    one_hot?: boolean;
    ordinal_encoding?: boolean;
  };
};

export interface StatisticSet {
  mean?: number;
  median?: number;
  min?: number;
  max?: number;
  last_value?: string;
  count?: number;
  null_count?: number;
  unique_count?: number;
  most_frequent_value?: string;
  counts: object;
  num_rows?: number;
  sample_data?: any[];
}

export interface Statistics {
  raw: StatisticSet;
  processed: StatisticSet;
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
  description?: string;
  status: DatasetStatus;
  needs_refresh: boolean;
  workflow_status: DatasetWorkflowStatus;
  target?: string;
  num_rows?: number;
  drop_cols?: string[];
  datasource_id: number;
  columns: Array<Column>;
  sample_data: Record<string, any>[];
  transforms?: Array<Feature>;
  preprocessing_steps: {
    training: Record<string, any>;
  };
  splitter_attributes?: {
    splitter_type: string;
    date_col: string;
    months_test: number;
    months_valid: number;
  };
  stacktrace?: string;
}

export interface NewDatasetForm {
  dataset: {
    name?: string;
    description?: string;
    datasource_id?: number;
    splitter_attributes: {
      splitter_type: string;
      date_col: string;
      months_test: number;
      months_valid: number;
    };
  };
}

export interface NewDatasetFormProps {
  constants: {
    COLUMN_TYPES: Array<{ value: string; label: string }>;
  };
  datasources: Datasource[];
}

export interface PreprocessingConstants {
  column_types: Array<{ value: ColumnType; label: string }>;
  preprocessing_strategies: {
    [K in ColumnType]: Array<{ value: string; label: string }>;
  };
}
