EasyML::Engine.routes.draw do
  root to: "models#index"

  # Models
  resources :models, as: :easy_ml_models do
    member do
      post :train
    end
    get "new", on: :collection, as: "new"
  end

  # Datasources
  resources :datasources, as: :easy_ml_datasources do
    member do
      post :sync
    end
  end

  # Datasets
  resources :datasets, as: :easy_ml_datasets do
    member do
      post :refresh
    end
  end

  # Transformations
  resources :transformations, only: %i[index new edit], as: :easy_ml_transformations

  # Settings
  resources :settings, only: [:index] do
    patch :update, on: :collection
  end

  # Columns
  resources :columns, only: [:update], as: :easy_ml_columns
end
