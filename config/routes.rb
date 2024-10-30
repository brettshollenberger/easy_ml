EasyML::Engine.routes.draw do
  root to: "models#index"
  resources :models, only: %i[index show]
end
