module Agents
  class AlimconfianceAgent < Agent
    include FormConfigurable

    can_dry_run!
    no_bulk_receive!
    default_schedule 'every_1h'

    description do
      <<-MD
      The Alimconfiance Agent checks results of official food safety controls carried out since March 1, 2017.

      `debug` is used to verbose mode.

      `zip_code` is needed to limit the research.

      `number_of_result` is for limiting result output.

      `changes_only` is only used to emit event about a currency's change.

      `expected_receive_period_in_days` is used to determine if the Agent is working. Set it to the maximum number of days
      that you anticipate passing without this Agent receiving an incoming Event.
      MD
    end

    event_description <<-MD
      Events look like this:

          {
            "app_libelle_etablissement": "AU PETIT BRIERES (NICOLAS VINCENT)",
            "siret": "83492327800016",
            "adresse_2_ua": "2 RUE DU PETIT BRIERES",
            "code_postal": "91150",
            "libelle_commune": "BRIERES LES SCELLES",
            "numero_inspection": "16616330",
            "date_inspection": "2022-10-07T00:00:00+00:00",
            "app_libelle_activite_etablissement": [
              "_"
            ],
            "synthese_eval_sanit": "Satisfaisant",
            "agrement": null,
            "geores": {
              "lon": 2.170879,
              "lat": 48.451185
            },
            "filtre": null,
            "ods_type_activite": "Autres"
          }
    MD

    def default_options
      {
        'debug' => 'false',
        'zip_code' => '',
        'expected_receive_period_in_days' => '2',
        'number_of_result' => '10',
        'changes_only' => 'true'
      }
    end

    form_configurable :expected_receive_period_in_days, type: :string
    form_configurable :number_of_result, type: :number
    form_configurable :zip_code, type: :number
    form_configurable :changes_only, type: :boolean
    form_configurable :debug, type: :boolean

    def validate_options
      if options.has_key?('changes_only') && boolify(options['changes_only']).nil?
        errors.add(:base, "if provided, changes_only must be true or false")
      end

      if options.has_key?('debug') && boolify(options['debug']).nil?
        errors.add(:base, "if provided, debug must be true or false")
      end

      unless options['expected_receive_period_in_days'].present? && options['expected_receive_period_in_days'].to_i > 0
        errors.add(:base, "Please provide 'expected_receive_period_in_days' to indicate how many days can pass before this Agent is considered to be not working")
      end

      unless options['zip_code'].present? && options['zip_code'].to_i > 0
        errors.add(:base, "Please provide 'zip_code'")
      end

      unless options['number_of_result'].present? && options['number_of_result'].to_i > 0
        errors.add(:base, "Please provide 'number_of_result' to limit the result's number")
      end
    end

    def working?
      event_created_within?(options['expected_receive_period_in_days']) && !recent_error_logs?
    end

    def check
      fetch
    end

    private

    def log_curl_output(code,body)

      log "request status : #{code}"

      if interpolated['debug'] == 'true'
        log "body"
        log body
      end

    end

    def fetch

      uri = URI.parse("https://dgal.opendatasoft.com/api/explore/v2.1/catalog/datasets/export_alimconfiance/records?where=code_postal%3D#{interpolated['zip_code']}&limit=#{interpolated['number_of_result']}")
      response = Net::HTTP.get_response(uri)

      log_curl_output(response.code,response.body)

      payload = JSON.parse(response.body)

      if interpolated['changes_only'] == 'true'
        if payload != memory['last_status']
          if "#{memory['last_status']}" == ''
            payload['results'].each do |result|
                create_event payload: result
            end
          else
            log "before"
            last_status = memory['last_status']
            log "after"
            payload['results'].each do |result|
              found = false
              if interpolated['debug'] == 'true'
                log "result"
                log result
              end
              last_status['results'].each do |resultbis|
                if result == resultbis
                  found = true
                end
                if interpolated['debug'] == 'true'
                  log "resultbis"
                  log resultbis
                  log "found is #{found}!"
                end
              end
              if found == false
                if interpolated['debug'] == 'true'
                  log "found is #{found}! so event created"
                  log result
                end
                create_event payload: result
              end
            end
          end
          memory['last_status'] = payload
        end
      else
        create_event payload: payload
        if payload != memory['last_status']
          memory['last_status'] = payload
        end
      end
    end
  end
end
