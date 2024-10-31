import React, { useState } from 'react';
import { ChevronLeft, ChevronRight, Clock, CheckCircle2, XCircle } from 'lucide-react';
import type { Prediction } from '../types';

interface PredictionStreamProps {
  predictions: Prediction[];
}

const ITEMS_PER_PAGE = 10;

export function PredictionStream({ predictions }: PredictionStreamProps) {
  const [currentPage, setCurrentPage] = useState(1);
  const totalPages = Math.ceil(predictions.length / ITEMS_PER_PAGE);
  
  const paginatedPredictions = predictions.slice(
    (currentPage - 1) * ITEMS_PER_PAGE,
    currentPage * ITEMS_PER_PAGE
  );

  return (
    <div className="bg-white rounded-lg shadow-lg p-6">
      <div className="flex justify-between items-center mb-6">
        <h3 className="text-lg font-semibold">Live Predictions</h3>
        <div className="flex items-center gap-2">
          <button
            onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
            disabled={currentPage === 1}
            className="p-1 rounded-md hover:bg-gray-100 disabled:opacity-50"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>
          <span className="text-sm text-gray-600">
            Page {currentPage} of {totalPages}
          </span>
          <button
            onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages}
            className="p-1 rounded-md hover:bg-gray-100 disabled:opacity-50"
          >
            <ChevronRight className="w-5 h-5" />
          </button>
        </div>
      </div>

      <div className="space-y-4">
        {paginatedPredictions.map((prediction) => (
          <div
            key={prediction.id}
            className="border border-gray-200 rounded-lg p-4 hover:border-gray-300 transition-colors"
          >
            <div className="flex justify-between items-start mb-3">
              <div className="flex items-center gap-2">
                <Clock className="w-4 h-4 text-gray-400" />
                <span className="text-sm text-gray-500">
                  {new Date(prediction.timestamp).toLocaleString()}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-sm text-gray-500">
                  {prediction.latencyMs.toFixed(2)}ms
                </span>
                {prediction.groundTruth !== undefined && (
                  prediction.output === prediction.groundTruth ? (
                    <CheckCircle2 className="w-5 h-5 text-green-500" />
                  ) : (
                    <XCircle className="w-5 h-5 text-red-500" />
                  )
                )}
              </div>
            </div>

            <div className="grid md:grid-cols-2 gap-6">
              <div>
                <h4 className="text-sm font-medium text-gray-500 mb-2">Input</h4>
                <div className="bg-gray-50 rounded-md p-3">
                  <pre className="text-sm whitespace-pre-wrap">
                    {JSON.stringify(prediction.input, null, 2)}
                  </pre>
                </div>
              </div>

              <div>
                <h4 className="text-sm font-medium text-gray-500 mb-2">Prediction</h4>
                <div className="bg-gray-50 rounded-md p-3">
                  <div className="flex items-center justify-between">
                    <span className="font-medium">
                      {typeof prediction.output === 'boolean' 
                        ? prediction.output ? 'Will Churn' : 'Will Not Churn'
                        : prediction.output}
                    </span>
                    {prediction.groundTruth !== undefined && (
                      <span className="text-sm text-gray-500">
                        Ground Truth: {prediction.groundTruth ? 'Churned' : 'Retained'}
                      </span>
                    )}
                  </div>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}