export const SPLITTER_OPTIONS = [
  { 
    value: 'date', 
    label: 'Date Split',
    description: 'Split data based on a date/time column'
  },
  { 
    value: 'random', 
    label: 'Random Split',
    description: 'Randomly split data into train/test/validation sets (70/20/10)'
  },
  { 
    value: 'predefined', 
    label: 'Predefined Splits',
    description: 'Use separate files for train/test/validation sets'
  },
//   { 
//     value: 'stratified', 
//     label: 'Stratified Shuffle Split',
//     description: 'Maintain the percentage of samples for each class'
//   },
//   { 
//     value: 'stratified_kfold', 
//     label: 'Stratified K-Fold',
//     description: 'K-fold with preserved class distribution'
//   },
//   { 
//     value: 'group_kfold', 
//     label: 'Group K-Fold',
//     description: 'K-fold ensuring group integrity'
//   },
//   { 
//     value: 'group_shuffle', 
//     label: 'Group Shuffle Split',
//     description: 'Random split respecting group boundaries'
//   },
//   { 
//     value: 'leave_p_out', 
//     label: 'Leave P Out',
//     description: 'Use P samples for testing in each fold'
//   }
] as const;

export const DEFAULT_CONFIGS = {
  date: {
    date_column: '',
    months_test: 2,
    months_valid: 1
  },
  random: {},
  predefined: {
    train_files: [],
    test_files: [],
    valid_files: []
  },
  stratified: {
    targetColumn: '',
    testSize: 20,
    validSize: 10
  },
  stratified_kfold: {
    targetColumn: '',
    nSplits: 5
  },
  group_kfold: {
    groupColumn: '',
    nSplits: 5
  },
  group_shuffle: {
    groupColumn: '',
    testSize: 20,
    validSize: 10
  },
  leave_p_out: {
    p: 1
  }
} as const;