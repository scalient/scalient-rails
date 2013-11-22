# -*- coding: utf-8 -*-
#
# Copyright 2013 Scalient LLC
# All rights reserved.

class Scalient::Rails::SessionsController < Devise::SessionsController
  skip_before_filter :verify_authenticity_token, only: [:create]

  def create
    resource = Scalient::Rails::User.find_for_database_authentication(email: params["session"]["email"])

    if !resource.nil? && resource.valid_password?(params["session"]["password"])
      sign_in(:user, resource)
      render json: {"session" => {"id" => 0, "csrf_token" => form_authenticity_token}}
      return
    end

    login_failed
  end

  def destroy
    sign_out
    render json: {}
  end

  protected

  def login_failed
    render json: {error: "Login failed."}, status: 401
  end
end
