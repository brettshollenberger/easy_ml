import type { Model, RetrainingJob, RetrainingRun, TunerJob, TunerRun, Dataset } from './types';

export const mockDatasets: Dataset[] = [
  {
    id: 1,
    name: 'Customer Churn Dataset',
    description: 'Historical customer data for churn prediction',
    columns: [
      {
        name: 'usage_days',
        type: 'numeric',
        description: 'Number of days customer has used the product',
        statistics: {
          mean: 145.7,
          median: 130,
          min: 1,
          max: 365,
          nullCount: 0
        }
      },
      {
        name: 'total_spend',
        type: 'numeric',
        description: 'Total customer spend in USD',
        statistics: {
          mean: 487.32,
          median: 425.50,
          min: 0,
          max: 2500.00,
          nullCount: 0
        }
      },
      {
        name: 'support_tickets',
        type: 'numeric',
        description: 'Number of support tickets opened',
        statistics: {
          mean: 2.3,
          median: 1,
          min: 0,
          max: 15,
          nullCount: 0
        }
      },
      {
        name: 'subscription_tier',
        type: 'categorical',
        description: 'Customer subscription level',
        statistics: {
          uniqueCount: 3,
          nullCount: 0
        }
      }
    ],
    sampleData: [
      {
        usage_days: 234,
        total_spend: 567.89,
        support_tickets: 1,
        subscription_tier: 'premium'
      },
      {
        usage_days: 45,
        total_spend: 123.45,
        support_tickets: 3,
        subscription_tier: 'basic'
      },
      {
        usage_days: 178,
        total_spend: 890.12,
        support_tickets: 0,
        subscription_tier: 'premium'
      }
    ],
    rowCount: 25000,
    updatedAt: '2024-03-10T12:00:00Z'
  },
  {
    id: 2,
    name: 'Customer LTV Dataset',
    description: 'Customer lifetime value prediction data',
    columns: [
      {
        name: 'historical_spend',
        type: 'numeric',
        description: 'Historical spending amount',
        statistics: {
          mean: 2456.78,
          median: 2100.00,
          min: 0,
          max: 15000.00,
          nullCount: 0
        }
      },
      {
        name: 'engagement_score',
        type: 'numeric',
        description: 'Customer engagement metric',
        statistics: {
          mean: 7.5,
          median: 7.8,
          min: 0,
          max: 10,
          nullCount: 0
        }
      }
    ],
    sampleData: [
      {
        historical_spend: 3456.78,
        engagement_score: 8.5
      },
      {
        historical_spend: 1234.56,
        engagement_score: 6.7
      }
    ],
    rowCount: 18000,
    updatedAt: '2024-03-09T15:30:00Z'
  }
];

export const mockModels: Model[] = [
  {
    id: 1,
    name: 'Customer Churn Predictor',
    modelType: 'classification',
    status: 'ready',
    datasetId: 1,
    configuration: {
      algorithm: 'xgboost',
      features: ['usage_days', 'total_spend', 'support_tickets'],
    },
    version: '2.1.0',
    rootDir: '/models/churn_predictor',
    file: { path: 'model.joblib' },
    createdAt: '2024-02-15T08:00:00Z',
    updatedAt: '2024-03-10T15:30:00Z',
  },
  {
    id: 2,
    name: 'Customer LTV Predictor',
    modelType: 'regression',
    status: 'ready',
    datasetId: 2,
    configuration: {
      algorithm: 'lightgbm',
      features: ['historical_spend', 'engagement_score', 'subscription_tier'],
    },
    version: '1.2.0',
    rootDir: '/models/ltv_predictor',
    file: { path: 'model.joblib' },
    createdAt: '2024-01-20T09:00:00Z',
    updatedAt: '2024-03-09T11:20:00Z',
  },
];

export const mockRetrainingJobs: RetrainingJob[] = [
  {
    id: 1,
    model: 'Customer Churn Predictor',
    frequency: 'daily',
    at: 2, // 2 AM
    evaluator: {
      metric: 'f1_score',
      threshold: 0.85,
    },
    tunerConfig: {
      maxTrials: 20,
      parameters: { learning_rate: [0.01, 0.1] },
    },
    tuningFrequency: 'monthly',
    lastTuningAt: '2024-03-01T02:00:00Z',
    active: true,
    status: 'completed',
    lastRunAt: '2024-03-10T02:00:00Z',
    lockedAt: null,
    createdAt: '2024-01-01T00:00:00Z',
    updatedAt: '2024-03-10T02:15:00Z',
  },
];

export const mockRetrainingRuns: RetrainingRun[] = [
  {
    id: 1,
    modelId: 1,
    retrainingJobId: 1,
    tunerJobId: null,
    status: 'completed',
    metricValue: 0.891,
    threshold: 0.85,
    thresholdDirection: 'maximize',
    shouldPromote: true,
    startedAt: '2024-03-10T02:00:00Z',
    completedAt: '2024-03-10T02:15:00Z',
    errorMessage: null,
    metadata: {
      metrics: {
        f1_score: 0.891,
        precision: 0.876,
        recall: 0.907,
      },
    },
    createdAt: '2024-03-10T02:00:00Z',
    updatedAt: '2024-03-10T02:15:00Z',
  },
];

export const mockTunerJobs: TunerJob[] = [
  {
    id: 1,
    config: {
      maxTrials: 20,
      parameters: { learning_rate: [0.01, 0.1] },
    },
    bestTunerRunId: 3,
    modelId: 1,
    status: 'completed',
    direction: 'maximize',
    startedAt: '2024-03-01T02:00:00Z',
    completedAt: '2024-03-01T03:30:00Z',
    metadata: {
      bestMetrics: {
        f1_score: 0.891,
      },
    },
    createdAt: '2024-03-01T02:00:00Z',
    updatedAt: '2024-03-01T03:30:00Z',
  },
];

export const mockTunerRuns: TunerRun[] = [
  {
    id: 1,
    tunerJobId: 1,
    hyperparameters: {
      learning_rate: 0.05,
      max_depth: 6,
    },
    value: 0.891,
    trialNumber: 1,
    status: 'completed',
    createdAt: '2024-03-01T02:00:00Z',
    updatedAt: '2024-03-01T02:10:00Z',
  },
];