# frozen_string_literal: true

module BopsApi
  module V2
    class OdpPlanningApplicationsController < AuthenticatedController
      def create
        @planning_application = creation_service.call!

        respond_to do |format|
          format.json
        end
      end

      private

      def required_api_key_scope = "planning_application"

      def send_email
        query_parameters[:send_email] == "true"
      end

      def creation_service
        @creation_service ||= Application::OdpCreationService.new(
          local_authority: current_local_authority,
          user: current_api_user,
          params: request_parameters,
          email_sending_permitted: send_email
        )
      end
    end
  end
end
