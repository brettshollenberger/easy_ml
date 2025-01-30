import React, { useState, useMemo, useCallback, useEffect } from "react";
import {
  X,
  Settings2,
  AlertCircle,
  Target,
  EyeOff,
  Search,
  Wand2,
  Play,
  Loader2,
  Sparkles,
  Calendar,
} from "lucide-react";
import { PreprocessingConfig } from "./PreprocessingConfig";
import { ColumnList } from "./ColumnList";
import { ColumnFilters } from "./ColumnFilters";
import { AutosaveIndicator } from "./AutosaveIndicator";
import { SearchableSelect } from "../SearchableSelect";
import { useAutosave } from "../../hooks/useAutosave";
import { Dataset, Column, Feature } from "../../types/dataset";
import type { PreprocessingStep } from "../../types/dataset";
import { FeaturePicker } from "./FeaturePicker";
import { router } from "@inertiajs/react";

interface ColumnConfig {
  targetColumn?: string;
  dateColumn?: string;
}

interface ColumnConfigModalProps {
  isOpen: boolean;
  onClose: () => void;
  initialDataset: Dataset;
  onSave: (dataset: Dataset) => Promise<void>;
  constants: any;
}

export function ColumnConfigModal({
  isOpen,
  onClose,
  initialDataset,
  onSave,
  constants,
}: ColumnConfigModalProps) {
  const [dataset, setDataset] = useState<Dataset>(initialDataset);
  const [activeTab, setActiveTab] = useState<"columns" | "features">(
    "columns"
  );
  const [activeColumnSubTab, setActiveColumnSubTab] = useState<
    "target" | "date"
  >("target");
  const [isApplying, setIsApplying] = useState(false);
  const [config, setConfig] = useState<ColumnConfig>({
    targetColumn: dataset.target,
  });
  const [selectedColumn, setSelectedColumn] = useState<string | null>(null);
  const [searchQuery, setSearchQuery] = useState("");
  const [activeFilters, setActiveFilters] = useState<{
    view: "all" | "training" | "hidden" | "preprocessed" | "nulls";
    types: string[];
  }>({
    view: "all",
    types: [],
  });
  const [needsRefresh, setNeedsRefresh] = useState(
    initialDataset.needs_refresh || false
  );

  const handleSave = useCallback(
    async (data: Dataset) => {
      await onSave(data);
    },
    [onSave]
  );

  const { saving, saved, error } = useAutosave(dataset, handleSave, 2000);

  const colHasPreprocessingSteps = (col: Column) => {
    return (
      col.preprocessing_steps?.training != null &&
      col.preprocessing_steps?.training?.method !== "none"
    );
  };

  const filteredColumns = useMemo(() => {
    return dataset.columns.filter((column) => {
      const matchesSearch = column.name
        .toLowerCase()
        .includes(searchQuery.toLowerCase());
      const matchesType =
        activeFilters.types.length === 0 ||
        activeFilters.types.includes(column.datatype);

      const matchesView = (() => {
        switch (activeFilters.view) {
          case "training":
            return !column.hidden && !column.drop_if_null;
          case "hidden":
            return column.hidden;
          case "preprocessed":
            return colHasPreprocessingSteps(column);
          case "nulls":
            return (column.statistics?.processed?.null_count || 0) > 0;
          default:
            return true;
        }
      })();

      return matchesSearch && matchesType && matchesView;
    });
  }, [dataset.columns, searchQuery, activeFilters]);

  const columnStats = useMemo(
    () => ({
      total: dataset.columns.length,
      filtered: filteredColumns.length,
      training: dataset.columns.filter((c) => !c.hidden && !c.drop_if_null)
        .length,
      hidden: dataset.columns.filter((c) => c.hidden).length,
      withPreprocessing: dataset.columns.filter(colHasPreprocessingSteps)
        .length,
      withNulls: dataset.columns.filter(
        (c) => (c.statistics?.processed?.null_count || 0) > 0
      ).length,
    }),
    [dataset.columns, filteredColumns]
  );

  const columnTypes = useMemo(
    () => Array.from(new Set(dataset.columns.map((c) => c.datatype))),
    [dataset.columns]
  );

  const dateColumns = useMemo(() => {
    return dataset.columns.filter((column) => column.datatype === "datetime");
  }, [dataset.columns]);

  const handleColumnSelect = (columnName: string) => {
    setSelectedColumn(columnName);
  };

  const toggleHiddenColumn = (columnName: string) => {
    const updatedColumns = dataset.columns.map((c) => ({
      ...c,
      hidden: c.name === columnName ? !c.hidden : c.hidden,
    }));

    setDataset({
      ...dataset,
      columns: updatedColumns,
    });
    setNeedsRefresh(true);
  };

  const setTargetColumn = (columnName: string) => {
    const name = String(columnName);
    setConfig({ ...config, targetColumn: columnName });
    const updatedColumns = dataset.columns.map((c) => ({
      ...c,
      is_target: c.name === name,
    }));

    setDataset({
      ...dataset,
      columns: updatedColumns,
    });
    setNeedsRefresh(true);
  };

  const setDateColumn = (columnName: string) => {
    const name = String(columnName);
    setConfig((prev) => ({ ...prev, dateColumn: columnName }));
    const updatedColumns = dataset.columns.map((c) => ({
      ...c,
      is_date_column: c.name === name,
    }));

    setDataset({
      ...dataset,
      columns: updatedColumns,
    });
    setNeedsRefresh(true);
  };

  const setColumnType = (columnName: string, datatype: string) => {
    const updatedColumns = dataset.columns.map((c) => ({
      ...c,
      datatype: c.name === columnName ? datatype : c.datatype,
    }));

    setDataset({
      ...dataset,
      columns: updatedColumns,
    });
    setNeedsRefresh(true);
  };

  const handlePreprocessingUpdate = (
    columnName: string,
    training: PreprocessingStep,
    inference: PreprocessingStep | undefined,
    useDistinctInference: boolean
  ) => {
    const column = dataset.columns.find((c) => c.name === columnName);
    if (!column) return;

    const updatedColumns = dataset.columns.map((c) => {
      if (c.name !== columnName) return c;

      return {
        ...c,
        preprocessing_steps: {
          training,
          ...(useDistinctInference && inference ? { inference } : {}),
        },
      };
    });

    setDataset({
      ...dataset,
      columns: updatedColumns,
    });
    setNeedsRefresh(true);
  };

  const handleFeaturesChange = (newFeatures: Feature[]) => {
    const existingFeatures = dataset.features || [];

    const removedFeatures = existingFeatures
      .filter(
        (existing) => !newFeatures.find((t) => t.name === existing.name)
      )
      .map((feature) => ({ ...feature, _destroy: true }));

    const featuresWithDatasetId = [
      ...newFeatures,
      ...removedFeatures,
    ].map((feature, index) => ({
      ...feature,
      dataset_id: dataset.id,
      feature_position: index,
    }));

    setDataset((prevDataset) => ({
      ...prevDataset,
      features: featuresWithDatasetId,
    }));
    setNeedsRefresh(true);
  };

  const handleApplyChanges = async () => {
    setIsApplying(true);
    try {
      await onSave(dataset);
      router.post(
        `/easy_ml/datasets/${dataset.id}/refresh`,
        {},
        {
          onSuccess: () => {
            setIsApplying(false);
          },
          onError: () => {
            console.error("Error refreshing dataset");
            setIsApplying(false);
          },
        }
      );
    } catch (error) {
      console.error("Error refreshing dataset:", error);
      setIsApplying(false);
    }
  };

  if (!isOpen) return null;

  const selectedColumnData = selectedColumn
    ? dataset.columns.find((c) => c.name === selectedColumn)
    : null;

  return (
    <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
      <div className="bg-white rounded-lg w-full max-w-6xl max-h-[90vh] overflow-hidden flex flex-col">
        <div className="flex justify-between items-center p-4 border-b shrink-0">
          <h2 className="text-lg font-semibold">Column Configuration</h2>
          <div className="flex items-center gap-4">
            <div className="min-w-[0px]">
              <AutosaveIndicator saving={saving} saved={saved} error={error} />
            </div>
            <div className="relative">
              <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-gray-400" />
              <input
                type="text"
                placeholder="Search columns..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="pl-9 pr-4 py-2 w-64 border border-gray-300 rounded-md focus:ring-blue-500 focus:border-blue-500"
              />
            </div>
            <button
              onClick={onClose}
              className="text-gray-500 hover:text-gray-700"
            >
              <X className="w-5 h-5" />
            </button>
          </div>
        </div>

        <div className="flex border-b shrink-0">
          <button
            onClick={() => setActiveTab("columns")}
            className={`flex items-center gap-2 px-4 py-2 border-b-2 ${
              activeTab === "columns"
                ? "border-blue-500 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
            }`}
          >
            <Settings2 className="w-4 h-4" />
            Preprocessing
          </button>
          <button
            onClick={() => setActiveTab("features")}
            className={`flex items-center gap-2 px-4 py-2 border-b-2 ${
              activeTab === "features"
                ? "border-blue-500 text-blue-600"
                : "border-transparent text-gray-500 hover:text-gray-700"
            }`}
          >
            <Wand2 className="w-4 h-4" />
            Feature Engineering
          </button>

          {needsRefresh && (
            <div className="ml-auto px-4 flex items-center">
              <button
                onClick={handleApplyChanges}
                disabled={isApplying}
                className="group relative inline-flex items-center gap-2 px-6 py-2.5 bg-gradient-to-r from-blue-600 to-indigo-600 text-white text-sm font-medium rounded-md hover:from-blue-700 hover:to-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 transition-all duration-200 shadow-md hover:shadow-lg"
              >
                <div className="absolute inset-0 bg-white/10 rounded-md opacity-0 group-hover:opacity-100 transition-opacity duration-200" />
                {isApplying ? (
                  <>
                    <Loader2 className="w-4 h-4 animate-spin" />
                    Applying Preprocessing...
                  </>
                ) : (
                  <>
                    <Sparkles className="w-4 h-4" />
                    Apply Preprocessing
                  </>
                )}
              </button>
            </div>
          )}
        </div>

        {activeTab === "columns" ? (
          <React.Fragment>
            <div className="grid grid-cols-7 flex-1 min-h-0">
              <div className="col-span-3 border-r overflow-hidden flex flex-col">
                <div className="p-4 border-b">
                  <div className="flex border-b">
                    <button
                      onClick={() => setActiveColumnSubTab("target")}
                      className={`flex items-center gap-2 px-4 py-2 border-b-2 ${
                        activeColumnSubTab === "target"
                          ? "border-blue-500 text-blue-600"
                          : "border-transparent text-gray-500 hover:text-gray-700"
                      }`}
                    >
                      <Target className="w-4 h-4" />
                      Target Column
                    </button>
                    <button
                      onClick={() => setActiveColumnSubTab("date")}
                      className={`flex items-center gap-2 px-4 py-2 border-b-2 ${
                        activeColumnSubTab === "date"
                          ? "border-blue-500 text-blue-600"
                          : "border-transparent text-gray-500 hover:text-gray-700"
                      }`}
                    >
                      <Calendar className="w-4 h-4" />
                      Date Column
                    </button>
                  </div>

                  {activeColumnSubTab === "target" ? (
                    <div className="mt-4">
                      <SearchableSelect
                        value={config.targetColumn || ""}
                        onChange={(value) => setTargetColumn(value)}
                        options={dataset.columns.map((column) => ({
                          value: column.name,
                          label: column.name,
                        }))}
                        placeholder="Select target column..."
                      />
                    </div>
                  ) : (
                    <div className="mt-4">
                      {dateColumns.length > 0 ? (
                        <SearchableSelect
                          value={config.dateColumn || ""}
                          onChange={(value) => setDateColumn(value)}
                          options={dateColumns.map((column) => ({
                            value: column.name,
                            label: column.name,
                          }))}
                          placeholder="Select date column..."
                        />
                      ) : (
                        <div className="text-center py-4 text-gray-500 bg-gray-50 rounded-md">
                          No date columns available
                        </div>
                      )}
                    </div>
                  )}
                </div>
                <div className="shrink-0">
                  <ColumnFilters
                    types={columnTypes}
                    activeFilters={activeFilters}
                    onFilterChange={setActiveFilters}
                    columnStats={columnStats}
                    columns={dataset.columns}
                    colHasPreprocessingSteps={colHasPreprocessingSteps}
                  />
                </div>

                <div className="flex-1 overflow-y-auto p-4 min-h-0">
                  <ColumnList
                    columns={filteredColumns}
                    selectedColumn={selectedColumn}
                    onColumnSelect={handleColumnSelect}
                    onToggleHidden={toggleHiddenColumn}
                  />
                </div>
              </div>

              <div className="col-span-4 overflow-y-auto p-4">
                {selectedColumnData ? (
                  <PreprocessingConfig
                    column={selectedColumnData}
                    dataset={dataset}
                    setColumnType={setColumnType}
                    setDataset={setDataset}
                    constants={constants}
                    onUpdate={(training, inference, useDistinctInference) =>
                      handlePreprocessingUpdate(
                        selectedColumnData.name,
                        training,
                        inference,
                        useDistinctInference
                      )
                    }
                  />
                ) : (
                  <div className="h-full flex items-center justify-center text-gray-500">
                    Select a column to configure preprocessing
                  </div>
                )}
              </div>
            </div>
            <div className="border-t p-4 flex justify-between items-center shrink-0">
              <div className="text-sm text-gray-600">
                {dataset.columns.filter((c) => !c.hidden).length} columns
                selected for training
              </div>
              <div className="flex gap-3">
                <button
                  onClick={onClose}
                  className="px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700"
                >
                  Close
                </button>
              </div>
            </div>
          </React.Fragment>
        ) : (
          <div className="p-6 h-[calc(90vh-8rem)] overflow-y-auto">
            <FeaturePicker
              options={constants.feature_options}
              initialFeatures={dataset.features}
              onFeaturesChange={handleFeaturesChange}
            />
          </div>
        )}
      </div>
    </div>
  );
}
