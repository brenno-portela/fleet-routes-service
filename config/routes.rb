# frozen_string_literal: true

Rails.application.routes.draw do
  namespace :api do
    namespace :v1 do
      resources :routes, only: %i[index show update destroy] do
        collection do
          get :report, to: 'route_reports#show'
          get :export, to: 'route_reports#export'
        end
      end
    end
  end
end
