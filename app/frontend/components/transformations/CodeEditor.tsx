import React from 'react';
import { AlertCircle } from 'lucide-react';

interface CodeEditorProps {
  value: string;
  onChange: (value: string) => void;
  language: string;
}

export function CodeEditor({ value, onChange, language }: CodeEditorProps) {
  return (
    <div className="space-y-4">
      <div className="bg-gray-900 rounded-lg overflow-hidden">
        <div className="flex items-center justify-between px-4 py-2 bg-gray-800">
          <span className="text-sm text-gray-400">Ruby Featureation</span>
          <span className="text-xs px-2 py-1 bg-gray-700 rounded text-gray-300">
            {language}
          </span>
        </div>
        <textarea
          value={value}
          onChange={(e) => onChange(e.target.value)}
          className="w-full h-64 p-4 bg-gray-900 text-gray-100 font-mono text-sm focus:outline-none"
          placeholder={`def transform(df)\n  # Your feature code here\n  # Example:\n  # df["column"] = df["column"].map { |value| value.upcase }\n  df\nend`}
          spellCheck={false}
        />
      </div>

      <div className="bg-blue-50 rounded-lg p-4">
        <div className="flex gap-2">
          <AlertCircle className="w-5 h-5 text-blue-500 flex-shrink-0" />
          <div className="text-sm text-blue-700">
            <p className="font-medium mb-1">Featureation Guidelines</p>
            <ul className="list-disc pl-4 space-y-1">
              <li>The function must be named 'feature'</li>
              <li>It should accept a DataFrame as its only parameter</li>
              <li>All operations should be performed on the DataFrame object</li>
              <li>The function must return the modified DataFrame</li>
              <li>Use standard Ruby syntax and DataFrame operations</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}