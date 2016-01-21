# -*- encoding : utf-8 -*-
require 'net/http'
require 'multi_xml'
require 'uri'

module Rubykassa
  class InvalidResponseError < StandardError; end

  class XmlInterface
    BASE_URL = "https://auth.robokassa.ru/Merchant/WebService/Service.asmx/".freeze

    attr_accessor :invoice_id, :total, :language

    def initialize &block
      yield self if block_given?
    end

    def get_currencies
      request(BASE_URL + transform_method_name(__method__), Hash["MerchantLogin", Rubykassa.login, "Language", @language, "isTest", test_mode_param])
    end

    def get_payment_methods
      request(BASE_URL + transform_method_name(__method__), Hash["MerchantLogin", Rubykassa.login, "Language", @language, "isTest", test_mode_param])
    end

    def get_rates
      request(BASE_URL + transform_method_name(__method__), Hash["MerchantLogin", Rubykassa.login, "IncCurrLabel", "", "OutSum", @total.to_s, "Language", @language, "isTest", test_mode_param])
    end

    def op_state(additional_params = {})
      params = Hash["MerchantLogin", Rubykassa.login, "InvoiceID", @invoice_id.to_s, "Signature", generate_signature, "isTest", test_mode_param]
      params.merge!(additional_params) if test_mode?

      request(BASE_URL + transform_method_name(__method__), params)
    end

    private

      def test_mode?
        Rubykassa.mode == :test
      end

      def test_mode_param
        test_mode? ? 1 : 0
      end

      def generate_signature
        Digest::MD5.hexdigest("#{Rubykassa.login}:#{@invoice_id}:#{Rubykassa.second_password}")
      end

      def transform_method_name(method_name)
        method_name.to_s.split('_').map(&:capitalize).join(' ').gsub(/\s/, "")
      end

      def request(url, params)
        if Rubykassa.xml_http_method == :get
          converted_params = "?" + params.map {|key, value| "#{key}=#{value}" }.join("&")
          response = Net::HTTP.get_response(URI(url) + converted_params)
        else
          response = Net::HTTP.post_form(URI(url), params)
        end

        raise InvalidResponseError, "Invalid response from the service" unless response.code == "200"

        MultiXml.parse(response.body)
      end
  end
end
