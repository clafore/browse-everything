# frozen_string_literal: true
module BrowseEverything
  class Session
    attr_accessor :id, :provider_id, :host, :port, :authorization_ids
    include ActiveModel::Serialization

    # Define the ORM persister Class
    # @return [Class]
    def self.orm_class
      SessionModel
    end

    # Define the JSON-API persister Class
    # @return [Class]
    def self.serializer_class
      SessionSerializer
    end

    # For Session Objects to be serializable, they must have a zero-argument constructor
    # @param provider_id
    # @param authorization_ids
    # @param session
    # @param host
    # @param port
    # @return [Session]
    def self.build(id: nil, provider_id: nil, authorization_ids: [], host: nil, port: nil)
      browse_everything_session = Session.new
      browse_everything_session.id = id
      browse_everything_session.provider_id = provider_id
      browse_everything_session.authorization_ids = authorization_ids
      browse_everything_session.host = host
      browse_everything_session.port = port
      browse_everything_session
    end

    class << self
      # Query service methods
      #
      # @see ActiveRecord::Base.find_by
      # @return [Array<Session>]
      def where(**arguments)
        session_models = orm_class.where(**arguments)
        models = session_models
        models.map do |model|
          new_attributes = JSON.parse(model.authorization)
          build(**new_attributes.symbolize_keys)
        end
      end
      alias find_by where
    end

    # Generate the attributes used for serialization
    # @see ActiveModel::Serialization
    # @return [Hash]
    def attributes
      {
        'id' => id,
        'provider_id' => provider_id,
        'host' => host,
        'port' => port,
        'authorization_ids' => authorization_ids
      }
    end

    # Build the JSON-API serializer Object
    # @return [SessionSerializer]
    def serializer
      @serialize ||= self.class.serializer_class.new(self)
    end

    def id
      return if @orm.nil?
      @orm.id
    end
    delegate :save, :save!, :destroy, :destroy!, to: :orm # Persistence methods

    def authorizations
      values = authorization_ids.map do |authorization_id|
        # This needs to be restructured to something like
        # query_service.find_by(id: authorization_id) (to support Valkyrie)
        results = Authorization.find_by(id: authorization_id)
        results.first
      end

      values.compact
    end

    def auth_code
      return if authorizations.empty?

      # Retrieve the most recent authorization
      authorizations.last.code
    end

    def provider
      @provider ||= Provider.build(id: provider_id, auth_code: auth_code, host: host, port: port)
    end

    delegate :root_container, to: :provider
    delegate :authorization_url, to: :provider

    private

      # There should be a BrowseEverything.metadata_adapter layer here for
      # providing closer Valkyrie integration
      def orm
        return @orm unless @orm.nil?

        # This ensures that the ID is persisted
        json_attributes = JSON.generate(attributes)
        orm_model = self.class.orm_class.new(session: json_attributes)
        orm_model.save
        @orm = orm_model.reload
      end
  end
end
