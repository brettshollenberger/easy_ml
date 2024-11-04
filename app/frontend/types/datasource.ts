export interface Datasource {
  id: number;
  name: string;
  datasource_type: string;
  s3_bucket: string;
  s3_prefix: string;
  s3_region: string;
  last_synced_at: string;
  is_syncing: boolean;
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