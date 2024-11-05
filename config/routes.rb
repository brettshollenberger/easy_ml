EasyML::Engine.routes.draw do
  root to: "models#index"

  # Models
  resources :models, only: %i[index new edit], as: :easy_ml_models do
    get "new", on: :collection, as: "new"
  end

  # Datasources
  resources :datasources, as: :easy_ml_datasources do
    member do
      post :sync
    end
  end

  # Datasets
  resources :datasets, only: %i[index new show], as: :easy_ml_datasets do
    collection do
      get :columns
    end
  end

  # Transformations
  resources :transformations, only: %i[index new edit], as: :easy_ml_transformations

  # Settings
  resources :settings, only: [:index] do
    patch :update, on: :collection
  end
end
