import type { Model, RetrainingJob, RetrainingRun, Dataset, Prediction } from './types';

// Helper function to generate dates
const daysAgo = (days: number) => {
  const date = new Date();
  date.setDate(date.getDate() - days);
  return date.toISOString();
};

export const datasets: Dataset[] = [
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
          nullCount: 1250
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
          nullCount: 3750
        }
      },
      {
        name: 'subscription_tier',
        type: 'categorical',
        description: 'Customer subscription level',
        statistics: {
          uniqueCount: 3,
          nullCount: 125
        }
      },
      {
        name: 'last_login',
        type: 'datetime',
        description: 'Last time the customer logged in',
        statistics: {
          nullCount: 5000
        }
      }
    ],
    sampleData: [
      {
        usage_days: 234,
        total_spend: 567.89,
        support_tickets: 1,
        subscription_tier: 'premium',
        last_login: '2024-03-01'
      },
      {
        usage_days: 45,
        total_spend: null,
        support_tickets: null,
        subscription_tier: 'basic',
        last_login: null
      }
    ],
    rowCount: 25000,
    updatedAt: '2024-03-10T12:00:00Z'
  }
];

export const models: Model[] = [
  {
    id: 1,
    name: 'Customer Churn Predictor',
    modelType: 'classification',
    status: 'completed',
    deploymentStatus: 'inference',
    promoted: true,
    datasetId: 1,
    configuration: {
      algorithm: 'xgboost',
      features: ['usage_days', 'total_spend', 'support_tickets'],
      objective: 'binary:logistic',
      metrics: ['accuracy', 'f1']
    },
    version: '2.1.0',
    rootDir: '/models/churn_predictor',
    file: { path: 'model.joblib' },
    createdAt: daysAgo(30),
    updatedAt: daysAgo(0)
  }
];

export const retrainingJobs: RetrainingJob[] = [
  {
    id: 1,
    model: 'Customer Churn Predictor',
    frequency: 'daily',
    at: 2,
    evaluator: {
      metric: 'f1_score',
      threshold: 0.85,
      direction: 'maximize'
    },
    tunerConfig: {
      trials: 10,
      metrics: ['f1_score'],
      parameters: {
        max_depth: { min: 3, max: 10 },
        learning_rate: { min: 0.01, max: 0.1 }
      }
    },
    tuningFrequency: 'weekly',
    lastTuningAt: daysAgo(7),
    active: true,
    status: 'completed',
    lastRunAt: daysAgo(1),
    lockedAt: null,
    createdAt: daysAgo(30),
    updatedAt: daysAgo(0)
  }
];

export const retrainingRuns: RetrainingRun[] = [
  {
    id: 1,
    modelId: 1,
    retrainingJobId: 1,
    tunerJobId: null,
    status: 'completed',
    metricValue: 0.89,
    threshold: 0.85,
    thresholdDirection: 'maximize',
    shouldPromote: true,
    startedAt: daysAgo(1),
    completedAt: daysAgo(1),
    errorMessage: null,
    metadata: {
      metrics: {
        accuracy: 0.92,
        precision: 0.88,
        recall: 0.90,
        f1: 0.89
      },
      parameters: {
        max_depth: 6,
        learning_rate: 0.05
      }
    },
    createdAt: daysAgo(1),
    updatedAt: daysAgo(1)
  },
  {
    id: 2,
    modelId: 1,
    retrainingJobId: 1,
    tunerJobId: 1,
    status: 'completed',
    metricValue: 0.86,
    threshold: 0.85,
    thresholdDirection: 'maximize',
    shouldPromote: true,
    startedAt: daysAgo(2),
    completedAt: daysAgo(2),
    errorMessage: null,
    metadata: {
      metrics: {
        accuracy: 0.90,
        precision: 0.85,
        recall: 0.87,
        f1: 0.86
      },
      parameters: {
        max_depth: 5,
        learning_rate: 0.03
      }
    },
    createdAt: daysAgo(2),
    updatedAt: daysAgo(2)
  },
  {
    id: 3,
    modelId: 1,
    retrainingJobId: 1,
    tunerJobId: null,
    status: 'failed',
    metricValue: null,
    threshold: 0.85,
    thresholdDirection: 'maximize',
    shouldPromote: false,
    startedAt: daysAgo(3),
    completedAt: daysAgo(3),
    errorMessage: 'Training failed due to insufficient memory',
    metadata: null,
    createdAt: daysAgo(3),
    updatedAt: daysAgo(3)
  },
  {
    id: 4,
    modelId: 1,
    retrainingJobId: 1,
    tunerJobId: null,
    status: 'completed',
    metricValue: 0.83,
    threshold: 0.85,
    thresholdDirection: 'maximize',
    shouldPromote: false,
    startedAt: daysAgo(4),
    completedAt: daysAgo(4),
    errorMessage: null,
    metadata: {
      metrics: {
        accuracy: 0.87,
        precision: 0.82,
        recall: 0.84,
        f1: 0.83
      },
      parameters: {
        max_depth: 4,
        learning_rate: 0.02
      }
    },
    createdAt: daysAgo(4),
    updatedAt: daysAgo(4)
  }
];