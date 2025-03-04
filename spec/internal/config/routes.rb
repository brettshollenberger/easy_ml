# frozen_string_literal: true

Rails.application.routes.draw do
  mount EasyML::Engine, at: "easy_ml"
end
