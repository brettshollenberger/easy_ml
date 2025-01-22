export type ColumnType =
  | "float"
  | "integer"
  | "boolean"
  | "categorical"
  | "datetime"
  | "text";

export interface Schema {
  [key: string]: ColumnType;
}

export interface Datasource {
  id: number;
  name: string;
  datasource_type: string;
  is_syncing: boolean;
  last_synced_at: string | null;
  columns: string[];
  schema: Schema;
  error?: string;
}

export interface DatasourceFormProps {
  datasource?: Datasource;
  constants: {
    DATASOURCE_TYPES: Array<{ value: string; label: string; description: string }>;
    s3: {
      S3_REGIONS: Array<{ value: string; label: string }>;
    };
  };
}