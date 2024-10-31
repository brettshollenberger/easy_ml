EasyML::Engine.routes.draw do
  root to: "models#index"

  # Models
  resources :models, only: %i[index new edit]

  # Datasources
  resources :datasources, only: %i[index new edit]

  # Datasets
  resources :datasets, only: %i[index new show]

  # Transformations
  resources :transformations, only: %i[index new edit]

  # Settings
  get "settings", to: "settings#show"
end
