import type { Datasource } from './datasource';
export interface Dataset {
  dataset: {
    id?: number;
    name: string;
    description: string;
    target?: string;
    drop_cols?: string[];
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
  };
}

export interface Props {
  constants: {
    COLUMN_TYPES: Array<{ value: string; label: string }>;
  };
  datasources: Datasource[];
} 