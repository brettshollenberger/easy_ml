import React, { useState, useRef, useEffect, forwardRef } from 'react';
import { Search, Check } from 'lucide-react';
import { createPortal } from 'react-dom';

interface Option {
  value: string | number;
  label: string;
  description?: string;
  metadata?: Record<string, any>;
}

interface SearchableSelectProps {
  options: Option[];
  value: Option['value'] | null;
  onChange: (value: Option['value']) => void;
  placeholder?: string;
  renderOption?: (option: Option) => React.ReactNode;
}

export const SearchableSelect = forwardRef<HTMLButtonElement, SearchableSelectProps>(
  ({ options, value, onChange, placeholder = 'Search...', renderOption }, ref) => {
    const [isOpen, setIsOpen] = useState(false);
    const [searchQuery, setSearchQuery] = useState('');
    const [dropdownPosition, setDropdownPosition] = useState({ top: 0, left: 0, width: 0 });
    const containerRef = useRef<HTMLDivElement>(null);
    const inputRef = useRef<HTMLInputElement>(null);

    const selectedOption = options.find(opt => opt.value === value);

    const filteredOptions = options.filter(option =>
      option.label.toLowerCase().includes(searchQuery.toLowerCase()) ||
      option.description?.toLowerCase().includes(searchQuery.toLowerCase())
    );

    useEffect(() => {
      function handleClickOutside(event: MouseEvent) {
        if (containerRef.current && !containerRef.current.contains(event.target as Node)) {
          setIsOpen(false);
        }
      }

      document.addEventListener('mousedown', handleClickOutside);
      return () => document.removeEventListener('mousedown', handleClickOutside);
    }, []);

    useEffect(() => {
      if (isOpen && inputRef.current) {
        inputRef.current.focus();
      }
    }, [isOpen]);

    useEffect(() => {
      if (isOpen && containerRef.current) {
        const rect = containerRef.current.getBoundingClientRect();
        setDropdownPosition({
          top: rect.bottom + window.scrollY,
          left: rect.left + window.scrollX,
          width: rect.width
        });
      }
    }, [isOpen]);

    const dropdown = isOpen ? (
      createPortal(
        <div 
          className="fixed bg-white shadow-lg rounded-md overflow-hidden border border-gray-200"
          style={{
            top: dropdownPosition.top,
            left: dropdownPosition.left,
            width: dropdownPosition.width,
            zIndex: 9999
          }}
        >
          <div className="p-2 border-b">
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                ref={inputRef}
                type="text"
                className="w-full pl-9 pr-4 py-2 border border-gray-300 rounded-md focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
                placeholder="Search..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                onClick={(e) => e.stopPropagation()}
              />
            </div>
          </div>

          <div className="max-h-60 overflow-y-auto">
            {filteredOptions.length === 0 ? (
              <div className="text-center py-4 text-sm text-gray-500">
                No results found
              </div>
            ) : (
              <ul className="py-1">
                {filteredOptions.map((option) => (
                  <li key={option.value}>
                    {renderOption ? (
                      <button
                        type="button"
                        className="w-full text-left"
                        onClick={() => {
                          onChange(option.value);
                          setIsOpen(false);
                          setSearchQuery('');
                        }}
                      >
                        {renderOption(option)}
                      </button>
                    ) : (
                      <button
                        type="button"
                        className={`w-full text-left px-4 py-2 hover:bg-gray-100 ${
                          option.value === value ? 'bg-blue-50' : ''
                        }`}
                        onClick={() => {
                          onChange(option.value);
                          setIsOpen(false);
                          setSearchQuery('');
                        }}
                      >
                        <div className="flex items-center justify-between">
                          <span className="block font-medium">
                            {option.label}
                          </span>
                          {option.value === value && (
                            <Check className="w-4 h-4 text-blue-600" />
                          )}
                        </div>
                        {option.description && (
                          <span className="block text-sm text-gray-500">
                            {option.description}
                          </span>
                        )}
                      </button>
                    )}
                  </li>
                ))}
              </ul>
            )}
          </div>
        </div>,
        document.body
      )
    ) : null;

    return (
      <div className="relative" ref={containerRef}>
        <button
          type="button"
          onClick={() => setIsOpen(!isOpen)}
          className="w-full bg-white relative border border-gray-300 rounded-md shadow-sm pl-3 pr-10 py-2 text-left cursor-pointer focus:outline-none focus:ring-1 focus:ring-blue-500 focus:border-blue-500"
          ref={ref}
        >
          {selectedOption ? (
            <span className="block truncate">{selectedOption.label}</span>
          ) : (
            <span className="block truncate text-gray-500">{placeholder}</span>
          )}
        </button>
        {dropdown}
      </div>
    );
  }
);

SearchableSelect.displayName = 'SearchableSelect';