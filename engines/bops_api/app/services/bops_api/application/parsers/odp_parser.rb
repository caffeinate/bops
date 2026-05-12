# frozen_string_literal: true

module BopsApi
  module Application
    module Parsers
      class OdpParser < BaseParser
        APPLICATION_TYPE_CODES = {
          "hh" => "pp.full.householder"
        }.freeze

        SUPPLEMENTARY_KEYS = %w[
          access-rights-of-way
          bng
          checklist
          conflict-of-interest
          declaration
          materials
          ownership-certs
          parking
          pre-app-advice
          proposal-details
          site-visit
          trees-hedges
        ].freeze

        def parse
          {
            alternative_reference: application_section["reference"],
            received_at: application_section["submission-date"],
            description: proposal_details_section["description"],
            address_1: site_location["address-text"],
            postcode: site_location["postcode"],
            applicant_first_name: applicant_person["first-name"],
            applicant_last_name: applicant_person["last-name"],
            applicant_email: applicant_contact_details["email"],
            applicant_phone: primary_phone(applicant_contact_details["phone-numbers"]),
            applicant_address_1: applicant_person["address-text"],
            agent_first_name: agent_person["first-name"],
            agent_last_name: agent_person["last-name"],
            agent_email: agent_contact_details["email"],
            agent_phone: primary_phone(agent_contact_details["phone-numbers"]),
            agent_address_1: agent_person["address-text"],
            application_type: application_type,
            proposal_details: supplementary_details
          }.then { |h| h.respond_to?(:compact_blank) ? h.compact_blank : h.compact }
        end

        private

        def application_section
          params["application"] || {}
        end

        def site_location
          params.dig("site-details", "site-locations", 0) || {}
        end

        def proposal_details_section
          params["proposal-details"] || {}
        end

        def applicant_person
          params.dig("applicant-details", "applicants", 0, "person") || {}
        end

        def applicant_contact_details
          params.dig("applicant-contact", "contact-details") || {}
        end

        def agent_person
          params.dig("agent-details", "agent", "person") || {}
        end

        def agent_contact_details
          params.dig("agent-contact", "contact-details") || {}
        end

        def primary_phone(phone_numbers)
          return if phone_numbers.blank?

          entry = phone_numbers.find { |p| p["contact-priority"] == "primary" } || phone_numbers.first
          entry["number"]
        end

        def application_type
          odp_code = application_section["application-types"]&.first
          return unless odp_code

          code = APPLICATION_TYPE_CODES.fetch(odp_code, odp_code)
          config = ApplicationType::Config.find_by!(code: code)
          retried = false

          begin
            local_authority.application_types.find_or_create_by!(
              config_id: config.id,
              code: config.code,
              name: config.name,
              suffix: config.suffix
            )
          rescue ActiveRecord::RecordNotUnique
            raise "Unable to find or create application type" if retried
            retried = true
            retry
          end
        end

        def supplementary_details
          SUPPLEMENTARY_KEYS.each_with_object({}) { |key, h| h[key] = params[key] if params.key?(key) }.presence
        end
      end
    end
  end
end
