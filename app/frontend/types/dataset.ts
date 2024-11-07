import type { Datasource } from './datasource';
export interface Dataset {
  dataset: {
    id: number;
    name: string;
    description: string;
    target?: string;
    num_rows?: number;
    drop_cols?: string[];
    datasource_id: number;
    columns: Array<{
      name: string;
      type: string;
      description?: string;
      statistics?: {
        mean?: number;
        median?: number;
        min?: number;
        max?: number;
        uniqueCount?: number;
        nullCount?: number;
      };
    }>;
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