EasyML::Engine.routes.draw do
  root to: "models#index"

  # Models
  resources :models, only: %i[index new edit], as: :easy_ml_models do
    get "new", on: :collection, as: "new"
  end

  # Datasources
  resources :datasources, only: %i[index new edit], as: :easy_ml_datasources

  # Datasets
  resources :datasets, only: %i[index new show], as: :easy_ml_datasets

  # Transformations
  resources :transformations, only: %i[index new edit], as: :easy_ml_transformations

  # Settings
  get "settings", to: "settings#show"
end
