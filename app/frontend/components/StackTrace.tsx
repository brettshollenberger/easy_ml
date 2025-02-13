interface StackTraceProps {
  stacktrace: string;
}

export function StackTrace({ stacktrace }: StackTraceProps) {
  return (
    <div className="mt-2 p-3 bg-red-50 rounded-md">
      <pre className="text-xs text-red-700 whitespace-pre-wrap break-words [word-break:break-word] font-mono">
        {stacktrace}
      </pre>
    </div>
  );
}
