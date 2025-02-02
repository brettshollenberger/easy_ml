require "zhong/web"
require "resque/server"

EasyML::Engine.routes.draw do
  root to: "models#index"
  get "healthcheck", to: "health#up"

  mount Zhong::Web, at: "/zhong"
  mount Resque::Server.new, at: "/resque"

  # Predictions API
  resources :predictions, only: [:create]

  # API Documentation
  get "api", to: "apis#show"

  resources :models, as: :easy_ml_models do
    member do
      post :train
      get :retraining_runs, to: "retraining_runs#index"
    end
    resources :deploys, only: [:create]
    get "new", on: :collection, as: "new"
  end

  resources :retraining_runs, only: [:show]

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
