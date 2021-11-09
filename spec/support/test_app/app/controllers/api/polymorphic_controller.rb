# frozen_string_literal: true

module Api
  class PolymorphicController < ApiController
    def show
      model_class = params[:class_name].safe_constantize
      scope = model_class.where(id: params[:id])

      if params.has_key?(:includes) &&
          # All this to access some params as a raw hash? Come on!
          includes = ActionController::Parameters.new(_: params.require(:includes)).permit!.to_h[:_]
        scope = scope.includes(*includes)
      end

      object = scope.first

      render json: object, include: "**"
    end

    def update
      model_class = params[:class_name].safe_constantize
      key = model_class.model_name.param_key
      object = model_class.where(id: params[:id]).first

      attributes = if params.has_key?(key)
        # All this to access some params as a raw hash? Come on!
        ActionController::Parameters.new(_: params.require(key)).permit!.to_h[:_]
      else
        {}
      end

      object.assign_attributes(attributes)
      object.save!

      render json: object, include: "**"
    end
  end
end
