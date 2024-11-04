import React, { createContext, useContext, useState, useCallback } from 'react';
import { AlertCircle, CheckCircle, XCircle, X } from 'lucide-react';

type AlertType = 'success' | 'error' | 'info';

interface Alert {
  id: string;
  type: AlertType;
  message: string;
  isLeaving?: boolean;
}

interface AlertContextType {
  alerts: Alert[];
  showAlert: (type: AlertType, message: string) => void;
  removeAlert: (id: string) => void;
}

const AlertContext = createContext<AlertContextType | undefined>(undefined);

export function AlertProvider({ children }: { children: React.ReactNode }) {
  const [alerts, setAlerts] = useState<Alert[]>([]);
  let numSeconds = 1.25;

  const removeAlert = useCallback((id: string) => {
    setAlerts(prev => 
      prev.map(alert => 
        alert.id === id ? { ...alert, isLeaving: true } : alert
      )
    );

    setTimeout(() => {
      setAlerts(prev => prev.filter(alert => alert.id !== id));
    }, 300);
  }, []);

  const showAlert = useCallback((type: AlertType, message: string) => {
    const id = Math.random().toString(36).substring(7);
    setAlerts(prev => [...prev, { id, type, message }]);

    setTimeout(() => {
      removeAlert(id);
    }, numSeconds * 1000);
  }, [removeAlert]);

  return (
    <AlertContext.Provider value={{ alerts, showAlert, removeAlert }}>
      {children}
    </AlertContext.Provider>
  );
}

export function useAlerts() {
  const context = useContext(AlertContext);
  if (context === undefined) {
    throw new Error('useAlerts must be used within an AlertProvider');
  }
  return context;
}

export function AlertContainer() {
  const { alerts, removeAlert } = useAlerts();

  if (alerts.length === 0) return null;

  return (
    <div className="fixed top-4 right-4 left-4 z-50 flex flex-col gap-2">
      {alerts.map(alert => (
        <div
          key={alert.id}
          className={`flex items-center justify-between p-4 rounded-lg shadow-lg 
            transition-all duration-300 ease-in-out
            ${alert.isLeaving ? 'opacity-0 transform -translate-y-2' : 'opacity-100'}
            ${
              alert.type === 'success' ? 'bg-green-50 text-green-900' :
              alert.type === 'error' ? 'bg-red-50 text-red-900' :
              'bg-blue-50 text-blue-900'
            }`}
        >
          <div className="flex items-center gap-3">
            {alert.type === 'success' ? (
              <CheckCircle className={`w-5 h-5 ${
                alert.type === 'success' ? 'text-green-500' :
                alert.type === 'error' ? 'text-red-500' :
                'text-blue-500'
              }`} />
            ) : alert.type === 'error' ? (
              <XCircle className="w-5 h-5 text-red-500" />
            ) : (
              <AlertCircle className="w-5 h-5 text-blue-500" />
            )}
            <p className="text-sm font-medium">{alert.message}</p>
          </div>
          <button
            onClick={() => removeAlert(alert.id)}
            className={`p-1 rounded-full hover:bg-opacity-10 ${
              alert.type === 'success' ? 'hover:bg-green-900' :
              alert.type === 'error' ? 'hover:bg-red-900' :
              'hover:bg-blue-900'
            }`}
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      ))}
    </div>
  );
}