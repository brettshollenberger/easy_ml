export interface Dataset {
  dataset: {
    id?: number;
    name: string;
    description: string;
    target: string;
    datasource_id: number;
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
    columns?: Array<{
      name: string;
      type: string;
      selected: boolean;
      sample?: any[];
    }>;
    drop_cols?: string[];
  };
}

export interface Datasource {
  id: number;
  name: string;
  label: string;
  value: number;
  datasource_type: string;
  s3_bucket?: string;
  root_dir?: string;
}

export interface Props {
  constants: {
    COLUMN_TYPES: Array<{ value: string; label: string }>;
  };
  datasources: Datasource[];
} 