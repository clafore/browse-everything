# frozen_string_literal: true

module BrowseEverything
  class ProvidersController < ActionController::Base
    skip_before_action :verify_authenticity_token

    def show
      @provider = Provider.build(**provider_attributes)
      @serializer = ProviderSerializer.new(@provider)
      respond_to do |format|
        format.json { render json: @serializer.serialized_json }
      end
    end

    def build_json_web_token(authorization)
      payload = {
        data: authorization.serializable_hash
      }

      token = JWT.encode(payload, nil, 'none')

      {
        token: token
      }
    end

    # This creates a new authorization, persists the authorization, uses this to
    # generate a new JSON Web Token
    def authorize
      @authorization = Authorization.build(**authorization_attributes)
      @authorization.save

      # Construct and return the JWT
      @json_web_token = build_json_web_token(@authorization)

      respond_to do |format|
        format.json { render json: @json_web_token }
        # This needs to be updated
        # Here the API response should redirect to the root path for the
        # application with the JWT stored in the session
        format.html { render json: @json_web_token }
      end
    end

    private

      def provider_params
        params.permit(:id)
      end

      def provider_attributes
        default_values = { host: request.host, port: request.port }
        values = default_values.merge(provider_params)
        values.to_h.symbolize_keys
      end

      def authorization_params
        params.permit(:code)
      end

      def authorization_attributes
        values = authorization_params
        values.to_h.symbolize_keys
      end
  end
end