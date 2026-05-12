# frozen_string_literal: true

module BopsApi
  module Application
    class OdpCreationService
      def initialize(local_authority:, user:, params:, email_sending_permitted: false)
        @local_authority = local_authority
        @user = user
        @params = params
        @email_sending_permitted = email_sending_permitted
      end

      def call!
        save!(build_planning_application)
      end

      private

      attr_reader :local_authority, :user, :params, :email_sending_permitted

      def build_planning_application
        case_record = local_authority.case_records.new

        local_authority.planning_applications.new(planning_application_params).tap do |pa|
          pa.api_user_id = user.id
          pa.case_record = case_record
        end
      end

      def planning_application_params
        {}.tap do |pa_params|
          pa_params.merge!(Parsers::OdpParser.new(params, local_authority:).parse)
          pa_params.merge!(planx_planning_data_attributes: {params_v2: params})
        end
      end

      def save!(planning_application)
        PlanningApplication.transaction do
          planning_application.save!
          planning_application.mark_accepted!
        end

        planning_application.send_receipt_notice_mail if email_sending_permitted

        planning_application
      end
    end
  end
end
