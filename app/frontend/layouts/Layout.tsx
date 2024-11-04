import React, { useEffect } from "react";
import { Navigation } from "../components/Navigation";
import { AlertProvider, useAlerts } from '../components/AlertProvider';
import { usePage } from '@inertiajs/react';

interface PageProps {
  flash: Array<{
    type: 'success' | 'error' | 'info';
    message: string;
  }>;
}

function FlashMessageHandler({ children }: { children: React.ReactNode }) {
  const { showAlert } = useAlerts();
  const { flash } = usePage<PageProps>().props;

  useEffect(() => {
    if (flash) {
      flash.forEach(({ type, message }) => {
        showAlert(type, message);
      });
    }
  }, [flash, showAlert]);

  return <>{children}</>;
}

export default function Layout({ children }: { children: React.ReactNode }) {
  return (
    <AlertProvider>
      <FlashMessageHandler>
        <Navigation>
          {children}
        </Navigation>
      </FlashMessageHandler>
    </AlertProvider>
  );
}