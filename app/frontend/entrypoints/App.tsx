import React from 'react';
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Navigation } from './components/Navigation';
import { ModelsPage } from './pages/ModelsPage';
import { NewModelPage } from './pages/NewModelPage';
import { EditModelPage } from './pages/EditModelPage';
import { DatasourcesPage } from './pages/DatasourcesPage';
import { NewDatasourcePage } from './pages/NewDatasourcePage';
import { EditDatasourcePage } from './pages/EditDatasourcePage';
import { DatasetsPage } from './pages/DatasetsPage';
import { NewDatasetPage } from './pages/NewDatasetPage';
import { DatasetDetailsPage } from './pages/DatasetDetailsPage';
import { SettingsPage } from './pages/SettingsPage';
import { TransformationsPage } from './pages/TransformationsPage';
import { NewTransformationPage } from './pages/NewTransformationPage';
import { EditTransformationPage } from './pages/EditTransformationPage';

export default function App() {
  return (
    <BrowserRouter>
      <Navigation>
        <Routes>
          <Route path="/" element={<ModelsPage />} />
          <Route path="/models/new" element={<NewModelPage />} />
          <Route path="/models/:id/edit" element={<EditModelPage />} />
          <Route path="/datasources" element={<DatasourcesPage />} />
          <Route path="/datasources/new" element={<NewDatasourcePage />} />
          <Route path="/datasources/:id/edit" element={<EditDatasourcePage />} />
          <Route path="/datasets" element={<DatasetsPage />} />
          <Route path="/datasets/new" element={<NewDatasetPage />} />
          <Route path="/datasets/:id" element={<DatasetDetailsPage />} />
          <Route path="/transformations" element={<TransformationsPage />} />
          <Route path="/transformations/new" element={<NewTransformationPage />} />
          <Route path="/transformations/:id/edit" element={<EditTransformationPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Routes>
      </Navigation>
    </BrowserRouter>
  );
}