import React, { useState, useRef, useEffect } from 'react';
import { X } from 'lucide-react';

interface PopoverProps {
  trigger: React.ReactElement;
  children: React.ReactNode;
  className?: string;
}

export function Popover({ trigger, children, className = '' }: PopoverProps) {
  const [isOpen, setIsOpen] = useState(false);
  const popoverRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        popoverRef.current &&
        !popoverRef.current.contains(event.target as Node) &&
        !triggerRef.current?.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    };

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  return (
    <div className="relative">
      <div ref={triggerRef} onClick={() => setIsOpen(!isOpen)}>
        {trigger}
      </div>
      
      {isOpen && (
        <div
          ref={popoverRef}
          className={`absolute z-50 right-0 mt-2 bg-white rounded-lg shadow-lg border border-gray-200 ${className}`}
        >
          <div className="flex justify-between items-center p-3 border-b border-gray-200">
            <h3 className="font-medium">Transform Configuration</h3>
            <button
              onClick={() => setIsOpen(false)}
              className="text-gray-400 hover:text-gray-600"
            >
              <X className="w-4 h-4" />
            </button>
          </div>
          <div className="p-4">
            {children}
          </div>
        </div>
      )}
    </div>
  );
} 