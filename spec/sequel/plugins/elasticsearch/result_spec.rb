require 'json'
require 'sequel'
require 'elasticsearch'
require 'sequel/plugins/elasticsearch'

describe Sequel::Plugins::Elasticsearch::Result do
  def fixture(name)
    File.read("spec/support/#{name}")
  end

  let(:result) do
    {
      'took' => 234,
      'timed_out' => false,
      'hits' => {
        'hits' => [ 'one', 'two' ],
        'total' => 2
      }
    }
  end

  let(:scroll_result) { result.merge('_scroll_id' => '123scrollid') }

  context '.new' do
    let(:subject) do
      described_class.new(result)
    end

    it 'creates an enumerable' do
      expect(subject).to be_a Enumerable
    end

    it 'handles an empty result' do
      expect { described_class.new(nil) }.to_not raise_error
    end

    it 'sets the result total property' do
      expect(subject.total).to_not be nil
      expect(subject.total).to eq result['hits']['total']
    end

    it 'sets the result timed_out property' do
      expect(subject.timed_out).to_not be nil
      expect(subject.timed_out).to eq result['timed_out']
    end

    it 'sets the result took property' do
      expect(subject.took).to_not be nil
      expect(subject.took).to eq result['took']
    end

    it 'accesses the enumerable elements correctly' do
      expect(subject).to include 'one'
      expect(subject).to include 'two'
      expect(subject).to_not include 'three'
    end

    it 'reports the size of the hits array correctly' do
      expect(subject.count).to eq result['hits']['hits'].count
    end
  end

  context 'scrollable' do
    let(:subject) do
      described_class.new(scroll_result)
    end

    it 'sets the result scroll_id property' do
      expect(subject.scroll_id).to_not be nil
      expect(subject.scroll_id).to eq scroll_result['_scroll_id']
    end

    it 'iterates through the whole result set' do
      skip 'feature still pending'
      stub_request(:get, 'http://localhost:9200/_search?q=test&scroll=1m&size=2')
        .to_return(status: 200, body: fixture('scroll_one.json'), headers: { 'Content-Type' => 'application/json' })
      stub_request(:get, 'http://localhost:9200/_search/scroll')
        .to_return(status: 200, body: fixture('scroll_two.json'), headers: { 'Content-Type' => 'application/json' })

      client = Elasticsearch::Client.new
      result = described_class.new client.search(q: 'test', scroll: '1m', size: 2)
      expect(result.total).to eq 5
      expect(result.count).to eq 2
      expect(result.map { |e| e }.count).to eq 5
    end
  end
end
