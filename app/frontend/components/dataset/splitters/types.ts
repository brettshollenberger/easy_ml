import type { ColumnType } from '../../../types/datasource';
import type { Datasource } from '../types/datasource';

export type NewDatasetFormProps = {
    datasources: Datasource[];
    constants: {
        columns: ColumnType[];
    };
}
export type SplitterType = 
  | 'date'
  | 'random'
  | 'predefined'
  | 'stratified'
  | 'stratified_kfold'
  | 'group_kfold'
  | 'group_shuffle'
  | 'leave_p_out';

export interface DateSplitConfig {
  date_column: string;
  months_test: number;
  months_valid: number;
}

export interface RandomSplitConfig {
  train_ratio?: number;
  test_ratio?: number;
  valid_ratio?: number;
  seed?: number;
}

export interface PredefinedSplitConfig {
  train_files: string[];
  test_files: string[];
  valid_files: string[];
}

export interface ColumnConfig {
  name: string;
  type: string;
}

export interface PredefinedSplitConfig {
  train_files: string[];
  test_files: string[];
  valid_files: string[];
}

export interface StratifiedSplitConfig {
  stratify_column: string;
  train_ratio: number;
  test_ratio: number;
  valid_ratio: number;
}

export interface KFoldConfig {
  n_splits: number;
  shuffle: boolean;
  random_state?: number;
}

export interface LeavePOutConfig {
  p: number;
  shuffle: boolean;
  random_state?: number;
}

export type SplitConfig = 
  | DateSplitConfig
  | PredefinedSplitConfig
  | StratifiedSplitConfig
  | KFoldConfig
  | LeavePOutConfig
  | Record<string, never>; // For random split

export interface ValidationResult {
  isValid: boolean;
  error?: string;
}

// Validation functions for each splitter type
export const validateDateSplitter = (config: DateSplitConfig): ValidationResult => {
  if (!config.date_column) {
    return { isValid: false, error: "Please select a date column" };
  }
  if (!config.months_test || config.months_test <= 0) {
    return { isValid: false, error: "Test months must be greater than 0" };
  }
  if (!config.months_valid || config.months_valid <= 0) {
    return { isValid: false, error: "Validation months must be greater than 0" };
  }
  return { isValid: true };
};

export const validateRandomSplitter = (config: RandomSplitConfig): ValidationResult => {
  const total = (config.train_ratio ?? 0.6) + 
                (config.test_ratio ?? 0.2) + 
                (config.valid_ratio ?? 0.2);
  
  if (Math.abs(total - 1.0) >= 0.001) {
    return { 
      isValid: false, 
      error: `Split ratios must sum to 1.0 (current sum: ${total.toFixed(2)})` 
    };
  }
  return { isValid: true };
};

export const validatePredefinedSplitter = (config: PredefinedSplitConfig): ValidationResult => {
  if (!config.files || config.files.length === 0) {
    return { isValid: false, error: "Please select at least one file for splitting" };
  }
  return { isValid: true };
};

export const validateStratifiedSplitter = (config: StratifiedSplitConfig): ValidationResult => {
  if (!config.stratify_column) {
    return { isValid: false, error: "Please select a column to stratify on" };
  }
  
  const total = (config.train_ratio ?? 0) + 
                (config.test_ratio ?? 0) + 
                (config.valid_ratio ?? 0);
                
  if (Math.abs(total - 1.0) >= 0.001) {
    return { 
      isValid: false, 
      error: `Split ratios must sum to 1.0 (current sum: ${total.toFixed(2)})` 
    };
  }
  return { isValid: true };
};

export const validateKFoldSplitter = (config: KFoldConfig): ValidationResult => {
  if (!config.n_splits || config.n_splits <= 1) {
    return { isValid: false, error: "Number of splits must be greater than 1" };
  }
  return { isValid: true };
};

export const validateLeavePOutSplitter = (config: LeavePOutConfig): ValidationResult => {
  if (!config.p || config.p <= 0) {
    return { isValid: false, error: "P value must be greater than 0" };
  }
  return { isValid: true };
};

// Main validation function
export const validateSplitterConfig = (type: SplitterType, config: SplitConfig): ValidationResult => {
  switch (type) {
    case 'date':
      return validateDateSplitter(config as DateSplitConfig);
    case 'random':
      return validateRandomSplitter(config as RandomSplitConfig);
    case 'predefined':
      return validatePredefinedSplitter(config as PredefinedSplitConfig);
    case 'stratified':
      return validateStratifiedSplitter(config as StratifiedSplitConfig);
    case 'stratified_kfold':
    case 'group_kfold':
      return validateKFoldSplitter(config as KFoldConfig);
    case 'leave_p_out':
      return validateLeavePOutSplitter(config as LeavePOutConfig);
    default:
      return { isValid: false, error: "Invalid splitter type" };
  }
};
