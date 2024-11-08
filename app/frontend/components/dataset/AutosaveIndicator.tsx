import React from 'react';
import { Save, AlertCircle, Loader2 } from 'lucide-react';

interface AutosaveIndicatorProps {
  saving: boolean;
  saved: boolean;
  error: string | null;
}

export function AutosaveIndicator({ saving, saved, error }: AutosaveIndicatorProps) {
  if (error) {
    return (
      <div className="flex items-center gap-2 text-red-600">
        <AlertCircle className="w-4 h-4" />
        <span className="text-sm font-medium">{error}</span>
      </div>
    );
  }

  if (saving) {
    return (
      <div className="flex items-center gap-2 text-blue-600">
        <Loader2 className="w-4 h-4 animate-spin" />
        <span className="text-sm font-medium">Saving changes...</span>
      </div>
    );
  }

  if (saved) {
    return (
      <div className="flex items-center gap-2 text-green-600">
        <Save className="w-4 h-4" />
        <span className="text-sm font-medium">Changes saved</span>
      </div>
    );
  }

  return null;
}