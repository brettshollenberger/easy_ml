import type { Column } from '../../types';

export function getDateColumns(columns: Column[]): string[] {
  return columns
    .filter(col => col.type === 'datetime')
    .map(col => col.name);
}

export function validateSplitConfig(type: string, config: any): string[] {
  const errors: string[] = [];

  switch (type) {
    case 'date':
      if (!config.dateColumn) {
        errors.push('Date column is required');
      }
      if (config.monthsTest < 1) {
        errors.push('Test set must be at least 1 month');
      }
      if (config.monthsValid < 1) {
        errors.push('Validation set must be at least 1 month');
      }
      break;

    case 'predefined':
      if (!config.files?.length) {
        errors.push('At least one file must be selected');
      }
      if (!config.files?.some(f => f.type === 'train')) {
        errors.push('Training set file is required');
      }
      if (!config.files?.some(f => f.type === 'test')) {
        errors.push('Test set file is required');
      }
      break;

    case 'stratified':
    case 'stratified_kfold':
      if (!config.targetColumn) {
        errors.push('Target column is required');
      }
      break;

    case 'group_kfold':
    case 'group_shuffle':
      if (!config.groupColumn) {
        errors.push('Group column is required');
      }
      break;
  }

  return errors;
}