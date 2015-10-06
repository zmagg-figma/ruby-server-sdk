require 'spec_helper'

describe LaunchDarkly::LDClient do
  subject { LaunchDarkly::LDClient }
  let(:client) do
    expect_any_instance_of(LaunchDarkly::LDClient).to receive :create_worker
    subject.new('api_key')
  end

  describe '#flush' do
    it 'will flush and post all events' do
      client.instance_variable_get(:@queue).push 'asdf'
      client.instance_variable_get(:@queue).push 'asdf'
      result = double('result', status: 200)
      expect(client.instance_variable_get(:@client)).to receive(:post).and_return result
      client.flush
      expect(client.instance_variable_get(:@queue).length).to eq 0
    end
    it 'will work with unexpected post results' do
      client.instance_variable_get(:@queue).push 'asdf'
      client.instance_variable_get(:@queue).push 'asdf'
      result = double('result', status: 500)
      expect(client.instance_variable_get(:@client)).to receive(:post).and_return result
      expect(client.instance_variable_get(:@config).logger).to receive :error
      client.flush
      expect(client.instance_variable_get(:@queue).length).to eq 0
    end
    it 'will not do anything if there are no events' do
      expect(client.instance_variable_get(:@client)).to_not receive(:post)
      expect(client.instance_variable_get(:@config).logger).to_not receive :error
      client.flush
    end
  end

  describe '#toggle?' do
    let(:key) { 'ld-key' }
    let(:user) { {user: 'user1'} }
    it 'will not fail' do
      expect(client.instance_variable_get(:@config)).to receive(:stream?).and_raise RuntimeError
      expect(client.instance_variable_get(:@config).logger).to receive(:error)
      result = client.toggle?(key, user, 'default')
      expect(result).to eq 'default'
    end
  end

  describe '#get_features' do
    it 'will parse and return the features list' do
      result = double('Faraday::Response', status: 200, body: '{"items": ["asdf"]}')
      expect(client).to receive(:make_request).with('/api/features').and_return(result)
      data = client.send(:get_features)
      expect(data).to eq ['asdf']
    end
    it 'will log errors' do
      result = double('Faraday::Response', status: 500)
      expect(client).to receive(:make_request).with('/api/features').and_return(result)
      expect(client.instance_variable_get(:@config).logger).to receive(:error)
      client.send(:get_features)
    end
  end

  describe '#get_flag_int' do
    it 'will return the parsed flag' do
      result = double('Faraday::Response', status: 200, body: '{"asdf":"qwer"}')
      expect(client).to receive(:make_request).with('/api/eval/features/key').and_return(result)
      data = client.send(:get_flag_int, 'key')
      expect(data).to eq({asdf: 'qwer'})
    end
    it 'will accept 401 statuses' do
      result = double('Faraday::Response', status: 401)
      expect(client).to receive(:make_request).with('/api/eval/features/key').and_return(result)
      expect(client.instance_variable_get(:@config).logger).to receive(:error)
      data = client.send(:get_flag_int, 'key')
      expect(data).to be_nil
    end
    it 'will accept 404 statuses' do
      result = double('Faraday::Response', status: 404)
      expect(client).to receive(:make_request).with('/api/eval/features/key').and_return(result)
      expect(client.instance_variable_get(:@config).logger).to receive(:error)
      data = client.send(:get_flag_int, 'key')
      expect(data).to be_nil
    end
    it 'will accept non-standard statuses' do
      result = double('Faraday::Response', status: 500)
      expect(client).to receive(:make_request).with('/api/eval/features/key').and_return(result)
      expect(client.instance_variable_get(:@config).logger).to receive(:error)
      data = client.send(:get_flag_int, 'key')
      expect(data).to be_nil
    end
  end

  describe '#make_request' do
    it 'will make a proper request' do
      expect(client.instance_variable_get :@client).to receive(:get)
      client.send(:make_request, '/asdf')
    end
  end
end