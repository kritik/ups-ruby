require 'spec_helper'
require 'support/shipping_options'

describe UPS::Connection do
  include ShippingOptions

  before do
    Excon.defaults[:mock] = true
  end

  after do
    Excon.stubs.clear
  end

  let(:stub_path) { File.expand_path("../../../stubs", __FILE__) }
  let(:server) { UPS::Connection.new(test_mode: true) }
  let(:supplied_package) { package }

  describe 'if requesting rates' do
    subject do
      server.rates do |rate_builder|
        rate_builder.add_access_request ENV['UPS_LICENSE_NUMBER'], ENV['UPS_USER_ID'], ENV['UPS_PASSWORD']
        rate_builder.add_shipper shipper
        rate_builder.add_ship_from shipper
        rate_builder.add_ship_to ship_to
        rate_builder.add_package supplied_package
      end
    end

    describe 'successful rates response' do
      before do
        Excon.stub(method: :post) do |params|
          case params[:path]
          when UPS::Connection::RATE_PATH
            { body: File.read("#{stub_path}/rates_success.xml"), status: 200 }
          end
        end
      end

      it 'returns standard rates' do
        expect(subject.rated_shipments).wont_be_empty
        expect(subject.rated_shipments).must_equal [
          {
            :service_code=>"11",
            :service_name=>"UPS Standard",
            :warnings=>[
              "Your invoice may vary from the displayed reference rates",
              "Ship To Address Classification is changed from Commercial to Residential"
            ],
            :total=>"25.03"
          },
          {
            :service_code=>"65",
            :service_name=>"Express Saver",
            :warnings=>["Your invoice may vary from the displayed reference rates"],
            :total=>"45.82"
          },
          {
            :service_code=>"54",
            :service_name=>"Express Plus",
            :warnings=>["Your invoice may vary from the displayed reference rates"],
            :total=>"82.08"
          },
          {
            :service_code=>"07",
            :service_name=>"Express",
            :warnings=>["Your invoice may vary from the displayed reference rates"],
            :total=>"47.77"
          }
        ]
      end

      describe 'when API responds with a single rate' do
        before do
          Excon.stub(method: :post) do |params|
            case params[:path]
            when UPS::Connection::RATE_PATH
              { body: File.read("#{stub_path}/rates_success_single_rate.xml"), status: 200 }
            end
          end
        end

        it 'returns rates' do
          expect(subject.rated_shipments).wont_be_empty
          expect(subject.rated_shipments).must_equal [
            {
              :service_code=>"11",
              :service_name=>"UPS Standard",
              :warnings=>[
                "Your invoice may vary from the displayed reference rates",
                "Ship To Address Classification is changed from Commercial to Residential"
              ],
              :total=>"25.03"
            }
          ]
        end
      end
    end

    describe 'when ups packaging type is specified' do
      let(:supplied_package) { package_with_carrier_packaging }

      before do
        Excon.stub(method: :post) do |params|
          case params[:path]
          when UPS::Connection::RATE_PATH
            { body: File.read("#{stub_path}/rates_success_with_packaging_type.xml"), status: 200 }
          end
        end
      end

      it 'returns rates' do
        expect(subject.rated_shipments).wont_be_empty
          expect(subject.rated_shipments).must_equal [
            {
              service_code: '07',
              service_name: 'Express',
              warnings: [
                ' The weight exceeds the limit for the UPS Letter/Envelope rate and will be rated using the weight. ',
                ' Your invoice may vary from the displayed reference rates '
              ],
              total: '171.04'
            },
            {
              service_code: '65',
              service_name: 'Express Saver',
              warnings: [
                ' The weight exceeds the limit for the UPS Letter/Envelope rate and will be rated using the weight. ',
                ' Your invoice may vary from the displayed reference rates '
              ],
              total: '160.76'
            },
            {
              service_code: '54',
              service_name: 'Express Plus',
              warnings: [
                ' The weight exceeds the limit for the UPS Letter/Envelope rate and will be rated using the weight. ',
                ' Your invoice may vary from the displayed reference rates '
              ],
              total: '226.89'
            }
          ]
      end
    end

    describe 'when both ups packaging type and dimensions are specified' do
      let(:supplied_package) { package_with_carrier_packaging }

      before do
        Excon.stub(method: :post) do |params|
          case params[:path]
          when UPS::Connection::RATE_PATH
            { body: File.read("#{stub_path}/rates_success_with_packaging_type_and_dimensions.xml"), status: 200 }
          end
        end
      end

      it 'returns rates' do
        expect(subject.rated_shipments).wont_be_empty
          expect(subject.rated_shipments).must_equal [
            {
              service_code: '07',
              service_name: 'Express',
              warnings: [
                ' The weight exceeds the limit for the UPS Letter/Envelope rate and will be rated using the weight. ',
                ' Your invoice may vary from the displayed reference rates '
              ],
              total: '170.27'
            },
            {
              service_code: '65',
              service_name: 'Express Saver',
              warnings: [
                ' The weight exceeds the limit for the UPS Letter/Envelope rate and will be rated using the weight. ',
                ' Your invoice may vary from the displayed reference rates '
              ],
              total: '160.76'
            },
            {
              service_code: '54',
              service_name: 'Express Plus',
              warnings: [
                ' The weight exceeds the limit for the UPS Letter/Envelope rate and will be rated using the weight. ',
                ' Your invoice may vary from the displayed reference rates '
              ],
              total: '226.89'
            }
          ]
      end
    end

    describe 'error rates response' do
      describe 'with single error response' do
        before do
          Excon.stub(method: :post) do |params|
            case params[:path]
            when UPS::Connection::RATE_PATH
              { body: File.read("#{stub_path}/rates_error_single_error.xml"), status: 200 }
            end
          end
        end

        it 'returns error' do
          subject.wont_equal false
          subject.success?.must_equal false
          subject.error_description.must_equal "Missing or invalid shipper number."
        end
      end

      describe 'with multi error response' do
        before do
          Excon.stub(method: :post) do |params|
            case params[:path]
            when UPS::Connection::RATE_PATH
              { body: File.read("#{stub_path}/rates_error_multi_error.xml"), status: 200 }
            end
          end
        end

        it 'returns error' do
          subject.wont_equal false
          subject.success?.must_equal false
          subject.error_description.must_equal "Packages must weigh more than zero kg."
        end
      end
    end
  end
end
